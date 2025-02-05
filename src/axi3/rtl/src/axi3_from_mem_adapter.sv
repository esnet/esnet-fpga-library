// Module: axi3_from_mem_adapter
//
// Converts (word-addressable) mem_wr_if/mem_rd_if interfaces into a
// 'byte-addressable' AXI-3 interface.
module axi3_from_mem_adapter
    import axi3_pkg::*;
#(
    parameter axsize_t SIZE = SIZE_64BYTES,
    parameter int WR_TIMEOUT = 64, // Write timeout (in clock cycles); set to 0 to disable timeout
    parameter int RD_TIMEOUT = 64  // Read timeout  (in clock cycles); set to 0 to disable timeout
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    output logic               init_done,

    // Memory interface (from controller)
    mem_wr_intf.peripheral     mem_wr_if,
    mem_rd_intf.peripheral     mem_rd_if,

    // AXI3 interface (to peripheral)
    axi3_intf.controller       axi3_if
);
    // Parameters
    localparam int DATA_BYTES     = get_word_size(SIZE);
    localparam int WORD_ADDR_WID  = mem_wr_if.ADDR_WID;
    localparam int BYTE_SEL_WID   = $clog2(DATA_BYTES);
    localparam int BYTE_ADDR_WID  = WORD_ADDR_WID + BYTE_SEL_WID;

    // Parameter checking
    initial begin
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_BYTES*8,  "mem_wr_if.DATA_WID");
        std_pkg::param_check(mem_rd_if.ADDR_WID, WORD_ADDR_WID, "mem_rd_if.ADDR_WID");
        std_pkg::param_check(mem_rd_if.DATA_WID, DATA_BYTES*8,  "mem_rd_if.DATA_WID");
        std_pkg::param_check(axi3_if.ADDR_WID, BYTE_ADDR_WID,   "axi3_if.ADDR_WID");
        std_pkg::param_check(axi3_if.DATA_BYTE_WID, DATA_BYTES, "axi3_if.DATA_BYTE_WID");
    end
    
    // Signals
    // --------------------
    logic                      wr_pending;
    logic                      wr_timeout;

    logic                      rd_pending;
    logic                      rd_timeout;

    // Initialization
    // -----------------------------
    // TODO: add init (i.e. auto-clear block)
    assign init_done = 1'b1;

    // Write address
    // -----------------------------
    initial axi3_if.awvalid = 1'b0;
    always @(posedge clk) begin
        if (srst) axi3_if.awvalid <= 1'b0;
        else begin
            if (mem_wr_if.req && mem_wr_if.rdy) axi3_if.awvalid <= 1'b1;
            else if (axi3_if.awready || wr_timeout) axi3_if.awvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) if (mem_wr_if.req && mem_wr_if.rdy) axi3_if.awaddr <= mem_wr_if.addr << BYTE_SEL_WID;
 
    // Write metadata
    // -----------------------------
    assign axi3_if.awid = '0;
    assign axi3_if.awlen = 0; // Burst length == 1; TODO: support Burst length > 1
    assign axi3_if.awsize = SIZE;
    assign axi3_if.awburst.encoded = BURST_INCR;
    assign axi3_if.awlock.encoded= LOCK_NORMAL;
    assign axi3_if.awcache.encoded = '{bufferable: 1'b0, cacheable: 1'b0, read_allocate: 1'b0, write_allocate: 1'b0};
    assign axi3_if.awprot.encoded = '{instruction_data_n: 1'b0, secure: 1'b0, privileged: 1'b0};
    assign axi3_if.awqos = '0;
    assign axi3_if.awregion = '0;
    assign axi3_if.awuser = '0;

    // Write data
    // -----------------------------
    initial axi3_if.wvalid = 1'b0;
    always @(posedge clk) begin
        if (srst) axi3_if.wvalid <= 1'b0;
        else begin
            if (mem_wr_if.req && mem_wr_if.rdy) axi3_if.wvalid <= 1'b1;
            else if (axi3_if.wready || wr_timeout) axi3_if.wvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (mem_wr_if.req && mem_wr_if.rdy) begin
            axi3_if.wdata <= mem_wr_if.data;
            axi3_if.wstrb <= '1;
        end
    end

    // TEMP: only burst length == 1 is supported.
    assign axi3_if.wlast = 1'b1;

    // Tie off unused signals
    assign axi3_if.wid = '0;
    assign axi3_if.wuser = '0;

    // Write state
    // -------------
    initial wr_pending = 1'b0;
    always @(posedge clk) begin
        if (srst) wr_pending <= 1'b0;
        else begin
            if (mem_wr_if.req && mem_wr_if.rdy) wr_pending <= 1'b1;
            else if (mem_wr_if.ack) wr_pending <= 1'b0;
        end
    end

    assign mem_wr_if.rdy = !wr_pending;

    // Write timeout
    // -----------------------------
    generate
        if (WR_TIMEOUT > 0) begin : g__wr_timeout
            // (Local) parameters
            localparam int WR_TIMER_WID = $clog2(WR_TIMEOUT);
            // (Local) signals
            logic [WR_TIMER_WID-1:0] wr_timer;

            initial wr_timer = 0;
            always @(posedge clk) begin
                if (srst) wr_timer <= 0;
                else begin
                    if (wr_pending) wr_timer <= wr_timer + 1;
                    else            wr_timer <= 0;
                end
            end
            assign wr_timeout = (wr_timer == WR_TIMEOUT-1);
        end : g__wr_timeout
        else begin : g__no_wr_timeout
            assign wr_timeout = 1'b0;
        end : g__no_wr_timeout
    endgenerate 

    // Write response
    // --------------------
    initial axi3_if.bready = 1'b0;
    always @(posedge clk) begin
        if (srst)                                 axi3_if.bready <= 1'b0;
        else begin
            if (mem_wr_if.req && mem_wr_if.rdy)   axi3_if.bready <= 1'b1;
            else if (wr_pending) begin
                if (axi3_if.bvalid || wr_timeout) axi3_if.bready <= 1'b0;
            end else if (axi3_if.bvalid)          axi3_if.bready <= 1'b1;
            else                                  axi3_if.bready <= 1'b0;
        end
    end

    initial begin
        mem_wr_if.ack = 1'b0;
    end
    always @(posedge clk) begin
        if (srst) begin
            mem_wr_if.ack <= 1'b0;
        end else begin
            if (wr_timeout) begin
                mem_wr_if.ack <= 1'b1;
            end else if (axi3_if.bvalid && axi3_if.bready) begin
                mem_wr_if.ack <= 1'b1;
            end else begin
                mem_wr_if.ack <= 1'b0;
            end
        end
    end

    // Read address
    // -----------------------------
    initial axi3_if.arvalid = 1'b0;
    always @(posedge clk) begin
        if (srst) axi3_if.arvalid <= 1'b0;
        else begin
            if (mem_rd_if.req && mem_rd_if.rdy) axi3_if.arvalid <= 1'b1;
            else if (axi3_if.arready || rd_timeout) axi3_if.arvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) if (mem_rd_if.req && mem_rd_if.rdy) axi3_if.araddr <= mem_rd_if.addr << BYTE_SEL_WID;
  
    // Read metadata
    // -----------------------------
    assign axi3_if.arid = '0;
    assign axi3_if.arlen = 0; // Burst length == 1; TODO: support Burst length > 1
    assign axi3_if.arsize = SIZE;
    assign axi3_if.arburst.encoded = BURST_INCR;
    assign axi3_if.arlock.encoded= LOCK_NORMAL;
    assign axi3_if.arcache.encoded = '{bufferable: 1'b0, cacheable: 1'b0, read_allocate: 1'b0, write_allocate: 1'b0};
    assign axi3_if.arprot.encoded = '{instruction_data_n: 1'b0, secure: 1'b0, privileged: 1'b0};
    assign axi3_if.arqos = '0;
    assign axi3_if.arregion = '0;
    assign axi3_if.aruser = '0;

    // Read  state
    // -------------
    initial rd_pending = 1'b0;
    always @(posedge clk) begin
        if (srst) rd_pending <= 1'b0;
        else begin
            if (mem_rd_if.req && mem_rd_if.rdy) rd_pending <= 1'b1;
            else if (mem_rd_if.ack) rd_pending <= 1'b0;
        end
    end

    assign mem_rd_if.rdy = !rd_pending;

    // Read timeout
    // -----------------------------
    generate
        if (RD_TIMEOUT > 0) begin : g__rd_timeout
            // (Local) parameters
            localparam int RD_TIMER_WID = $clog2(RD_TIMEOUT);
            // (Local) signals
            logic [RD_TIMER_WID-1:0] rd_timer;

            initial rd_timer = 0;
            always @(posedge clk) begin
                if (srst) rd_timer <= 0;
                else begin
                    if (rd_pending) rd_timer <= rd_timer + 1;
                    else            rd_timer <= 0;
                end
            end
            assign rd_timeout = (rd_timer == RD_TIMEOUT-1);
        end : g__rd_timeout
        else begin : g__no_rd_timeout
            assign rd_timeout = 1'b0;
        end : g__no_rd_timeout
    endgenerate 

    // Read response
    // --------------------
    initial axi3_if.rready = 1'b0;
    always @(posedge clk) begin
        if (srst)                                 axi3_if.rready <= 1'b0;
        else begin
            if (mem_rd_if.req && mem_rd_if.rdy)   axi3_if.rready <= 1'b1;
            else if (rd_pending) begin
                if (axi3_if.rvalid || rd_timeout) axi3_if.rready <= 1'b0;
            end else if (axi3_if.rvalid)          axi3_if.rready <= 1'b1;
            else                                  axi3_if.rready <= 1'b0;
        end
    end

    initial begin
        mem_rd_if.ack = 1'b0;
    end
    always @(posedge clk) begin
        if (srst) begin
            mem_rd_if.ack <= 1'b0;
        end else begin
            if (rd_timeout) begin
                mem_rd_if.ack <= 1'b1;
            end else if (axi3_if.rvalid && axi3_if.rready) begin
                mem_rd_if.ack <= 1'b1;
            end else begin
                mem_rd_if.ack <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rd_timeout) mem_rd_if.data <= '0;
        else if (axi3_if.rvalid && axi3_if.rready) mem_rd_if.data <= axi3_if.rdata;
    end

endmodule : axi3_from_mem_adapter
