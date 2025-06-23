// Module: packet_read
//
// Description: Reads a packet from memory, given a descriptor. Memory
//              interface is generic, allowing connection to arbitrary
//              memory types (i.e. on-chip SRAM, HBM, etc.)
//
module packet_read
    import packet_pkg::*;
#(
    parameter bit  IGNORE_RDY = 0,
    parameter int  MAX_RD_LATENCY = 8
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.tx              packet_if,

    // Packet completion interface
    packet_descriptor_intf.rx   descriptor_if,

    // Packet reporting interface
    packet_event_intf.publisher event_if,

    // Memory read interface
    mem_rd_intf.controller      mem_rd_if
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam type DATA_T = logic[0:DATA_BYTE_WID-1][7:0];
    localparam int  MTY_WID  = $clog2(DATA_BYTE_WID);
    localparam type MTY_T    = logic[MTY_WID-1:0];

    localparam type META_T = packet_if.META_T;
    localparam int  META_WID = $bits(META_T);

    localparam type ADDR_T = descriptor_if.ADDR_T;
    localparam int  ADDR_WID = $bits(ADDR_T);

    localparam type SIZE_T = descriptor_if.SIZE_T;
    localparam int  MAX_PKT_SIZE = 2**$bits(SIZE_T);
    localparam int  MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int  WORD_CNT_WID = $clog2(MAX_PKT_WORDS);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check($bits(descriptor_if.META_T), META_WID, "descriptor_if.META_T");
        std_pkg::param_check(mem_rd_if.DATA_WID, DATA_WID, "mem_rd_if.DATA_WID");
        std_pkg::param_check(mem_rd_if.ADDR_WID, ADDR_WID, "mem_rd_if.ADDR_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [1:0] {
        RESET = 0,
        READY = 1,
        BUSY  = 2
    } state_t;

    typedef struct packed {
        logic  eop;
        MTY_T  mty;
        META_T meta;
    } ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic desc_ack;

    ADDR_T rd_ptr;

    logic [WORD_CNT_WID-1:0] rd_word;

    logic [WORD_CNT_WID-1:0] last_word;
    MTY_T                    last_word_mty;

    logic prefetch_req;
    logic prefetch_rdy;
    logic prefetch_eop;

    ctxt_t ctxt_in;
    ctxt_t ctxt_out;

    // -----------------------------
    // Read FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        desc_ack = 1'b0;
        prefetch_req = 1'b0;
        case (state)
            RESET: begin
                nxt_state = READY;
            end
            READY: begin
                if (descriptor_if.valid) nxt_state = BUSY;
            end
            BUSY : begin
                prefetch_req = 1'b1;
                if (mem_rd_if.rdy && prefetch_rdy && prefetch_eop) begin
                    desc_ack = 1'b1;
                    nxt_state = READY;
                end
            end
            default: begin
                nxt_state = RESET;
            end
        endcase
    end

    assign descriptor_if.rdy = desc_ack;

    // -----------------------------
    // Read pointer management
    // -----------------------------
    initial rd_ptr = '0;
    always @(posedge clk) begin
        if (srst) rd_ptr <= '0;
        else begin
            case (state)
                READY :  begin
                    if (descriptor_if.valid) rd_ptr <= descriptor_if.addr;
                end
                BUSY : begin
                    if (mem_rd_if.rdy && prefetch_rdy) rd_ptr <= rd_ptr + 1;
                end
            endcase
        end
    end

    // -----------------------------
    // Word management
    // -----------------------------
    initial rd_word = 0;
    always @(posedge clk) begin
        if (srst) rd_word <= '0;
        else begin
            case (state)
                READY : rd_word <= 0;
                BUSY  : if (mem_rd_if.rdy && prefetch_rdy) rd_word <= rd_word + 1;
            endcase
        end
    end

    // Latch current packet size/mty
    always_ff @(posedge clk) begin
        case (state)
            READY : begin
                last_word <= (descriptor_if.size - 1) / DATA_BYTE_WID;
                last_word_mty <= (DATA_BYTE_WID - descriptor_if.size % DATA_BYTE_WID) % DATA_BYTE_WID;
            end
        endcase
    end

    assign prefetch_eop = (rd_word == last_word);

    // -----------------------------
    // Drive memory read interface
    // -----------------------------
    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.addr = rd_ptr;
    assign mem_rd_if.req = prefetch_req && prefetch_rdy;

    // -----------------------------
    // Synthesize packet context from descriptor
    // -----------------------------
    assign ctxt_in.eop = prefetch_eop;
    assign ctxt_in.mty = prefetch_eop ? last_word_mty : '0;

    // Latch metadata
    always_ff @(posedge clk) begin
        case (state)
            READY : begin
                ctxt_in.meta <= descriptor_if.meta;
            end
        endcase
    end

    generate
        if (IGNORE_RDY) begin : g__ignore_rdy
            // Backpressure from receiver not supported; no prefetch needed
            assign prefetch_rdy = 1'b1;

            assign packet_if.valid = mem_rd_if.ack;
            assign packet_if.data = mem_rd_if.data;

            fifo_small  #(
                .DATA_T  ( ctxt_t ),
                .DEPTH   ( MAX_RD_LATENCY )
            ) i_fifo_small__ctxt (
                .clk,
                .srst,
                .wr      ( mem_rd_if.req && mem_rd_if.rdy ),
                .wr_data ( ctxt_in ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( mem_rd_if.ack ),
                .rd_data ( ctxt_out ),
                .empty   ( ),
                .uflow   ( )
            );

        end : g__ignore_rdy
        else begin : g__obey_rdy
            // Backpressure from receiver supported; prefetch needed

            // (Local) parameters
            localparam int PREFETCH_DEPTH = MAX_RD_LATENCY * 2 > 8 ? MAX_RD_LATENCY * 2 : 8;
            localparam int PREFETCH_CNT_WID = $clog2(PREFETCH_DEPTH+1);
            // (Local) typedefs
            typedef logic[PREFETCH_CNT_WID-1:0] prefetch_cnt_t;
            // (Local) signals
            prefetch_cnt_t __prefetch_cnt;
            logic          __prefetch_oflow;

            // Prefetch buffer (data)
            fifo_sync    #(
                .DATA_T   ( DATA_T ),
                .DEPTH    ( PREFETCH_DEPTH ),
                .FWFT     ( 1 )
            ) i_fifo_sync__prefetch_data (
                .clk,
                .srst,
                .wr_rdy   ( ),
                .wr       ( mem_rd_if.ack ),
                .wr_data  ( mem_rd_if.data ),
                .wr_count ( __prefetch_cnt ),
                .full     ( ),
                .oflow    ( __prefetch_oflow ),
                .rd       ( packet_if.rdy ),
                .rd_ack   ( packet_if.valid ),
                .rd_data  ( packet_if.data ),
                .rd_count ( ),
                .empty    ( ),
                .uflow    ( )
            );

            // Prefetch buffer (context)
            fifo_sync    #(
                .DATA_T   ( ctxt_t ),
                .DEPTH    ( PREFETCH_DEPTH ),
                .FWFT     ( 1 )
            ) i_fifo_sync__prefetch_ctxt (
                .clk,
                .srst,
                .wr_rdy   ( ),
                .wr       ( mem_rd_if.req && mem_rd_if.rdy),
                .wr_data  ( ctxt_in ),
                .wr_count ( ),
                .full     ( ),
                .oflow    ( ),
                .rd       ( packet_if.valid && packet_if.rdy ),
                .rd_data  ( ctxt_out ),
                .rd_ack   ( ),
                .rd_count ( ),
                .empty    ( ),
                .uflow    ( )
            );

            // Ready
            assign prefetch_rdy = (__prefetch_cnt < PREFETCH_DEPTH / 2);

        end : g__obey_rdy
    endgenerate

    assign packet_if.eop  = ctxt_out.eop;
    assign packet_if.mty  = ctxt_out.mty;
    assign packet_if.err  = 1'b0;
    assign packet_if.meta = ctxt_out.meta;

    // Drive event interface
    assign event_if.evt = packet_if.valid && (packet_if.rdy || IGNORE_RDY) && packet_if.eop;
    assign event_if.size = 0; // TODO
    assign event_if.status = STATUS_OK;

endmodule : packet_read
