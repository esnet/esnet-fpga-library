// Module: packet_gather
//
// Description: 'Gathers' a packet from memory by interfacing with a
//              gather controller that provides a series of buffers
//              from which the packet segments can be read from.
//              The memory interface (for both data and descriptors)
//              is generic, allowing connection to arbitrary memory
//              types (i.e. on-chip SRAM, HBM, etc.)
//

module packet_gather #(
    parameter bit IGNORE_RDY = 0,
    parameter int MAX_PKT_SIZE = 16384,
    parameter int NUM_BUFFERS = 1,
    parameter int BUFFER_SIZE = 1,
    parameter int MAX_RD_LATENCY = 8

) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.tx              packet_if,

    // Gather controller interface (provides buffers for packet data)
    alloc_intf.load_tx          gather_if,

    // Packet completion interface
    packet_descriptor_intf.rx   descriptor_if,

    // Packet reporting interface
    packet_event_intf.publisher event_if,

    // Memory read interface
    mem_rd_intf.controller      mem_rd_if,
    input logic                 mem_init_done
);
    // -----------------------------
    // Imports
    // -----------------------------
    import packet_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam int  MTY_WID = $clog2(DATA_BYTE_WID);

    localparam int  MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int  PKT_WORD_CNT_WID = $clog2(MAX_PKT_WORDS+1);

    localparam int  BUFFER_WORDS = BUFFER_SIZE / DATA_BYTE_WID;
    localparam int  BUFFER_WORD_CNT_WID = $clog2(BUFFER_WORDS);

    localparam int  PTR_WID = NUM_BUFFERS > 1 ? $clog2(NUM_BUFFERS) : 1;
    localparam int  MEM_DEPTH = NUM_BUFFERS * BUFFER_WORDS;
    localparam int  ADDR_WID = $clog2(MEM_DEPTH);

    localparam int  META_WID = packet_if.META_WID;
    localparam int  SIZE_WID = BUFFER_SIZE > 1 ? $clog2(BUFFER_SIZE) : 1;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_rd_if.DATA_WID, DATA_WID, "mem_rd_if.DATA_WID");
        std_pkg::param_check_gt(mem_rd_if.ADDR_WID, ADDR_WID,"mem_rd_if.ADDR_WID");
        std_pkg::param_check(descriptor_if.ADDR_WID, PTR_WID, "descriptor_if.ADDR_WID");
        std_pkg::param_check(descriptor_if.META_WID, META_WID, "descriptor_if.META_WID");
        std_pkg::param_check_gt(descriptor_if.MAX_PKT_SIZE, MAX_PKT_SIZE, "descriptor_if.MAX_PKT_SIZE");
        std_pkg::param_check(BUFFER_SIZE % DATA_BYTE_WID, 0, "BUFFER_SIZE");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic[BUFFER_WORD_CNT_WID-1:0] word_cnt_t;
    typedef logic[PKT_WORD_CNT_WID-1:0]    pkt_word_cnt_t;

    typedef enum logic [1:0] {
        FETCH_RESET,
        FETCH_INIT,
        FETCH_BUFFER
    } fetch_state_t;

    typedef enum logic [1:0] {
        READ_RESET,
        READ_SOB,
        READ_MOB
    } read_state_t;

    typedef struct packed {
        logic [PTR_WID-1:0]  ptr;
        logic                sof;
        logic                eof;
        logic [SIZE_WID-1:0] size;
        logic [META_WID-1:0] meta;
        logic                err;
    } buffer_ctxt_t;

    typedef struct packed {
        logic                eop;
        logic [MTY_WID-1:0]  mty;
        logic [META_WID-1:0] meta;
        logic                err;
    } rd_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    fetch_state_t  fetch_state;
    fetch_state_t  nxt_fetch_state;

    logic          fetch_init;

    logic          buffer_valid;
    logic          buffer_ack;
    logic          buffer_rd;
    buffer_ctxt_t  buffer_ctxt;

    read_state_t   read_state;
    read_state_t   nxt_read_state;

    word_cnt_t     words;

    logic               rd_rdy;
    logic               rd_eop;
    logic [MTY_WID-1:0] rd_mty;

    logic          prefetch_rdy;

    rd_ctxt_t      rd_ctxt_in;
    rd_ctxt_t      rd_ctxt_out;

    // -----------------------------
    // Buffer fetch from descriptor
    // -----------------------------
    initial fetch_state = FETCH_RESET;
    always @(posedge clk) begin
        if (srst) fetch_state <= FETCH_RESET;
        else      fetch_state <= nxt_fetch_state;
    end

    always_comb begin
        nxt_fetch_state = fetch_state;
        fetch_init = 1'b0;
        case (fetch_state)
            FETCH_RESET: begin
                nxt_fetch_state = FETCH_INIT;
            end
            FETCH_INIT: begin
                fetch_init = 1'b1;
                if (descriptor_if.vld && gather_if.rdy) nxt_fetch_state = FETCH_BUFFER;
            end
            FETCH_BUFFER: begin
                if (gather_if.vld && gather_if.ack) begin
                    if (gather_if.eof) nxt_fetch_state = FETCH_INIT;
                end
            end
            default: begin
                nxt_fetch_state = FETCH_RESET;
            end
        endcase
    end

    assign descriptor_if.rdy = fetch_init && gather_if.rdy;
    assign gather_if.req     = fetch_init && descriptor_if.vld;
    assign gather_if.ptr     = descriptor_if.addr;

    // -----------------------------
    // Prefetch buffer context
    // -----------------------------
    initial buffer_valid = 1'b0;
    always @(posedge clk) begin
        if (srst)                                buffer_valid <= 1'b0;
        else if (gather_if.vld && gather_if.ack) buffer_valid <= 1'b1;
        else if (buffer_ack)                     buffer_valid <= 1'b0;
    end

    assign gather_if.ack = !buffer_valid || buffer_ack;

    always_ff @(posedge clk) begin
        if (gather_if.vld && gather_if.ack) begin
            buffer_ctxt.ptr  <= gather_if.nxt_ptr;
            buffer_ctxt.sof  <= gather_if.sof;
            buffer_ctxt.eof  <= gather_if.eof;
            buffer_ctxt.size <= gather_if.size;
            buffer_ctxt.err  <= gather_if.err;
            buffer_ctxt.meta <= gather_if.meta;
        end
    end

    // -----------------------------
    // Read FSM
    // -----------------------------
    initial read_state = READ_RESET;
    always @(posedge clk) begin
        if (srst) read_state <= READ_RESET;
        else      read_state <= nxt_read_state;
    end

    always_comb begin
        nxt_read_state = read_state;
        buffer_ack = 1'b0;
        buffer_rd = 1'b0;
        case (read_state)
            READ_RESET: begin
                nxt_read_state = READ_SOB;
            end
            READ_SOB: begin
                if (buffer_valid && rd_rdy) begin
                    buffer_rd = 1'b1;
                    if (buffer_ctxt.eof && (buffer_ctxt.size > 0 && buffer_ctxt.size <= DATA_BYTE_WID)) begin
                        buffer_ack = 1'b1;
                        nxt_read_state = READ_SOB;
                    end else nxt_read_state = READ_MOB;
                end
            end
            READ_MOB: begin
                if (rd_rdy) begin
                    buffer_rd = 1'b1;
                    if (rd_eop || (words == BUFFER_WORDS-1)) begin
                        buffer_ack = 1'b1;
                        nxt_read_state = READ_SOB;
                    end
                end
            end
            default: begin
                nxt_read_state = READ_RESET;
            end
        endcase
    end

    assign rd_rdy = mem_rd_if.rdy && prefetch_rdy;

    // -----------------------------
    // Read pointer management
    // -----------------------------
    always_ff @(posedge clk) begin
        if (gather_if.vld && gather_if.ack) words <= 0;
        else if (buffer_rd)                   words <= words + 1;
    end

    always_comb begin
        rd_eop = 1'b0;
        if (buffer_ctxt.eof) begin
            if (buffer_ctxt.size == 0) rd_eop = (words == BUFFER_WORDS == 1);
            else                       rd_eop = (words == (buffer_ctxt.size-1)/DATA_BYTE_WID);
        end
    end
    assign rd_mty = rd_eop ? DATA_BYTE_WID - (buffer_ctxt.size % DATA_BYTE_WID) : 0;

    // -----------------------------
    // Drive memory read interface
    // -----------------------------
    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.addr = (buffer_ctxt.ptr * BUFFER_WORDS) + words;
    assign mem_rd_if.req = buffer_rd & prefetch_rdy;

    // -----------------------------
    // Maintain read context
    // -----------------------------
    assign rd_ctxt_in.eop  = rd_eop;
    assign rd_ctxt_in.mty  = rd_mty;
    assign rd_ctxt_in.meta = buffer_ctxt.meta;
    assign rd_ctxt_in.err  = buffer_ctxt.err;

    fifo_small_ctxt #(
        .DATA_WID ( $bits(rd_ctxt_t) ),
        .DEPTH    ( MAX_RD_LATENCY )
    ) i_fifo_small_ctxt (
        .clk,
        .srst,
        .wr_rdy  ( ),
        .wr      ( mem_rd_if.req && mem_rd_if.rdy ),
        .wr_data ( rd_ctxt_in ),
        .rd      ( mem_rd_if.ack ),
        .rd_vld  ( ),
        .rd_data ( rd_ctxt_out ),
        .oflow   ( ),
        .uflow   ( )
    );

    generate
        if (IGNORE_RDY) begin : g__ignore_rdy
            // Backpressure from receiver not supported; no prefetch needed
            assign prefetch_rdy = 1'b1;

            logic                __valid;
            logic [DATA_WID-1:0] __data;
            rd_ctxt_t            __rd_ctxt_out;

            initial __valid = 1'b0;
            always @(posedge clk) begin
                if (srst) __valid <= 1'b0;
                else      __valid <= mem_rd_if.ack;
            end

            always_ff @(posedge clk) begin
                __data <= mem_rd_if.data;
                __rd_ctxt_out <= rd_ctxt_out;
            end

            assign packet_if.vld  = __valid;
            assign packet_if.data = __data;
            assign packet_if.eop  = __rd_ctxt_out.eop;
            assign packet_if.mty  = __rd_ctxt_out.mty;
            assign packet_if.err  = __rd_ctxt_out.err;
            assign packet_if.meta = __rd_ctxt_out.meta;

        end : g__ignore_rdy
        else begin : g__obey_rdy
            // Backpressure from receiver supported; prefetch needed
            // (Local) typedefs
            typedef struct packed {
                logic [DATA_WID-1:0] data;
                logic                eop;
                logic [MTY_WID-1:0]  mty;
                logic                err;
                logic [META_WID-1:0] meta;
            } prefetch_data_t;
            // (Local) signals
            prefetch_data_t __prefetch_wr_data;
            prefetch_data_t __prefetch_rd_data;
            logic           __prefetch_oflow;

            assign __prefetch_wr_data.data = mem_rd_if.data;
            assign __prefetch_wr_data.eop = rd_ctxt_out.eop;
            assign __prefetch_wr_data.mty = rd_ctxt_out.mty;
            assign __prefetch_wr_data.err = rd_ctxt_out.err;
            assign __prefetch_wr_data.meta = rd_ctxt_out.meta;

            // Prefetch buffer (data)
            fifo_prefetch #(
                .DATA_WID        ( $bits(prefetch_data_t) ),
                .PIPELINE_DEPTH  ( MAX_RD_LATENCY)
            ) i_fifo_prefetch__data (
                .clk,
                .srst,
                .wr_rdy   ( prefetch_rdy ),
                .wr       ( mem_rd_if.ack ),
                .wr_data  ( __prefetch_wr_data ),
                .oflow    ( __prefetch_oflow ),
                .rd       ( packet_if.rdy ),
                .rd_vld   ( packet_if.vld ),
                .rd_data  ( __prefetch_rd_data )
            );

            assign packet_if.data = __prefetch_rd_data.data;
            assign packet_if.eop = __prefetch_rd_data.eop;
            assign packet_if.mty = __prefetch_rd_data.mty;
            assign packet_if.err = __prefetch_rd_data.err;
            assign packet_if.meta = __prefetch_rd_data.meta;

        end : g__obey_rdy
    endgenerate

    // Drive event interface
    assign event_if.evt = packet_if.vld && (packet_if.rdy || IGNORE_RDY) && packet_if.eop;
    assign event_if.size = 0; // TODO
    assign event_if.status = STATUS_OK;

endmodule : packet_gather

