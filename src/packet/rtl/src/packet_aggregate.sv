// Packet aggregation component
//
// Aggregates multiple (narrower) packet interfaces into
// a single (wider) interface efficiently by striping
// packets across a memory.
//
// The memory is arranged in columns, where the total width
// is equal to the output data width. The number of columns is
// exactly OUTPUT_WIDTH / INPUT_WIDTH and must be equal to
// or greater than the number of input interfaces.
//
module packet_aggregate
    import packet_pkg::*;
#(
    parameter int  NUM_INPUTS = 1,
    parameter bit  ASYNC = 0,
    parameter int  IGNORE_RDY_IN = 0,
    parameter int  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter mux_mode_t MUX_MODE = MUX_MODE_RR, // By default, use RR arbitration to service input interfaces
    // Derived parameters (don't override)
    parameter int  CTXT_WID = NUM_INPUTS > 1 ? $clog2(NUM_INPUTS) : 1
) (
    // Disaggregated (narrow) packet interfaces
    input  logic                srst_in,
    packet_intf.rx              packet_in_if [NUM_INPUTS],
    packet_event_intf.publisher event_in_if  [NUM_INPUTS],

    // Select aggregation context (used only for MUX_MODE == MUX_MODE_SEL; ignored otherwise)
    input  logic [CTXT_WID-1:0] ctxt_sel = 0,

    // Provide ordered list of aggregation contexts (used only for MUX_MODE == MUX_MODE LIST; ignored otherwise)
    input  logic                ctxt_list_append_req = 1'b0,
    input  logic [CTXT_WID-1:0] ctxt_list_append_data = 0, 
    output logic                ctxt_list_append_rdy,

    // Aggregation context (report context for aggregated packets, in order they are transmitted)
    output logic                ctxt_out_valid,
    output logic [CTXT_WID-1:0] ctxt_out,
    input  logic                ctxt_out_ack = 1'b1,

    // Aggregated (wide) packet interfaces
    input  logic                srst_out,
    packet_intf.tx              packet_out_if,
    packet_event_intf.publisher event_out_if
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_IN_BYTE_WID = packet_in_if[0].DATA_BYTE_WID;
    localparam int  DATA_IN_WID = DATA_IN_BYTE_WID * 8;

    localparam int  DATA_OUT_BYTE_WID = packet_out_if.DATA_BYTE_WID;
    localparam int  DATA_OUT_WID = DATA_OUT_BYTE_WID * 8;

    localparam int  N = 2**$clog2(DATA_OUT_BYTE_WID / DATA_IN_BYTE_WID);
    localparam int  SEL_WID = $clog2(N);

    localparam int  SIZE_WID = $clog2(MAX_PKT_SIZE + 1);

    localparam int  META_WID = packet_out_if.META_WID;

    localparam int  MIN_PKT_WORDS = MAX_PKT_SIZE % DATA_OUT_BYTE_WID == 0 ?
                                    MAX_PKT_SIZE / DATA_OUT_BYTE_WID : MAX_PKT_SIZE / DATA_OUT_BYTE_WID + 1;

    // Maintain isolated memory pages (one for each output context)
    localparam int  PAGE_DEPTH = 2**$clog2(MIN_PKT_WORDS);
    localparam int  PAGE_ADDR_WID = $clog2(PAGE_DEPTH);

    localparam int  DEPTH = NUM_INPUTS * PAGE_DEPTH;
    localparam int  ADDR_WID = $clog2(DEPTH);
    localparam type ADDR_T = logic[ADDR_WID-1:0];

    localparam int  OUTPUT_FIFO_DEPTH = 2**$clog2(NUM_INPUTS);

    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_IN_WID,
        ASYNC: ASYNC,
        RESET_FSM: 0,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    localparam MAX_RD_LATENCY = mem_pkg::get_rd_latency(MEM_SPEC);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check_gt(DATA_OUT_BYTE_WID, DATA_IN_BYTE_WID, "packet_out_if.DATA_BYTE_WID");
        std_pkg::param_check(DATA_OUT_BYTE_WID, 2**$clog2(DATA_OUT_BYTE_WID), "packet_out_if.DATA_BYTE_WID");
        std_pkg::param_check(DATA_OUT_BYTE_WID % N, 0, "DATA_OUT_BYTE_WID % N");
        std_pkg::param_check_lt(NUM_INPUTS, N, "NUM_INPUTS");
    end
    generate
        for (genvar g_if = 0; g_if < NUM_INPUTS; g_if++) begin : g__params_in
            initial begin
                std_pkg::param_check(DATA_IN_BYTE_WID, 2**$clog2(DATA_IN_BYTE_WID), $sformatf("packet_in_if[%0d].DATA_BYTE_WID", g_if));
                std_pkg::param_check(packet_in_if[g_if].DATA_BYTE_WID, DATA_IN_BYTE_WID, $sformatf("packet_in_if[%0d].DATA_BYTE_WID", g_if));
                std_pkg::param_check(packet_in_if[g_if].META_WID, META_WID, $sformatf("packet_in_if[%0d].META_WID", g_if));
            end
        end : g__params_in
    endgenerate

    // -----------------------------
    // Signals
    // -----------------------------
    logic clk_in;
    logic clk_out;

    logic mem_init_done;

    logic                __ctxt_out_valid;
    logic [CTXT_WID-1:0] __ctxt_out;
    logic                __ctxt_out_rdy;

    logic [SEL_WID-1:0] sel;

    logic                          wr_in_req  [N];
    logic                          wr_in_en   [N];
    logic [PAGE_ADDR_WID-1:0]      wr_in_addr [N];
    logic [DATA_IN_WID-1:0]        wr_in_data [N];

    logic                          wr_col_rdy  [N];

    logic [0:N-1]                  mem_rd_rdy;
    logic [0:N-1]                  mem_rd_ack;
    logic [0:N-1][DATA_IN_WID-1:0] mem_rd_data;

    logic [SEL_WID-1:0]            mem_rd_ctxt;

    logic                          mem_rd_error;

    // -----------------------------
    // Interfaces
    // -----------------------------
    packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) wr_descriptor_out_if [NUM_INPUTS] (.clk (clk_out));
    packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) rd_descriptor_out_if [NUM_INPUTS] (.clk (clk_out));
    mem_rd_intf #(.DATA_WID(DATA_OUT_WID), .ADDR_WID(PAGE_ADDR_WID)) mem_rd_if (.clk (clk_out));

    // -----------------------------
    // Clocks
    // -----------------------------
    assign clk_in = packet_in_if[0].clk;
    assign clk_out = packet_out_if.clk;

    // -----------------------------
    // Input stage
    // -----------------------------
    // Rotator
    initial sel = 0;
    always @(posedge clk_in) sel <= (sel < N-1) ? sel + 1 : 0;

    generate
        for (genvar g_if = 0; g_if < NUM_INPUTS; g_if++) begin : g__if
            // (Local) parameters
            localparam int  ADDR_IN_WID = $clog2(PAGE_DEPTH*N); // Address in units of input words (instead of output words)
            localparam int  DESC_FIFO_DEPTH = 2**$clog2(NUM_INPUTS);
            // (Local) typedefs
            typedef struct packed {
                logic [DATA_IN_WID-1:0]   data;
                logic [ADDR_IN_WID-1:0]   addr;
                logic                     desc_valid;
                logic [PAGE_ADDR_WID-1:0] desc_addr;
                logic [SIZE_WID-1:0]      desc_size;
                logic [META_WID-1:0]      desc_meta;
                logic                     desc_err;
            } wr_ctxt_t;
            // (Local) interfaces
            mem_wr_intf #(.ADDR_WID(ADDR_IN_WID), .DATA_WID(DATA_IN_WID)) __mem_wr_if (.clk(clk_in));
            packet_descriptor_intf #(.ADDR_WID(ADDR_IN_WID),   .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __wr_descriptor_if [1] (.clk(clk_in));
            packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __wr_descriptor_in_if  (.clk(clk_in));
            packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __rd_descriptor_in_if  (.clk(clk_in));
            packet_descriptor_intf #(.ADDR_WID(ADDR_IN_WID),   .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __rd_descriptor_if [1] (.clk(clk_in));
            // (Local) signals
            logic [SEL_WID-1:0] __col;
            wr_ctxt_t           __fifo_wr_q_wr_data;
            logic               __fifo_wr_q_rd_vld;
            wr_ctxt_t           __fifo_wr_q_rd_data;
            logic               __mem_wr_rdy;
            logic               __wr_col_sel;
            logic               __wr_rdy;

            // Each input gets access to a different input memory column each cycle (i.e. TDM)
            // - a write can be completed only if the allocated column contains the
            //   desired write address (i.e. wr_addr % N == __sel)
            assign __col = sel + g_if;

            packet_enqueue       #(
                .IGNORE_RDY       ( IGNORE_RDY_IN ),
                .DROP_ERRORED     ( DROP_ERRORED ),
                .MIN_PKT_SIZE     ( MIN_PKT_SIZE ),
                .MAX_PKT_SIZE     ( MAX_PKT_SIZE ),
                .ALIGNMENT        ( N ),
                .NUM_CONTEXTS     ( 1 )
            ) i_packet_enqueue    (
                .clk              ( clk_in ),
                .srst             ( srst_in ),
                .packet_if        ( packet_in_if[g_if] ),
                .wr_descriptor_if ( __wr_descriptor_if ),
                .rd_descriptor_if ( __rd_descriptor_if ),
                .event_if         ( event_in_if[g_if] ),
                .mem_wr_if        ( __mem_wr_if ),
                .mem_wr_ctxt      ( ),
                .mem_init_done    ( mem_init_done ),
                // Unused for single-context implementation
                .ctxt_list_append_rdy ( ),
                .ctxt_out_valid       ( ),
                .ctxt_out             ( )
            );

            // Write transactions go into a write queue, to smooth out address/column mismatches
            assign __fifo_wr_q_wr_data.addr = __mem_wr_if.addr;
            assign __fifo_wr_q_wr_data.data = __mem_wr_if.data;
            assign __fifo_wr_q_wr_data.desc_valid = __wr_descriptor_if[0].vld;
            assign __fifo_wr_q_wr_data.desc_addr = __wr_descriptor_if[0].addr / N;
            assign __fifo_wr_q_wr_data.desc_size = __wr_descriptor_if[0].size;
            assign __fifo_wr_q_wr_data.desc_meta = __wr_descriptor_if[0].meta;
            assign __fifo_wr_q_wr_data.desc_err = __wr_descriptor_if[0].err;
            assign __wr_descriptor_if[0].rdy = 1'b1;

            fifo_ctxt    #(
                .DATA_WID ( $bits(wr_ctxt_t) ),
                .DEPTH    ( 2*N )
            ) i_fifo_ctxt__wr_q (
                .clk     ( clk_in ),
                .srst    ( srst_in ),
                .wr_rdy  ( __mem_wr_if.rdy ),
                .wr      ( __mem_wr_if.req ),
                .wr_data ( __fifo_wr_q_wr_data ),
                .rd      ( __wr_rdy ),
                .rd_vld  ( __fifo_wr_q_rd_vld ),
                .rd_data ( __fifo_wr_q_rd_data ),
                .oflow   ( ),
                .uflow   ( )
            );

            // Drive write interface
            assign __wr_col_sel = __fifo_wr_q_rd_data.addr % N == __col;
            assign __mem_wr_rdy = wr_col_rdy[__col];
            assign __wr_rdy = __wr_col_sel && __mem_wr_rdy;
            assign wr_in_req  [g_if] = __fifo_wr_q_rd_vld && __wr_col_sel;
            assign wr_in_en   [g_if] = 1'b1;
            assign wr_in_addr [g_if] = __fifo_wr_q_rd_data.addr / N;
            assign wr_in_data [g_if] = __fifo_wr_q_rd_data.data;

            // Pass packet write completions to read side
            assign __wr_descriptor_in_if.vld  = __wr_rdy && __fifo_wr_q_rd_vld &&  __fifo_wr_q_rd_data.desc_valid;
            assign __wr_descriptor_in_if.addr = __fifo_wr_q_rd_data.desc_addr;
            assign __wr_descriptor_in_if.size = __fifo_wr_q_rd_data.desc_size;
            assign __wr_descriptor_in_if.meta = __fifo_wr_q_rd_data.desc_meta;
            assign __wr_descriptor_in_if.err  = __fifo_wr_q_rd_data.desc_err;

            packet_descriptor_fifo #(.DEPTH (DESC_FIFO_DEPTH), .ASYNC (ASYNC)) i_packet_descriptor_fifo__wr (
                .from_tx      ( __wr_descriptor_in_if ),
                .from_tx_srst ( srst_in ),
                .to_rx        ( wr_descriptor_out_if[g_if] ),
                .to_rx_srst   ( srst_out )
            );

            packet_descriptor_fifo #(.DEPTH (DESC_FIFO_DEPTH), .ASYNC (ASYNC)) i_packet_descriptor_fifo__rd (
                .from_tx      ( rd_descriptor_out_if[g_if] ),
                .from_tx_srst ( srst_out ),
                .to_rx        ( __rd_descriptor_in_if ),
                .to_rx_srst   ( srst_in )
            );

            assign __rd_descriptor_if[0].vld  = __rd_descriptor_in_if.vld;
            assign __rd_descriptor_if[0].addr = __rd_descriptor_in_if.addr * N;
            assign __rd_descriptor_if[0].size = __rd_descriptor_in_if.size;
            assign __rd_descriptor_if[0].meta = __rd_descriptor_in_if.meta;
            assign __rd_descriptor_if[0].err  = __rd_descriptor_in_if.err;
            assign __rd_descriptor_in_if.rdy  = __rd_descriptor_if[0].rdy;
        end : g__if
        for (genvar g_if = NUM_INPUTS; g_if < N; g_if++) begin : g__unused_input
            assign wr_in_req [g_if]  = 1'b0;
            assign wr_in_en  [g_if]  = 1'b0;
            assign wr_in_addr [g_if] = 'x;
            assign wr_in_data [g_if] = 'x;
        end : g__unused_input
    endgenerate

    // -----------------------------
    // Packet memory instantiation
    // -----------------------------

    generate
        for (genvar g_col = 0; g_col < N; g_col++) begin : g__col
            // (Local) interfaces
            mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_IN_WID)) __mem_wr_if (.clk(clk_in));
            mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_IN_WID)) __mem_rd_if (.clk(clk_out));
            // (Local) signals
            logic [SEL_WID-1:0]       __sel;
            logic                     __wr_req;
            logic                     __wr_en;
            logic [PAGE_ADDR_WID-1:0] __wr_addr;
            logic [DATA_IN_WID-1:0]   __wr_data;

            mem_ram_sdp #(
                .SPEC ( MEM_SPEC )
            ) i_mem_ram_sdp (
                .mem_wr_if ( __mem_wr_if ),
                .mem_rd_if ( __mem_rd_if )
            );

            // Write interface
            always_comb begin
                __sel = (N + g_col - sel) % N;
                __wr_req  = wr_in_req[__sel];
                __wr_en   = wr_in_en [__sel];
                __wr_addr = wr_in_addr[__sel];
                __wr_data = wr_in_data[__sel];
            end
            assign __mem_wr_if.rst = 1'b0;
            assign __mem_wr_if.req = __wr_req;
            assign __mem_wr_if.en = __wr_en;
            assign __mem_wr_if.addr = (__sel * PAGE_DEPTH) + __wr_addr;
            assign __mem_wr_if.data = __wr_data;
            assign wr_col_rdy[g_col] = __mem_wr_if.rdy;

            // Read interface
            assign __mem_rd_if.rst = mem_rd_if.rst;
            assign mem_rd_rdy [g_col] = __mem_rd_if.rdy;
            assign __mem_rd_if.req = mem_rd_if.req;
            assign __mem_rd_if.addr = (mem_rd_ctxt * PAGE_DEPTH) + mem_rd_if.addr;
            assign mem_rd_ack [g_col] = __mem_rd_if.ack;
            assign mem_rd_data[g_col] = __mem_rd_if.data;

        end : g__col
    endgenerate

    assign mem_rd_if.rdy = mem_rd_rdy[0]; // (Arbitrarily) choose column 0 as the reference for ready
    assign mem_rd_if.ack = mem_rd_ack[0]; // (Arbitrarily) choose column 0 as the reference for ack
    assign mem_rd_if.data = mem_rd_data;
    assign mem_rd_error = mem_rd_ack[0] ^ (|mem_rd_ack[1:N-1]);

    assign mem_init_done = 1'b1;

    // -----------------------------
    // Output stage
    // -----------------------------
    packet_dequeue       #(
        .IGNORE_RDY       ( IGNORE_RDY_OUT ),
        .MAX_RD_LATENCY   ( MAX_RD_LATENCY ),
        .NUM_CONTEXTS     ( NUM_INPUTS ),
        .MUX_MODE         ( MUX_MODE )
    ) i_packet_dequeue    (
        .clk              ( clk_out ),
        .srst             ( srst_out ),
        .packet_if        ( packet_out_if ),
        .ctxt_sel,
        .ctxt_list_append_req,
        .ctxt_list_append_data,
        .ctxt_list_append_rdy,
        .ctxt_out_valid   ( __ctxt_out_valid ),
        .ctxt_out         ( __ctxt_out ),
        .ctxt_out_rdy     ( __ctxt_out_rdy ),
        .wr_descriptor_if ( wr_descriptor_out_if ),
        .rd_descriptor_if ( rd_descriptor_out_if ),
        .event_if         ( event_out_if ),
        .mem_rd_if,
        .mem_rd_ctxt,
        .mem_init_done
    );

    // Context queue
    fifo_ctxt    #(
        .DATA_WID ( CTXT_WID ),
        .DEPTH    ( 16 )
    ) i_fifo_ctxt (
        .clk     ( clk_out ),
        .srst    ( srst_out ),
        .wr_rdy  ( __ctxt_out_rdy ),
        .wr      ( __ctxt_out_valid ),
        .wr_data ( __ctxt_out ),
        .rd      ( ctxt_out_ack ),
        .rd_vld  ( ctxt_out_valid ),
        .rd_data ( ctxt_out ),
        .oflow   ( ),
        .uflow   ( )  
    );

endmodule : packet_aggregate
