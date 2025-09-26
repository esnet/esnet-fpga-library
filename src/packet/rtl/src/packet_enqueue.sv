// Stores packet to memory managed as circular buffer. Write descriptor is generated
// only after full packet has been received successfully.
module packet_enqueue
    import packet_pkg::*;
#(
    parameter int  IGNORE_RDY = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  ALIGNMENT = 1, // sop alignment; when > 1, enforce alignment of SOP to packet_if.DATA_BYTE_WID*ALIGNMENT
    parameter int  NUM_CONTEXTS = 1,
    parameter mux_mode_t MUX_MODE = MUX_MODE_SEL, // By default, drive demux select using 'ctxt' interface
    // Derived parameters (don't override)
    parameter int  SIZE_WID = $clog2(MAX_PKT_SIZE+1),
    parameter int  CTXT_WID = NUM_CONTEXTS > 1 ? $clog2(NUM_CONTEXTS) : 1
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.rx              packet_if,

    // Select enqueue context (used only for MUX_MODE == MUX_MODE_SEL; ignored otherwise)
    input  logic [CTXT_WID-1:0] ctxt_sel = 0,

    // Provide ordered list of enqueue contexts (used only for MUX_MODE == MUX_MODE LIST; ignored otherwise)
    input  logic                ctxt_list_append_req = 1'b0,
    input  logic [CTXT_WID-1:0] ctxt_list_append_data = 0, 
    output logic                ctxt_list_append_rdy,

    // Queue context (report context for enqueued packets, in order)
    output logic                ctxt_out_valid,
    output logic [CTXT_WID-1:0] ctxt_out,
    input  logic                ctxt_out_rdy = 1,

    // Packet write completion interface
    packet_descriptor_intf.tx   wr_descriptor_if [NUM_CONTEXTS],

    // Packet read completion interface
    packet_descriptor_intf.rx   rd_descriptor_if [NUM_CONTEXTS],

    // Packet reporting interface
    packet_event_intf.publisher event_if,

    // Memory write interface
    mem_wr_intf.controller      mem_wr_if,
    output logic [CTXT_WID-1:0] mem_wr_ctxt,
    input  logic                mem_init_done
);
    // -----------------------------
    // Imports
    // -----------------------------
    import packet_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;

    localparam int ROW_DATA_BYTE_WID = DATA_BYTE_WID * ALIGNMENT;

    localparam int ADDR_WID = mem_wr_if.ADDR_WID;
    localparam int DEPTH = 2**ADDR_WID;
    localparam int ROW_DEPTH = DEPTH / ALIGNMENT;
    localparam int ROW_ADDR_WID = $clog2(ROW_DEPTH);
    localparam int PTR_WID = $clog2(ROW_DEPTH + 1);

    localparam int META_WID = packet_if.META_WID;

    localparam int MAX_PKT_WORDS = MAX_PKT_SIZE % ROW_DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / ROW_DATA_BYTE_WID : MAX_PKT_SIZE / ROW_DATA_BYTE_WID + 1;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_WID, "mem_wr_if.DATA_WID");
        std_pkg::param_check(mem_wr_if.ADDR_WID, ADDR_WID, "mem_wr_if.ADDR_WID");
        std_pkg::param_check(wr_descriptor_if[0].META_WID, META_WID, "wr_descriptor_if[0].META_WID");
        std_pkg::param_check(rd_descriptor_if[0].META_WID, META_WID, "rd_descriptor_if[0].META_WID");
        std_pkg::param_check_gt(wr_descriptor_if[0].ADDR_WID, ADDR_WID, "wr_descriptor_if[0].ADDR_WID");
        std_pkg::param_check_gt(rd_descriptor_if[0].ADDR_WID, ADDR_WID, "rd_descriptor_if[0].ADDR_WID");
        std_pkg::param_check_gt(wr_descriptor_if[0].MAX_PKT_SIZE, MAX_PKT_SIZE, "wr_descriptor_if[0].MAX_PKT_SIZE");
        std_pkg::param_check_gt(rd_descriptor_if[0].MAX_PKT_SIZE, MAX_PKT_SIZE, "rd_descriptor_if[0].MAX_PKT_SIZE");
        std_pkg::param_check_gt(ALIGNMENT, 1, "ALIGNMENT");
        std_pkg::param_check(ALIGNMENT, 2**$clog2(ALIGNMENT), "ALIGNMENT (power of 2)");
        std_pkg::param_check(DATA_BYTE_WID, 2**$clog2(DATA_BYTE_WID), "DATA_BYTE_WID (power of 2)");
        std_pkg::param_check_lt(ALIGNMENT, DATA_BYTE_WID-1, "ALIGNMENT");
        if (MUX_MODE == MUX_MODE_LIST) std_pkg::param_check(IGNORE_RDY, 0, "IGNORE_RDY (when MUX_MODE == MUX_MODE_LIST)");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef struct packed {
        logic [META_WID-1:0] opaque;
        logic [CTXT_WID-1:0] ctxt;
    } meta_int_t;
    localparam int META_INT_WID = $bits(meta_int_t);

    // -----------------------------
    // Interfaces
    // -----------------------------
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_INT_WID)) __packet_if (.clk, .srst);
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) nxt_descriptor_if (.clk, .srst);
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_INT_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __wr_descriptor_if (.clk, .srst);

    // -----------------------------
    // Signals
    // -----------------------------
    logic  __ctxt_valid;
    logic [CTXT_WID-1:0] __ctxt;

    logic [PTR_WID-1:0]  head_ptr [NUM_CONTEXTS];
    logic [SIZE_WID-1:0] headroom             [NUM_CONTEXTS];
    logic                wr_descriptor_if_rdy [NUM_CONTEXTS];

    meta_int_t __packet_if_meta;
    meta_int_t __wr_descriptor_if_meta;

    // Per-context FIFO logic
    generate
        for (genvar g_ctxt = 0; g_ctxt < NUM_CONTEXTS; g_ctxt++) begin : g__ctxt
            // (Local) signals
            logic [PTR_WID-1:0]  __head_ptr;
            logic [PTR_WID-1:0]  tail_ptr;
            logic [PTR_WID-1:0]  count;
            logic [PTR_WID-1:0]  avail;

            logic [PTR_WID-1:0]  headroom_words;

            // -----------------------------
            // Pointer logic
            // -----------------------------
            initial __head_ptr = 0;
            always @(posedge clk) begin
                if (srst) __head_ptr <= '0;
                else if (wr_descriptor_if[g_ctxt].vld && wr_descriptor_if[g_ctxt].rdy) __head_ptr <= __head_ptr + (wr_descriptor_if[g_ctxt].size-1)/ROW_DATA_BYTE_WID + 1;
            end
            assign head_ptr[g_ctxt] = __head_ptr;

            initial tail_ptr = 0;
            always @(posedge clk) begin
                if (srst) tail_ptr <= '0;
                else if (rd_descriptor_if[g_ctxt].vld) tail_ptr <= tail_ptr + (rd_descriptor_if[g_ctxt].size-1)/ROW_DATA_BYTE_WID + 1;
            end
            assign rd_descriptor_if[g_ctxt].rdy = 1'b1;

            // -----------------------------
            // Full/Write Ready
            // -----------------------------
            assign count = __head_ptr - tail_ptr;
            assign avail = ROW_DEPTH - count;

            initial headroom_words = 0;
            always @(posedge clk) begin
                if (srst) headroom_words <= MAX_PKT_WORDS;
                else begin
                    if (avail >= MAX_PKT_WORDS) headroom_words <= MAX_PKT_WORDS;
                    else headroom_words <= avail;
                end
            end
            assign headroom[g_ctxt] = headroom_words * ROW_DATA_BYTE_WID;

            // Drive write descriptor output interface
            assign wr_descriptor_if[g_ctxt].vld  = __wr_descriptor_if_meta.ctxt == g_ctxt? __wr_descriptor_if.vld : 1'b0;
            assign wr_descriptor_if[g_ctxt].addr = __wr_descriptor_if.addr;
            assign wr_descriptor_if[g_ctxt].size = __wr_descriptor_if.size;
            assign wr_descriptor_if[g_ctxt].err  = __wr_descriptor_if.err;
            assign wr_descriptor_if[g_ctxt].meta = __wr_descriptor_if_meta.opaque;
            assign wr_descriptor_if_rdy[g_ctxt] = wr_descriptor_if[g_ctxt].rdy;

        end : g__ctxt
    endgenerate
 
    // Arbitration logic
    generate
        if (NUM_CONTEXTS > 1) begin : g__multi_ctxt
            if (MUX_MODE == MUX_MODE_SEL) begin : g__mux_sel
                assign __ctxt = ctxt_sel;
                assign __ctxt_valid = 1'b1;
            end : g__mux_sel
            else if (MUX_MODE == MUX_MODE_RR) begin : g__mux_rr
                initial __ctxt = 0;
                always @(posedge clk) begin
                    if (packet_if.vld && packet_if.rdy && packet_if.eop) begin
                        if (__ctxt < NUM_CONTEXTS-1) __ctxt <= __ctxt + 1;
                        else                         __ctxt <= 0;
                    end
                end
                assign __ctxt_valid = 1'b1;
            end : g__mux_rr
            else begin : g__mux_list
                fifo_small_ctxt  #(
                    .DATA_WID ( CTXT_WID ),
                    .DEPTH    ( 16 )
                ) i_fifo_small_ctxt__mux (
                    .clk     ( clk ),
                    .srst    ( srst ),
                    .wr_rdy  ( ctxt_list_append_rdy ),
                    .wr      ( ctxt_list_append_req ),
                    .wr_data ( ctxt_list_append_data ),
                    .rd      ( packet_if.vld && packet_if.rdy && packet_if.eop ),
                    .rd_rdy  ( __ctxt_valid ),
                    .rd_data ( __ctxt ),
                    .oflow   ( ),
                    .uflow   ( )
                );
            end : g__mux_list
        end : g__multi_ctxt
        else begin : g__single_ctxt
            assign __ctxt = 0;
            assign __ctxt_valid = 1'b1;
            if (MUX_MODE == MUX_MODE_SEL) begin : g__mux_sel
                // Nothing to do
            end : g__mux_sel
            else if (MUX_MODE == MUX_MODE_RR) begin : g__mux_rr
                // Nothing to do
            end : g__mux_rr
            else if (MUX_MODE == MUX_MODE_LIST) begin : g__mux_list
                // No need to maintain actual list...
                assign ctxt_list_append_rdy = 1'b1;
            end : g__mux_list
        end : g__single_ctxt
    endgenerate

    // Packet write FSM
    assign __packet_if.vld = packet_if.vld && __ctxt_valid;
    assign __packet_if.data  = packet_if.data;
    assign __packet_if.eop   = packet_if.eop;
    assign __packet_if.mty   = packet_if.mty;
    assign __packet_if.err   = packet_if.err;
    assign __packet_if_meta.opaque = packet_if.meta;
    assign __packet_if_meta.ctxt   = __ctxt;
    assign __packet_if.meta = __packet_if_meta;
    assign packet_if.rdy = __packet_if.rdy && __ctxt_valid;

    packet_write     #(
        .IGNORE_RDY   ( IGNORE_RDY ),
        .DROP_ERRORED ( DROP_ERRORED ),
        .MIN_PKT_SIZE ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE )
    ) i_packet_write  (
        .clk,
        .srst,
        .packet_if     ( __packet_if ),
        .nxt_descriptor_if,
        .descriptor_if ( __wr_descriptor_if ),
        .event_if,
        .mem_wr_if,
        .mem_init_done
    );

    assign mem_wr_ctxt = __ctxt;

    assign nxt_descriptor_if.vld = 1'b1;
    assign nxt_descriptor_if.addr = head_ptr[__ctxt] * ALIGNMENT;
    assign nxt_descriptor_if.size = headroom[__ctxt];
    assign nxt_descriptor_if.meta = 'x;
    assign nxt_descriptor_if.err = 1'bx;

    assign __wr_descriptor_if.rdy = wr_descriptor_if_rdy[__ctxt] && ctxt_out_rdy;

    assign __wr_descriptor_if_meta = __wr_descriptor_if.meta;

    assign ctxt_out_valid = __wr_descriptor_if.vld && __wr_descriptor_if.rdy;
    assign ctxt_out = __wr_descriptor_if_meta.ctxt;

endmodule : packet_enqueue
