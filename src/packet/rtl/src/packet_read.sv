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
    localparam int  MTY_WID  = $clog2(DATA_BYTE_WID);

    localparam int  META_WID = packet_if.META_WID;

    localparam int  ADDR_WID = descriptor_if.ADDR_WID;

    localparam int  MAX_PKT_SIZE = descriptor_if.MAX_PKT_SIZE;
    localparam int  MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int  WORD_CNT_WID = $clog2(MAX_PKT_WORDS);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(descriptor_if.META_WID, META_WID, "descriptor_if.META_WID");
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
        logic                eop;
        logic [MTY_WID-1:0]  mty;
        logic                err;
        logic [META_WID-1:0] meta;
    } ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic desc_ack;

    logic [ADDR_WID-1:0] rd_ptr;

    logic [WORD_CNT_WID-1:0] rd_word;

    logic [WORD_CNT_WID-1:0] last_word;
    logic [MTY_WID-1:0]      last_word_mty;

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
                if (descriptor_if.vld) nxt_state = BUSY;
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
                    if (descriptor_if.vld) rd_ptr <= descriptor_if.addr;
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
                ctxt_in.err <= descriptor_if.err;
                ctxt_in.meta <= descriptor_if.meta;
            end
        endcase
    end

    // Read context
    fifo_small_ctxt  #(
        .DATA_WID ( $bits(ctxt_t) ),
        .DEPTH    ( MAX_RD_LATENCY )
    ) i_fifo_small_ctxt (
        .clk,
        .srst,
        .wr_rdy  ( ),
        .wr      ( mem_rd_if.req && mem_rd_if.rdy ),
        .wr_data ( ctxt_in ),
        .rd      ( mem_rd_if.ack ),
        .rd_vld  ( ),
        .rd_data ( ctxt_out ),
        .oflow   ( ),
        .uflow   ( )
    );

    generate
        if (IGNORE_RDY) begin : g__ignore_rdy
            // Backpressure from receiver not supported; no prefetch needed
            assign prefetch_rdy = 1'b1;

            logic                __valid;
            logic [DATA_WID-1:0] __data;
            ctxt_t               __ctxt_out;

            initial __valid = 1'b0;
            always @(posedge clk) begin
                if (srst) __valid <= 1'b0;
                else      __valid <= mem_rd_if.ack;
            end

            always_ff @(posedge clk) begin
                __data <= mem_rd_if.data;
                __ctxt_out <= ctxt_out;
            end

            assign packet_if.vld  = __valid;
            assign packet_if.data = __data;
            assign packet_if.eop  = __ctxt_out.eop;
            assign packet_if.mty  = __ctxt_out.mty;
            assign packet_if.err  = __ctxt_out.err;
            assign packet_if.meta = __ctxt_out.meta;

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
            assign __prefetch_wr_data.eop = ctxt_out.eop;
            assign __prefetch_wr_data.mty = ctxt_out.mty;
            assign __prefetch_wr_data.err = ctxt_out.err;
            assign __prefetch_wr_data.meta = ctxt_out.meta;

            // Prefetch buffer (data)
            fifo_prefetch #(
                .DATA_WID        ( $bits(prefetch_data_t) ),
                .PIPELINE_DEPTH  ( MAX_RD_LATENCY )
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

endmodule : packet_read
