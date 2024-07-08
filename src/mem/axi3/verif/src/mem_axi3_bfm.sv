module mem_axi3_bfm #(
    parameter int CHANNELS = 1,
    parameter bit DEBUG = 1'b0
) (
    axi3_intf.peripheral axi3_if [CHANNELS]
);

    // Imports
    import axi3_pkg::*;

    // Parameters
    localparam int ADDR_WID = axi3_if[0].ADDR_WID;
    localparam int DATA_BYTE_WID = axi3_if[0].DATA_BYTE_WID;
    localparam type AXI_ID_T = axi3_if[0].ID_T; 

    // Typedefs
    typedef logic [ADDR_WID-1:0]           addr_t;
    typedef logic [DATA_BYTE_WID-1:0][7:0] data_t;
    typedef logic [DATA_BYTE_WID-1:0]      strb_t;
    typedef AXI_ID_T id_t;
    typedef struct packed {id_t id; addr_t addr;} addr_ctxt_t;
    typedef struct packed {id_t id; data_t data; strb_t strb; logic last;} wdata_ctxt_t;
    typedef struct packed {id_t id; data_t data; logic last;} rdata_ctxt_t;

    data_t __ram [addr_t];

    generate
        for (genvar g_if = 0; g_if < CHANNELS; g_if++) begin : g__if

            // (Local) signals
            addr_ctxt_t  aw_ctxt_q[$];
            addr_t       awaddr;
            id_t         awid;

            wdata_ctxt_t wdata_q[$];
            data_t       wdata;
            strb_t       wstrb;
            id_t         wid;
            logic        wlast;
            logic        wvalid;
            logic        wip;

            addr_ctxt_t  ar_ctxt_q[$];
            addr_t       araddr;
            id_t         arid;
            logic        arvalid;

            rdata_ctxt_t rdata_q[$];
            data_t       rdata;
            id_t         rid;
            logic        rlast;
            logic        rvalid;

            // Always ready for write address
            assign axi3_if[g_if].awready = 1'b1;

            // Latch write address/id
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    aw_ctxt_q.delete();
                end else begin
                    if (axi3_if[g_if].awvalid && axi3_if[g_if].awready) begin
                        if (DEBUG) $display("[Ch%0d] Push 0x%0x (ID 0x%0x) onto write address queue.", g_if, axi3_if[g_if].awaddr, axi3_if[g_if].awid);
                        aw_ctxt_q.push_back({axi3_if[g_if].awid, axi3_if[g_if].awaddr});
                    end
                end
            end

            // Always ready for write data
            assign axi3_if[g_if].wready = 1'b1;

            // Latch write data
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    wdata_q.delete();
                end else begin
                    if (axi3_if[g_if].wvalid && axi3_if[g_if].wready) begin
                        if (DEBUG) $display("[Ch%0d] Push 0x%0x (ID 0x%0x, LAST 0x%0x, STRB 0x%0x) onto write data queue.", g_if, axi3_if[g_if].wdata, axi3_if[g_if].wid, axi3_if[g_if].wlast, axi3_if[g_if].wstrb);
                        wdata_q.push_back({axi3_if[g_if].wid, axi3_if[g_if].wdata, axi3_if[g_if].wstrb, axi3_if[g_if].wlast});
                    end
                end
            end

            // Track write progress
            initial wip = 1'b0;
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    wip <= 1'b0;
                end else if (wvalid && wlast) begin
                    wip <= 1'b0;
                end else if (wvalid) begin
                    wip <= 1'b1;
                end
            end

            // Perform write
            initial begin
                wvalid = 1'b0;
                wip = 1'b0;
            end
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    wvalid <= 1'b0;
                end else  if (wip) begin
                    if (wlast) begin
                        if (aw_ctxt_q.size() > 0 && wdata_q.size() > 0) begin
                            wvalid <= 1'b1;
                            {awid, awaddr} <= aw_ctxt_q.pop_front();
                            {wid, wdata, wstrb, wlast} <= wdata_q.pop_front();
                        end else begin
                            wvalid <= 1'b0;
                            wip <= 1'b0;
                        end
                    end else if (wdata_q.size() > 0) begin
                        wvalid <= 1'b1;
                        {wid, wdata, wstrb, wlast} <= wdata_q.pop_front();
                    end else begin
                        wvalid <= 1'b0;
                    end
                end else if (aw_ctxt_q.size() > 0 && wdata_q.size() > 0) begin
                    wvalid <= 1'b1;
                    wip <= 1'b1;
                    {awid, awaddr} <= aw_ctxt_q.pop_front();
                    {wid, wdata, wstrb, wlast} <= wdata_q.pop_front();
                end else begin
                    wvalid <= 1'b0;
                end
            end

            always_comb begin
                if (wvalid) begin
                    __ram[awaddr] = wdata;
                    if (DEBUG) $display("WRITE on Ch%0d, ID %d: ADDR: 0x%x, DATA: 0x%x, STRB: 0x%x, LAST: %b ", g_if, awid, awaddr, wdata, wstrb, wlast);
                end
            end

            initial axi3_if[g_if].bvalid = 1'b0;

            // Perform write response
            always @(posedge axi3_if[g_if].aclk) begin
                if (wvalid && wlast) begin
                    axi3_if[g_if].bvalid <= 1'b1;
                    axi3_if[g_if].bid <= awid;
                    axi3_if[g_if].bresp <= axi3_pkg::RESP_OKAY;
                end else begin
                    axi3_if[g_if].bvalid <= 1'b0;
                end
            end

            // Always ready for read address
            assign axi3_if[g_if].arready = 1'b1;
 
            // Latch read address/id
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    ar_ctxt_q.delete();
                end else begin
                    if (axi3_if[g_if].arvalid && axi3_if[g_if].arready) begin
                        if (DEBUG) $display("Push 0x%x (ID 0x%0x) onto read address queue.", axi3_if[g_if].araddr, axi3_if[g_if].arid);
                        ar_ctxt_q.push_back({axi3_if[g_if].arid, axi3_if[g_if].araddr});
                    end
                end
            end
          
            // Perform read
            initial arvalid = 1'b0;
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    arvalid <= 1'b0;
                end else if (ar_ctxt_q.size() > 0) begin
                    arvalid <= 1'b1;
                    {arid, araddr} <= ar_ctxt_q.pop_front();
                end else begin
                    arvalid <= 1'b0;
                end
            end

            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    rdata_q.delete();
                end else begin
                    if (arvalid) begin
                        if (__ram.exists(araddr)) begin
                            rdata_q.push_back({arid, __ram[araddr], 1'b0});
                            if (DEBUG) $display("READ on Ch%0d, ID %0d: ADDR: 0x%x, DATA: 0x%x, LAST: 0", g_if, arid, araddr, __ram[araddr]);
                        end else begin
                            rdata_q.push_back({arid, 256'b0, 1'b0});
                            if (DEBUG) $display("READ unitialized address on Ch%0d, ID %0d: ADDR: 0x%x, LAST: 0", g_if, arid, araddr);
                        end
                    end
                end
            end

            // Process read results
            initial rvalid = 1'b0;
            always @(posedge axi3_if[g_if].aclk) begin
                if (!axi3_if[g_if].aresetn) begin
                    rvalid <= 1'b0;
                end else if (rdata_q.size() > 0 && axi3_if[g_if].rready) begin
                    rvalid <= 1'b1;
                    {rid, rdata, rlast} <= rdata_q.pop_front();
                end else begin
                    rvalid <= 1'b0;
                end
            end

            // Drive read interface
            assign axi3_if[g_if].rvalid = rvalid;
            assign axi3_if[g_if].rdata = rdata;
            assign axi3_if[g_if].rlast = rlast;
            assign axi3_if[g_if].rresp = axi3_pkg::RESP_OKAY;
            assign axi3_if[g_if].rid = rid;

        end : g__if
    endgenerate

endmodule : mem_axi3_bfm
