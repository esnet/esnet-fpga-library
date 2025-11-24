// Module: axi3_from_mem_adapter
//
// Converts (word-addressable) mem_wr_if/mem_rd_if interfaces into a
// 'byte-addressable' AXI-3 interface.
module axi3_from_mem_adapter
    import axi3_pkg::*;
#(
    parameter axsize_t SIZE = SIZE_64BYTES,
    parameter longint BASE_ADDR  = 0,
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
    localparam int DATA_BYTES    = get_word_size(SIZE);
    localparam int DATA_WID      = DATA_BYTES*8;
    localparam int WORD_ADDR_WID = mem_wr_if.ADDR_WID;
    localparam int BYTE_SEL_WID  = $clog2(DATA_BYTES);
    localparam int BYTE_ADDR_WID = WORD_ADDR_WID + BYTE_SEL_WID;
    localparam int BASE_ADDR_WID = $clog2(BASE_ADDR);
    localparam int AXI_ADDR_WID  = $clog2(BASE_ADDR + 2**BYTE_ADDR_WID);

    localparam int MAX_BURST_LEN = 16;
    localparam int BURST_LEN_WID = $clog2(MAX_BURST_LEN);
    localparam int BURST_TIMEOUT = 8;

    // Parameter checking
    initial begin
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_WID,  "mem_wr_if.DATA_WID");
        std_pkg::param_check(mem_rd_if.ADDR_WID, WORD_ADDR_WID, "mem_rd_if.ADDR_WID");
        std_pkg::param_check(mem_rd_if.DATA_WID, DATA_WID,  "mem_rd_if.DATA_WID");
        std_pkg::param_check_gt(axi3_if.ADDR_WID, AXI_ADDR_WID,   "axi3_if.ADDR_WID");
        std_pkg::param_check(axi3_if.DATA_BYTE_WID, DATA_BYTES, "axi3_if.DATA_BYTE_WID");
        if (BASE_ADDR > 0) std_pkg::param_check(2**$clog2(BASE_ADDR), BASE_ADDR, "BASE_ADDR must be power of 2.");
    end

    // Typedefs
    // --------------------
    typedef enum logic [1:0] {
        RESET,
        BURST_START,
        BURST
    } state_t;

    typedef struct packed {
        logic [WORD_ADDR_WID-1:0] addr;
        logic [BURST_LEN_WID-1:0] len;
    } burst_ctxt_t;
    
    // Signals
    // --------------------
    state_t                   wr_state;
    state_t                   nxt_wr_state;

    logic                     wr_data_valid;

    logic                     wr_burst_reset;
    logic                     wr_burst_inc;
    logic                     wr_burst_done;
    logic [WORD_ADDR_WID-1:0] wr_burst_addr;
    logic [WORD_ADDR_WID-1:0] wr_burst_addr_nxt;
    logic [BURST_LEN_WID-1:0] wr_burst_cnt;
    logic [BURST_LEN_WID-1:0] wr_burst_len;
    burst_ctxt_t              wr_burst_ctxt_in;
    burst_ctxt_t              wr_burst_ctxt_out;
    logic                     wr_burst_ctxt_vld;
    logic                     wr_burst_sop;
    logic [BURST_LEN_WID-1:0] axi3_if_awlen;

    logic                      rd_pending;
    logic                      rd_timeout;

    // Initialization
    // -----------------------------
    // TODO: add init (i.e. auto-clear block)
    assign init_done = 1'b1;


    // Accumulate write bursts
    // -----------------------------
    fifo_prefetch #(
        .DATA_WID        ( DATA_WID ),
        .PIPELINE_DEPTH  ( MAX_BURST_LEN )
    ) i_fifo_prefetch__wr_data (
        .clk,
        .srst,
        .wr      ( mem_wr_if.req && mem_wr_if.en ),
        .wr_rdy  ( mem_wr_if.rdy ),
        .wr_data ( mem_wr_if.data ),
        .rd      ( axi3_if.wvalid && axi3_if.wready ),
        .rd_vld  ( wr_data_valid ),
        .rd_data ( axi3_if.wdata ),
        .oflow   ( )
    );

    // Burst FSM
    initial wr_state = RESET;
    always @(posedge clk) begin
        if (srst) wr_state <= RESET;
        else      wr_state <= nxt_wr_state;
    end

    always_comb begin
        nxt_wr_state = wr_state;
        wr_burst_reset = 1'b0;
        wr_burst_inc = 1'b0;
        wr_burst_done = 1'b0;
        case (wr_state)
            RESET : begin
                nxt_wr_state = BURST_START;
            end
            BURST_START : begin
                wr_burst_reset = 1'b1;
                if (mem_wr_if.req && mem_wr_if.en && mem_wr_if.rdy) nxt_wr_state = BURST;
            end
            BURST : begin
                if (mem_wr_if.req && mem_wr_if.en && mem_wr_if.rdy) begin
                    if (mem_wr_if.addr == wr_burst_addr_nxt && wr_burst_len < MAX_BURST_LEN-1) wr_burst_inc = 1'b1;
                    else wr_burst_done = 1'b1;
                end else begin
                    wr_burst_done = 1'b1;
                    nxt_wr_state = BURST_START;
                end
            end
            default : begin
                nxt_wr_state = RESET;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (wr_burst_reset || wr_burst_done) begin
            wr_burst_len <= '0;
            wr_burst_addr <= mem_wr_if.addr;
            wr_burst_addr_nxt <= mem_wr_if.addr + 1;
        end else if (wr_burst_inc) begin
            wr_burst_len <= wr_burst_len + 1;
            wr_burst_addr_nxt <= wr_burst_addr_nxt + 1;
        end
    end

    assign wr_burst_ctxt_in.addr = wr_burst_addr;
    assign wr_burst_ctxt_in.len = wr_burst_len;

    fifo_ctxt #(
        .DATA_WID ( $bits(burst_ctxt_t) ),
        .DEPTH    ( 2*MAX_BURST_LEN )
    ) i_fifo_ctxt__wr_burst (
        .clk,
        .srst,
        .wr       ( wr_burst_done ),
        .wr_rdy   ( ),
        .wr_data  ( wr_burst_ctxt_in ),
        .rd       ( axi3_if.awvalid && axi3_if.awready ),
        .rd_vld   ( wr_burst_ctxt_vld ),
        .rd_data  ( wr_burst_ctxt_out ),
        .oflow    ( ),
        .uflow    ( )
    );

    // Write address
    // -----------------------------
    assign axi3_if.awvalid = wr_burst_sop && wr_burst_ctxt_vld;
    assign axi3_if.awaddr = BASE_ADDR + (wr_burst_ctxt_out.addr << BYTE_SEL_WID);

    // Write metadata
    // -----------------------------
    assign axi3_if.awid = '0;
    assign axi3_if.awsize = SIZE;
    assign axi3_if.awlen = wr_burst_ctxt_out.len;
    assign axi3_if.awburst.encoded = BURST_INCR;
    assign axi3_if.awlock.encoded= LOCK_NORMAL;
    assign axi3_if.awcache.encoded = '{bufferable: 1'b0, cacheable: 1'b0, read_allocate: 1'b0, write_allocate: 1'b0};
    assign axi3_if.awprot.encoded = '{instruction_data_n: 1'b0, secure: 1'b0, privileged: 1'b0};
    assign axi3_if.awqos = '0;
    assign axi3_if.awregion = '0;
    assign axi3_if.awuser = '0;

    // Latch burst length
    always_ff @(posedge clk) begin
        if (axi3_if.awvalid && axi3_if.awready) axi3_if_awlen <= axi3_if.awlen;
    end

    // Write data
    // -----------------------------
    assign axi3_if.wvalid = wr_data_valid && (!wr_burst_sop || wr_burst_ctxt_vld);
    assign axi3_if.wstrb = '1;

    initial wr_burst_cnt = '0;
    always @(posedge clk) begin
        if (srst) wr_burst_cnt <= '0;
        else begin
            if (axi3_if.wvalid && axi3_if.wready && axi3_if.wlast) wr_burst_cnt <= '0;
            else if (axi3_if.wvalid && axi3_if.wready) wr_burst_cnt <= wr_burst_cnt + 1;
        end
    end
    assign axi3_if.wlast = wr_burst_sop ? (wr_burst_ctxt_out.len == 0) : (wr_burst_cnt == axi3_if_awlen);

    initial wr_burst_sop = 1'b1;
    always @(posedge clk) begin
        if (srst) wr_burst_sop <= 1'b1;
        else begin
            if (axi3_if.wvalid && axi3_if.wready && axi3_if.wlast) wr_burst_sop <= 1'b1;
            else if (axi3_if.wvalid && axi3_if.wready)             wr_burst_sop <= 1'b0;
        end
    end

    // Tie off unused signals
    assign axi3_if.wid = '0;
    assign axi3_if.wuser = '0;

    // Write response
    // --------------------
    assign mem_wr_if.ack = axi3_if.wvalid && axi3_if.wready;
    assign axi3_if.bready = 1'b1;

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

    always_ff @(posedge clk) if (mem_rd_if.req && mem_rd_if.rdy) axi3_if.araddr <= BASE_ADDR + (mem_rd_if.addr << BYTE_SEL_WID);
  
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
