// Loads packet from memory managed as circular buffer. Read descriptor is generated
// only after full packet has been transmitted successfully.
module packet_dequeue
    import packet_pkg::*;
#(
    parameter int  IGNORE_RDY = 0,
    parameter int  MAX_RD_LATENCY = 8,
    parameter int  NUM_CONTEXTS = 1,
    parameter mux_mode_t MUX_MODE = MUX_MODE_RR, // By default, service available descriptors in RR order
    // Derived parameters (don't override)
    parameter int  CTXT_WID = NUM_CONTEXTS > 1 ? $clog2(NUM_CONTEXTS) : 1
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.tx              packet_if,

    // Select dequeue context (used only for MUX_MODE == MUX_MODE_SEL; ignored otherwise)
    input  logic [CTXT_WID-1:0] ctxt_sel = 0,

    // Provide ordered list of dequeue contexts (used only for MUX_MODE == MUX_MODE LIST; ignored otherwise)
    input  logic                ctxt_list_append_req = 1'b0,
    input  logic [CTXT_WID-1:0] ctxt_list_append_data = 0, 
    output logic                ctxt_list_append_rdy,

    // Queue context (report context for dequeued packets, in order)
    output logic                ctxt_out_valid,
    output logic [CTXT_WID-1:0] ctxt_out,
    input  logic                ctxt_out_rdy = 1,

    // Packet write completion interface
    packet_descriptor_intf.rx   wr_descriptor_if [NUM_CONTEXTS],

    // Packet read completion interface
    packet_descriptor_intf.tx   rd_descriptor_if [NUM_CONTEXTS],

    // Packet reporting interface
    packet_event_intf.publisher event_if,

    // Memory write interface
    mem_rd_intf.controller      mem_rd_if,
    output logic [CTXT_WID-1:0] mem_rd_ctxt,
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

    localparam int ADDR_WID = mem_rd_if.ADDR_WID;
    localparam int DEPTH = 2**ADDR_WID;

    localparam int META_WID = packet_if.META_WID;

    localparam int MAX_PKT_SIZE = wr_descriptor_if[0].MAX_PKT_SIZE;
    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_rd_if.DATA_WID, DATA_WID, "mem_rd_if.DATA_WID");
        std_pkg::param_check(mem_rd_if.ADDR_WID, ADDR_WID, "mem_rd_if.ADDR_WID");
        std_pkg::param_check(DATA_BYTE_WID, 2**$clog2(DATA_BYTE_WID), "DATA_BYTE_WID (power of 2)");
        std_pkg::param_check(wr_descriptor_if[0].META_WID, META_WID, "wr_descriptor_if[0].META_WID");
        std_pkg::param_check(rd_descriptor_if[0].META_WID, META_WID, "rd_descriptor_if[0].META_WID");
        std_pkg::param_check_gt(wr_descriptor_if[0].ADDR_WID, ADDR_WID, "wr_descriptor_if[0].ADDR_WID");
        std_pkg::param_check_gt(rd_descriptor_if[0].ADDR_WID, ADDR_WID, "rd_descriptor_if[0].ADDR_WID");
        std_pkg::param_check_gt(wr_descriptor_if[0].MAX_PKT_SIZE, MAX_PKT_SIZE, "wr_descriptor_if[0].MAX_PKT_SIZE");
        std_pkg::param_check_gt(rd_descriptor_if[0].MAX_PKT_SIZE, MAX_PKT_SIZE, "rd_descriptor_if[0].MAX_PKT_SIZE");
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
    // Signals
    // -----------------------------
    logic [NUM_CONTEXTS-1:0] __req;
    logic [NUM_CONTEXTS-1:0] __ack;

    logic                 __ctxt_valid;
    logic [CTXT_WID-1:0]  __ctxt;

    logic                 wr_descriptor_rdy;
    logic                 wr_descriptor_vld[NUM_CONTEXTS];
    logic [ADDR_WID-1:0]  wr_descriptor_addr [NUM_CONTEXTS];
    logic [SIZE_WID-1:0]  wr_descriptor_size [NUM_CONTEXTS];
    logic [META_WID-1:0]  wr_descriptor_meta [NUM_CONTEXTS];
    logic                 wr_descriptor_err  [NUM_CONTEXTS];

    meta_int_t __packet_if_meta;
    meta_int_t __wr_descriptor_if_meta;

    // -----------------------------
    // Interfaces
    // -----------------------------
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_INT_WID)) __packet_if (.clk);
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_INT_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __wr_descriptor_if (.clk);

    // Per-context logic/mapping
    for (genvar g_ctxt = 0; g_ctxt < NUM_CONTEXTS; g_ctxt++) begin : g__ctxt
        // (Local) signals
        assign __req[g_ctxt] = wr_descriptor_if[g_ctxt].vld;
        assign __ack[g_ctxt] = wr_descriptor_if[g_ctxt].rdy;

        // Flatten incoming write descriptor interfaces for muxing
        assign wr_descriptor_vld [g_ctxt]  = wr_descriptor_if[g_ctxt].vld;
        assign wr_descriptor_addr[g_ctxt]  = wr_descriptor_if[g_ctxt].addr;
        assign wr_descriptor_size[g_ctxt]  = wr_descriptor_if[g_ctxt].size;
        assign wr_descriptor_meta[g_ctxt]  = wr_descriptor_if[g_ctxt].meta;
        assign wr_descriptor_err [g_ctxt]  = wr_descriptor_if[g_ctxt].err;
        assign wr_descriptor_if[g_ctxt].rdy = (__ctxt == g_ctxt) ? wr_descriptor_rdy : 1'b0;

        // Synthesize read descriptor to close loop with Tx side
        assign rd_descriptor_if[g_ctxt].vld  = (__packet_if_meta.ctxt == g_ctxt) ? __wr_descriptor_if.vld && __wr_descriptor_if.rdy : 1'b0;
        assign rd_descriptor_if[g_ctxt].addr = __wr_descriptor_if.addr;
        assign rd_descriptor_if[g_ctxt].size = __wr_descriptor_if.size;
        assign rd_descriptor_if[g_ctxt].meta = __wr_descriptor_if.meta;
        assign rd_descriptor_if[g_ctxt].err  = __wr_descriptor_if.err;
    end : g__ctxt
 
    // Arbitration logic
    generate
        if (NUM_CONTEXTS > 1) begin : g__multi_ctxt
            if (MUX_MODE == MUX_MODE_SEL) begin : g__mux_sel
                assign __ctxt = ctxt_sel;
                assign __ctxt_valid = 1'b1;
            end : g__mux_sel
            else if (MUX_MODE == MUX_MODE_RR) begin : g__mux_rr
                // Service queues in round-robin order
                arb_rr #(
                    .MODE ( arb_pkg::WCRR ),
                    .N    ( NUM_CONTEXTS )
                ) i_arb_rr (
                    .clk,
                    .srst,
                    .en    ( 1'b1 ),
                    .req   ( __req ),
                    .grant ( ),
                    .ack   ( __ack ),
                    .sel   ( __ctxt )
                );
                assign __ctxt_valid = 1'b1;
            end : g__mux_rr
            else begin : g__mux_list
                fifo_small_ctxt  #(
                    .DATA_WID ( CTXT_WID ),
                    .DEPTH    ( 16 )
                ) i_fifo_small_ctxt__mux (
                    .clk,
                    .srst,
                    .wr_rdy  ( ctxt_list_append_rdy ),
                    .wr      ( ctxt_list_append_req ),
                    .wr_data ( ctxt_list_append_data ),
                    .rd      ( __wr_descriptor_if.vld && __wr_descriptor_if.rdy ),
                    .rd_vld  ( __ctxt_valid ),
                    .rd_data ( __ctxt ),
                    .oflow   ( ),
                    .uflow   ( )
                );
            end : g__mux_list
        end : g__multi_ctxt
        else begin : g__single_ctxt
            // No need to maintain actual list...
            assign __ctxt = 0;
            assign __ctxt_valid = 1'b1;
            assign ctxt_list_append_rdy = 1'b1;
        end : g__single_ctxt
    endgenerate

    // Mux write descriptors
    assign __wr_descriptor_if.vld         = wr_descriptor_vld[__ctxt] && __ctxt_valid && ctxt_out_rdy;
    assign __wr_descriptor_if.addr        = wr_descriptor_addr [__ctxt];
    assign __wr_descriptor_if.size        = wr_descriptor_size [__ctxt];
    assign __wr_descriptor_if_meta.opaque = wr_descriptor_meta [__ctxt];
    assign __wr_descriptor_if_meta.ctxt   = __ctxt;
    assign __wr_descriptor_if.meta        = __wr_descriptor_if_meta;
    assign __wr_descriptor_if.err         = wr_descriptor_err  [__ctxt];
    assign wr_descriptor_rdy = __wr_descriptor_if.rdy && __ctxt_valid && ctxt_out_rdy;

    // Read packet from memory
    packet_read        #(
        .IGNORE_RDY     ( IGNORE_RDY ),
        .MAX_RD_LATENCY ( MAX_RD_LATENCY )
    ) i_packet_read     (
        .clk,
        .srst,
        .packet_if      ( __packet_if ),
        .descriptor_if  ( __wr_descriptor_if ),
        .event_if,
        .mem_rd_if
    );

    assign mem_rd_ctxt = __ctxt;

    // Assign output interface
    assign packet_if.vld  = __packet_if.vld;
    assign packet_if.data = __packet_if.data;
    assign packet_if.eop  = __packet_if.eop;
    assign packet_if.mty  = __packet_if.mty;
    assign packet_if.err  = __packet_if.err;
    assign __packet_if_meta = __packet_if.meta;
    assign packet_if.meta = __packet_if_meta.opaque;
    assign __packet_if.rdy = packet_if.rdy;

    assign ctxt_out_valid = packet_if.vld && packet_if.rdy && packet_if.eop;
    assign ctxt_out = __packet_if_meta.ctxt;

endmodule : packet_dequeue
