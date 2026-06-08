// =============================================================================
// AXI4 memory BFM
//
// Sparse-memory peripheral model for simulation. Accepts single-beat and
// multi-beat INCR bursts on one or more AXI4 channels. All transactions
// complete with RESP_OKAY; a configurable latency is introduced between
// address acceptance and response.
//
// Modelled on axi3_mem_bfm; key AXI4 differences:
//   - AxLEN is 8-bit (256-beat bursts)
//   - No WID on the write data channel
//   - AxLOCK is 1 bit
// =============================================================================
module axi4_mem_bfm #(
    parameter int CHANNELS        = 1,
    parameter bit GLOBAL_ADDRESSING = 1'b0,
    parameter bit DEBUG           = 1'b0,
    parameter int WR_LATENCY      = 8,
    parameter int RD_LATENCY      = 8
) (
    input logic srst,

    axi4_intf.peripheral axi4_if [CHANNELS]
);
    import axi4_pkg::*;

    localparam int ADDR_WID      = axi4_if[0].ADDR_WID;
    localparam int DATA_BYTE_WID = axi4_if[0].DATA_BYTE_WID;
    localparam int ID_WID        = axi4_if[0].ID_WID;
    localparam int BYTE_SEL_WID  = $clog2(DATA_BYTE_WID);
    localparam int CH_ID_WID     = $clog2(CHANNELS > 1 ? CHANNELS : 2);

    typedef logic [ADDR_WID-1:0]             addr_t;
    typedef logic [DATA_BYTE_WID-1:0][7:0]   data_t;
    typedef logic [DATA_BYTE_WID-1:0]         strb_t;
    typedef logic [ID_WID-1:0]               id_t;
    typedef logic [63:0]                     timestamp_t;

    typedef struct packed {id_t id; addr_t addr; logic [7:0] len; axburst_t burst;} addr_ctxt_t;
    typedef struct packed {id_t id; data_t data; strb_t strb; logic last;} wdata_ctxt_t;
    typedef struct packed {id_t id; timestamp_t timestamp;}                b_ctxt_t;
    typedef struct packed {id_t id; data_t data; logic last; timestamp_t timestamp;} rdata_ctxt_t;

    typedef logic [ADDR_WID-BYTE_SEL_WID-1:0] word_addr_t;

    // Shared sparse memory array
    data_t __ram [word_addr_t];

    // Shared timestamp counter (driven from channel 0 clock)
    timestamp_t timestamp;
    initial timestamp = 0;
    always @(posedge axi4_if[0].aclk) timestamp <= timestamp + 1;

    generate
        for (genvar g = 0; g < CHANNELS; g++) begin : g__ch

            // ---------------------------------------------------------------
            // Address mapping
            // ---------------------------------------------------------------
            addr_t eff_awaddr, eff_araddr;

            if (GLOBAL_ADDRESSING) begin : g__global
                assign eff_awaddr = axi4_if[g].awaddr;
                assign eff_araddr = axi4_if[g].araddr;
            end : g__global
            else begin : g__channel
                assign eff_awaddr = {CH_ID_WID'(g), axi4_if[g].awaddr[ADDR_WID-CH_ID_WID-1:0]};
                assign eff_araddr = {CH_ID_WID'(g), axi4_if[g].araddr[ADDR_WID-CH_ID_WID-1:0]};
            end : g__channel

            // ---------------------------------------------------------------
            // Write address channel
            // ---------------------------------------------------------------
            addr_ctxt_t aw_q[$];

            assign axi4_if[g].awready = 1'b1;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    aw_q.delete();
                end else if (axi4_if[g].awvalid && axi4_if[g].awready) begin
                    if (DEBUG)
                        $display("[axi4_mem_bfm ch%0d] AW: addr=0x%0x id=0x%0x len=%0d",
                                 g, eff_awaddr, axi4_if[g].awid, axi4_if[g].awlen);
                    aw_q.push_back('{axi4_if[g].awid, eff_awaddr, axi4_if[g].awlen, axi4_if[g].awburst});
                end
            end

            // ---------------------------------------------------------------
            // Write data channel
            // ---------------------------------------------------------------
            wdata_ctxt_t wd_q[$];
            b_ctxt_t     b_q[$];

            assign axi4_if[g].wready = 1'b1;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    wd_q.delete();
                    b_q.delete();
                end else if (axi4_if[g].wvalid && axi4_if[g].wready) begin
                    wd_q.push_back('{axi4_if[g].awid, axi4_if[g].wdata, axi4_if[g].wstrb, axi4_if[g].wlast});
                    if (axi4_if[g].wlast)
                        b_q.push_back('{axi4_if[g].awid, timestamp});
                end
            end

            // ---------------------------------------------------------------
            // Write execution — direct queue-driven RAM write, mirroring
            // axi3_mem_bfm.  A wvalid logic flag is driven from a single
            // always @(posedge) block that also pops the queues; the same
            // block writes __ram while wvalid and data are stable.
            // ---------------------------------------------------------------
            logic  wvalid;
            addr_t wr_addr;
            id_t   wr_id;
            logic [7:0] wr_len;
            axburst_t   wr_burst;
            data_t      wr_data;
            strb_t      wr_strb;
            logic       wr_last;
            logic       wr_ip;   // burst in progress

            initial wvalid = 1'b0;
            initial wr_ip  = 1'b0;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    wvalid <= 1'b0;
                    wr_ip  <= 1'b0;
                end else if (wr_ip) begin
                    if (wr_last) begin
                        if (wvalid && aw_q.size() > 0 && wd_q.size() > 0) begin
                            {wr_id, wr_addr, wr_len, wr_burst} = aw_q.pop_front();
                            {wr_id, wr_data, wr_strb, wr_last} = wd_q.pop_front();
                        end else begin
                            wr_ip  <= 1'b0;
                            wvalid <= 1'b0;
                        end
                    end else if (wd_q.size() > 0) begin
                        if (wr_burst.encoded == BURST_INCR) wr_addr <= wr_addr + DATA_BYTE_WID;
                        wvalid <= 1'b1;
                        {wr_id, wr_data, wr_strb, wr_last} = wd_q.pop_front();
                    end else begin
                        wvalid <= 1'b0;
                    end
                end else if (aw_q.size() > 0 && wd_q.size() > 0) begin
                    wvalid <= 1'b1;
                    wr_ip  <= 1'b1;
                    {wr_id, wr_addr, wr_len, wr_burst} = aw_q.pop_front();
                    {wr_id, wr_data, wr_strb, wr_last} = wd_q.pop_front();
                end else begin
                    wvalid <= 1'b0;
                end

                // RAM write — blocking, executes while wvalid+data are stable
                if (wvalid) begin
                    automatic word_addr_t wa = wr_addr >> BYTE_SEL_WID;
                    for (int b = 0; b < DATA_BYTE_WID; b++)
                        if (wr_strb[b]) __ram[wa][b] = wr_data[b];
                    if (DEBUG)
                        $display("[axi4_mem_bfm ch%0d] WR addr=0x%0x strb=0x%0x last=%0b",
                                 g, wr_addr, wr_strb, wr_last);
                end
            end

            // ---------------------------------------------------------------
            // Write response channel
            // ---------------------------------------------------------------
            initial axi4_if[g].bvalid = 1'b0;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    axi4_if[g].bvalid <= 1'b0;
                end else if (b_q.size() > 0 && axi4_if[g].bready &&
                             (timestamp > b_q[0].timestamp + WR_LATENCY)) begin
                    automatic b_ctxt_t bc = b_q.pop_front();
                    axi4_if[g].bvalid <= 1'b1;
                    axi4_if[g].bid    <= bc.id;
                    axi4_if[g].bresp  <= RESP_OKAY;
                    axi4_if[g].buser  <= '0;
                end else begin
                    axi4_if[g].bvalid <= 1'b0;
                end
            end

            // ---------------------------------------------------------------
            // Read address channel
            // ---------------------------------------------------------------
            addr_ctxt_t ar_q[$];

            assign axi4_if[g].arready = 1'b1;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    ar_q.delete();
                end else if (axi4_if[g].arvalid && axi4_if[g].arready) begin
                    automatic logic [7:0] __len  = axi4_if[g].arlen;
                    automatic addr_t      __addr = eff_araddr;
                    if (DEBUG)
                        $display("[axi4_mem_bfm ch%0d] AR: addr=0x%0x id=0x%0x len=%0d",
                                 g, __addr, axi4_if[g].arid, __len);
                    ar_q.push_back('{axi4_if[g].arid, __addr, __len, axi4_if[g].arburst});
                    while (__len > 0) begin
                        __addr = __addr + DATA_BYTE_WID;
                        __len  = __len - 1;
                        ar_q.push_back('{axi4_if[g].arid, __addr, __len, axi4_if[g].arburst});
                    end
                end
            end

            // ---------------------------------------------------------------
            // Read execution
            // ---------------------------------------------------------------
            rdata_ctxt_t rd_q[$];
            logic        rd_active;
            addr_t       rd_addr;
            id_t         rd_id;
            logic [7:0]  rd_len;
            axburst_t    rd_burst;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    rd_q.delete();
                    rd_active <= 1'b0;
                end else if (ar_q.size() > 0) begin
                    automatic addr_ctxt_t ac = ar_q.pop_front();
                    automatic word_addr_t ra = ac.addr >> BYTE_SEL_WID;
                    automatic data_t      rd;
                    rd = __ram.exists(ra) ? __ram[ra] : '0;
                    if (DEBUG)
                        $display("[axi4_mem_bfm ch%0d] RD addr=0x%0x data=0x%0x last=%0b",
                                 g, ac.addr, rd, (ac.len == 0));
                    rd_q.push_back('{ac.id, rd, (ac.len == 0), timestamp});
                    rd_active <= 1'b1;
                end else begin
                    rd_active <= 1'b0;
                end
            end

            // ---------------------------------------------------------------
            // Read response channel
            // ---------------------------------------------------------------
            logic   rd_rvalid;
            data_t  rd_rdata;
            id_t    rd_rid;
            logic   rd_rlast;

            initial rd_rvalid = 1'b0;

            always @(posedge axi4_if[g].aclk) begin
                if (srst) begin
                    rd_rvalid <= 1'b0;
                end else if (rd_q.size() > 0 && axi4_if[g].rready &&
                             (timestamp > rd_q[0].timestamp + RD_LATENCY)) begin
                    automatic rdata_ctxt_t rc = rd_q.pop_front();
                    rd_rvalid <= 1'b1;
                    rd_rid    <= rc.id;
                    rd_rdata  <= rc.data;
                    rd_rlast  <= rc.last;
                end else begin
                    rd_rvalid <= 1'b0;
                end
            end

            assign axi4_if[g].rvalid = rd_rvalid;
            assign axi4_if[g].rid    = rd_rid;
            assign axi4_if[g].rdata  = rd_rdata;
            assign axi4_if[g].rlast  = rd_rlast;
            assign axi4_if[g].rresp  = RESP_OKAY;
            assign axi4_if[g].ruser  = '0;

        end : g__ch
    endgenerate

endmodule : axi4_mem_bfm
