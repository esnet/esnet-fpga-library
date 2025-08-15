// Packet disaggregation component
//
// Disaggregates a single (wider) packet interface into multiple (narrower)
// packet interface efficiently by striping packets across a memory.
//
// The memory is arranged in columns, where the total width
// is equal to the output data width. The number of columns is
// exactly INPUT_WIDTH / OUTPUT_WIDTH and must be equal to
// or greater than the number of output interfaces.
//
module packet_disaggregate
    import packet_pkg::*;
#(
    parameter int  NUM_OUTPUTS = 1,
    parameter bit  ASYNC = 0,
    parameter int  IGNORE_RDY_IN = 0,
    parameter int  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter mux_mode_t MUX_MODE = MUX_MODE_SEL, // By default, drive demux select using 'ctxt' interface
    // Derived parameters (don't override)
    parameter int  CTXT_WID = NUM_OUTPUTS > 1 ? $clog2(NUM_OUTPUTS) : 1
) (
    // Aggregated (wide) packet interfaces
    packet_intf.rx              packet_in_if,
    packet_event_intf.publisher event_in_if,

    // Select aggregation context (used only for MUX_MODE == MUX_MODE_SEL; ignored otherwise)
    input  logic [CTXT_WID-1:0] ctxt_sel = 0,

    // Provide ordered list of aggregation contexts (used only for MUX_MODE == MUX_MODE LIST; ignored otherwise)
    input  logic                ctxt_list_append_req = 1'b0,
    input  logic [CTXT_WID-1:0] ctxt_list_append_data = 0,
    output logic                ctxt_list_append_rdy,

    // Aggregation context (report context for disaggregated packets, in the order they were received)
    output logic                ctxt_out_valid,
    output logic [CTXT_WID-1:0] ctxt_out,
    input  logic                ctxt_out_ack = 1,

    // Disaggregated (narrow) packet interfaces
    packet_intf.tx              packet_out_if [NUM_OUTPUTS],
    packet_event_intf.publisher event_out_if  [NUM_OUTPUTS]
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_IN_BYTE_WID = packet_in_if.DATA_BYTE_WID;
    localparam int  DATA_IN_WID = DATA_IN_BYTE_WID * 8;

    localparam int  DATA_OUT_BYTE_WID = packet_out_if[0].DATA_BYTE_WID;
    localparam int  DATA_OUT_WID = DATA_OUT_BYTE_WID * 8;

    localparam int  N = 2**$clog2(DATA_IN_BYTE_WID / DATA_OUT_BYTE_WID);
    localparam int  SEL_WID = $clog2(N);

    localparam int  SIZE_WID = $clog2(MAX_PKT_SIZE + 1);

    localparam int  META_WID = packet_in_if.META_WID;

    localparam int  MIN_PKT_WORDS = MAX_PKT_SIZE % DATA_IN_BYTE_WID == 0 ?
                                    MAX_PKT_SIZE / DATA_IN_BYTE_WID : MAX_PKT_SIZE / DATA_IN_BYTE_WID + 1;

    // Maintain isolated memory pages (one for each output context)
    localparam int  PAGE_DEPTH = 2**$clog2(MIN_PKT_WORDS);
    localparam int  PAGE_ADDR_WID = $clog2(PAGE_DEPTH);

    localparam int  DEPTH = NUM_OUTPUTS * PAGE_DEPTH;
    localparam int  ADDR_WID = $clog2(DEPTH);

    localparam int  INPUT_FIFO_DEPTH = 2**$clog2(NUM_OUTPUTS);

    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_OUT_WID,
        ASYNC: ASYNC,
        RESET_FSM: 0,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    localparam MAX_RD_LATENCY = mem_pkg::get_rd_latency(MEM_SPEC);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check_gt(DATA_IN_BYTE_WID, DATA_OUT_BYTE_WID, "packet_in_if.DATA_BYTE_WID");
        std_pkg::param_check(DATA_IN_BYTE_WID, 2**$clog2(DATA_IN_BYTE_WID), "packet_in_if.DATA_BYTE_WID");
        std_pkg::param_check(DATA_IN_BYTE_WID % N, 0, "DATA_IN_BYTE_WID % N");
        std_pkg::param_check_lt(NUM_OUTPUTS, N, "NUM_OUTPUTS");
    end
    generate
        for (genvar g_if = 0; g_if < NUM_OUTPUTS; g_if++) begin : g__params_out
            initial begin
                std_pkg::param_check(DATA_OUT_BYTE_WID, 2**$clog2(DATA_OUT_BYTE_WID), $sformatf("packet_out_if[%0d].DATA_BYTE_WID", g_if));
                std_pkg::param_check(packet_out_if[g_if].DATA_BYTE_WID, DATA_OUT_BYTE_WID, $sformatf("packet_out_if[%0d].DATA_BYTE_WID", g_if));
                std_pkg::param_check(packet_out_if[g_if].META_WID, META_WID, $sformatf("packet_out_if[%0d].META_WID", g_if));
            end
        end : g__params_out
    endgenerate

    // -----------------------------
    // Signals
    // -----------------------------
    logic clk_in;
    logic clk_out;

    logic srst_in;
    logic srst_out;

    logic mem_init_done;

    logic                __ctxt_out_valid;
    logic [CTXT_WID-1:0] __ctxt_out;
    logic                __ctxt_out_rdy;

    logic [SEL_WID-1:0] sel;

    logic                           rd_out_req [N];
    logic [PAGE_ADDR_WID-1:0]       rd_out_addr[N];

    logic                           rd_col_ack [N];
    logic [SEL_WID-1:0]             rd_col_sel [N];
    logic [DATA_OUT_WID-1:0]        rd_col_data[N];
    logic                           rd_col_rdy [N];

    logic                           mem_wr_req;
    logic [ADDR_WID-1:0]            mem_wr_addr;
    logic [0:N-1]                   mem_wr_rdy;
    logic [0:N-1]                   mem_wr_ack;
    logic [0:N-1][DATA_OUT_WID-1:0] mem_wr_data;
    logic                           mem_wr_error;
    logic [CTXT_WID-1:0]            mem_wr_ctxt;

    // -----------------------------
    // Interfaces
    // -----------------------------
    packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) wr_descriptor_if [NUM_OUTPUTS] (.clk (clk_in), .srst(srst_in));
    packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) rd_descriptor_if [NUM_OUTPUTS] (.clk (clk_in), .srst(srst_in));
    mem_wr_intf #(.DATA_WID(DATA_IN_WID), .ADDR_WID(PAGE_ADDR_WID)) mem_wr_if (.clk (clk_in));

    // -----------------------------
    // Clocks
    // -----------------------------
    assign clk_in = packet_in_if.clk;
    assign clk_out = packet_out_if[0].clk;

    assign srst_in = packet_in_if.srst;
    assign srst_out = packet_out_if[0].srst;

    // -----------------------------
    // Input stage
    // -----------------------------
    // Enqueue logic (multi-context: one state machine per output context)
    packet_enqueue    #(
        .IGNORE_RDY    ( IGNORE_RDY_IN ),
        .DROP_ERRORED  ( DROP_ERRORED ),
        .MIN_PKT_SIZE  ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE  ( MAX_PKT_SIZE ),
        .ALIGNMENT     ( 1 ),
        .NUM_CONTEXTS  ( NUM_OUTPUTS ),
        .MUX_MODE      ( MUX_MODE )
    ) i_packet_enqueue (
        .clk           ( clk_in ),
        .srst          ( srst_in ),
        .packet_if     ( packet_in_if ),
        .ctxt_sel,
        .ctxt_list_append_req,
        .ctxt_list_append_data,
        .ctxt_list_append_rdy,
        .ctxt_out_valid ( __ctxt_out_valid ),
        .ctxt_out       ( __ctxt_out ),
        .ctxt_out_rdy   ( __ctxt_out_rdy ),
        .wr_descriptor_if,
        .rd_descriptor_if,
        .event_if      ( event_in_if ),
        .mem_wr_if,
        .mem_wr_ctxt,
        .mem_init_done
    );

    // Context queue
    fifo_small_ctxt  #(
        .DATA_WID ( CTXT_WID ),
        .DEPTH    ( 16 )
    ) i_fifo_small_ctxt (
        .clk     ( clk_in ),
        .srst    ( srst_in ),
        .wr_rdy  ( __ctxt_out_rdy ),
        .wr      ( __ctxt_out_valid ),
        .wr_data ( __ctxt_out ),
        .rd      ( ctxt_out_ack ),
        .rd_vld  ( ctxt_out_valid ),
        .rd_data ( ctxt_out ),
        .oflow   ( ),
        .uflow   ( )  
    );

    // -----------------------------
    // Input stage
    // -----------------------------
    generate
        for (genvar g_if = 0; g_if < NUM_OUTPUTS; g_if++) begin : g__if
            // (Local) parameters
            localparam int  ADDR_OUT_WID = $clog2(PAGE_DEPTH*N); // Address in units of output words (instead of input words)
            localparam int  DESC_FIFO_DEPTH = 2*2**$clog2(NUM_OUTPUTS);
            // (Local) typedefs
            localparam type rd_req_ctxt_t = struct packed {
                logic [ADDR_OUT_WID-1:0]  addr;
                logic                     desc_valid;
                logic [PAGE_ADDR_WID-1:0] desc_addr;
                logic [SIZE_WID-1:0]      desc_size;
                logic [META_WID-1:0]      desc_meta;
                logic                     desc_err;
            };
            // (Local) signals
            logic [SEL_WID-1:0]      __col;
            logic                    __desc_valid;
            logic                    __fifo_rd_req_q_wr_rdy;
            logic                    __fifo_rd_req_q_wr;
            rd_req_ctxt_t            __fifo_rd_req_q_wr_data;
            logic                    __fifo_rd_req_q_rd_vld;
            rd_req_ctxt_t            __fifo_rd_req_q_rd_data;
            logic                    __rd_rdy;
            logic                    __rd_col_sel;
            logic                    __rd_ack;
            logic [DATA_OUT_WID-1:0] __rd_data;
            logic                    __mem_rd_rdy;
            // (Local) interfaces
            packet_descriptor_intf #(.ADDR_WID(ADDR_OUT_WID),  .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __wr_descriptor_in_if  (.clk(clk_out), .srst(srst_out));
            packet_descriptor_intf #(.ADDR_WID(ADDR_OUT_WID),  .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __wr_descriptor_out_if (.clk(clk_out), .srst(srst_out));
            packet_descriptor_intf #(.ADDR_WID(PAGE_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __rd_descriptor_out_if (.clk(clk_out), .srst(srst_out));
            mem_rd_intf #(.ADDR_WID(ADDR_OUT_WID), .DATA_WID(DATA_OUT_WID)) __mem_rd_if (.clk(clk_out));

            assign __wr_descriptor_in_if.vld  = wr_descriptor_if[g_if].vld;
            assign __wr_descriptor_in_if.addr = wr_descriptor_if[g_if].addr * N;
            assign __wr_descriptor_in_if.size = wr_descriptor_if[g_if].size;
            assign __wr_descriptor_in_if.err  = wr_descriptor_if[g_if].err;
            assign __wr_descriptor_in_if.meta = wr_descriptor_if[g_if].meta;
            assign wr_descriptor_if[g_if].rdy = __wr_descriptor_in_if.rdy;

            packet_descriptor_fifo #(.DEPTH (DESC_FIFO_DEPTH), .ASYNC (ASYNC)) i_packet_descriptor_fifo__wr (
                .from_tx ( __wr_descriptor_in_if ),
                .to_rx   ( __wr_descriptor_out_if )
            );

            packet_read        #(
                .IGNORE_RDY     ( IGNORE_RDY_OUT ),
                .MAX_RD_LATENCY ( MAX_RD_LATENCY + 2*N + 1) // Account for memory read + column 'alignment' FIFO delay
            ) i_packet_read     (
                .clk            ( clk_out ),
                .srst           ( srst_out ),
                .packet_if      ( packet_out_if[g_if] ),
                .descriptor_if  ( __wr_descriptor_out_if ),
                .event_if       ( event_out_if[g_if] ),
                .mem_rd_if      ( __mem_rd_if )
            );

            assign __desc_valid = __wr_descriptor_out_if.vld && __wr_descriptor_out_if.rdy;

            // Read requests go into a queue, to smooth out address/column mismatches
            assign __fifo_rd_req_q_wr = __mem_rd_if.req;
            assign __mem_rd_if.rdy = __fifo_rd_req_q_wr_rdy;
            assign __fifo_rd_req_q_wr_data.addr = __mem_rd_if.addr;
            assign __fifo_rd_req_q_wr_data.desc_valid = __desc_valid;
            assign __fifo_rd_req_q_wr_data.desc_addr  = __wr_descriptor_out_if.addr;
            assign __fifo_rd_req_q_wr_data.desc_size  = __wr_descriptor_out_if.size;
            assign __fifo_rd_req_q_wr_data.desc_meta  = __wr_descriptor_out_if.meta;
            assign __fifo_rd_req_q_wr_data.desc_err   = __wr_descriptor_out_if.err;
            fifo_ctxt    #(
                .DATA_WID ( $bits(rd_req_ctxt_t) ),
                .DEPTH    ( 2*N )
            ) i_fifo_ctxt__rd_req_q (
                .clk     ( clk_out ),
                .srst    ( srst_out ),
                .wr_rdy  ( __fifo_rd_req_q_wr_rdy ),
                .wr      ( __fifo_rd_req_q_wr ),
                .wr_data ( __fifo_rd_req_q_wr_data ),
                .rd      ( __rd_rdy ),
                .rd_vld  ( __fifo_rd_req_q_rd_vld ),
                .rd_data ( __fifo_rd_req_q_rd_data ),
                .oflow   ( ),
                .uflow   ( )
            );

            // Each output gets access to a different output memory column each cycle (i.e. TDM)
            // - a read can be completed only if the allocated column contains the
            //   desired read address (i.e. rd_addr % N == __sel)
            assign __col = sel + g_if;

            // Drive read interface
            assign __rd_col_sel = __fifo_rd_req_q_rd_data.addr % N == __col;
            assign __mem_rd_rdy = rd_col_rdy[__col];
            assign __rd_rdy = __rd_col_sel && __mem_rd_rdy;
            assign rd_out_req [g_if] = __fifo_rd_req_q_rd_vld && __rd_col_sel;
            assign rd_out_addr[g_if] = __fifo_rd_req_q_rd_data.addr/N;

            always_comb begin
                __rd_ack = 1'b0;
                __rd_data = '0;
                for (int i = 0; i < N; i++) begin
                    if (rd_col_sel[i] == g_if && rd_col_ack[i]) begin
                        __rd_ack = 1'b1;
                        __rd_data = rd_col_data[i];
                    end
                end
            end

            assign __mem_rd_if.ack  = __rd_ack;
            assign __mem_rd_if.data = __rd_data;

            // Pass packet read completions to write side
            assign __rd_descriptor_out_if.vld  = __rd_rdy && __fifo_rd_req_q_rd_vld && __fifo_rd_req_q_rd_data.desc_valid;
            assign __rd_descriptor_out_if.addr = __fifo_rd_req_q_rd_data.desc_addr/N;
            assign __rd_descriptor_out_if.size = __fifo_rd_req_q_rd_data.desc_size;
            assign __rd_descriptor_out_if.meta = __fifo_rd_req_q_rd_data.desc_meta;
            assign __rd_descriptor_out_if.err  = __fifo_rd_req_q_rd_data.desc_err;

            packet_descriptor_fifo #(.DEPTH (DESC_FIFO_DEPTH), .ASYNC (ASYNC)) i_packet_descriptor_fifo__rd (
                .from_tx ( __rd_descriptor_out_if ),
                .to_rx   ( rd_descriptor_if[g_if] )
            );
        end : g__if
        for (genvar g_if = NUM_OUTPUTS; g_if < N; g_if++) begin : g__unused_output
            assign rd_out_req [g_if]  = 1'b0;
            assign rd_out_addr[g_if] = 'x;
        end : g__unused_output

    endgenerate

    // Rotator
    initial sel = 0;
    always @(posedge clk_in) sel <= (sel < N-1) ? sel + 1 : 0;

    // -----------------------------
    // Packet memory instantiation
    // -----------------------------
    generate
        for (genvar g_col = 0; g_col < N; g_col++) begin : g__col
            // (Local) interfaces
            mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_OUT_WID)) __mem_wr_if (.clk(clk_in));
            mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_OUT_WID)) __mem_rd_if (.clk(clk_out));
            // (Local) signals
            logic [SEL_WID-1:0]  __sel;
            logic                __rd_req;
            logic [ADDR_WID-1:0] __rd_addr;
            logic [SEL_WID-1:0]  __rd_ack_sel;

            mem_ram_sdp #(
                .SPEC ( MEM_SPEC )
            ) i_mem_ram_sdp (
                .mem_wr_if ( __mem_wr_if ),
                .mem_rd_if ( __mem_rd_if )
            );

            // Write interface
            assign __mem_wr_if.rst = mem_wr_if.rst;
            assign mem_wr_rdy [g_col] = __mem_wr_if.rdy;
            assign __mem_wr_if.en = 1'b1;
            assign __mem_wr_if.req = mem_wr_if.req;
            assign __mem_wr_if.addr = (mem_wr_ctxt * PAGE_DEPTH) + mem_wr_if.addr;
            assign mem_wr_ack [g_col] = __mem_wr_if.ack;
            assign __mem_wr_if.data = mem_wr_data[g_col];

            // Read interface
            always_comb begin
                __sel = (N + g_col - sel) % N;
                __rd_req  = rd_out_req[__sel];
                __rd_addr = (__sel * PAGE_DEPTH) + rd_out_addr[__sel];
            end
            assign __mem_rd_if.rst = 1'b0;
            assign __mem_rd_if.req = __rd_req;
            assign __mem_rd_if.addr = __rd_addr;
            assign rd_col_rdy[g_col] = __mem_rd_if.rdy;

            fifo_small_ctxt #(
                .DATA_WID ( SEL_WID ),
                .DEPTH    ( MAX_RD_LATENCY+1 )
            ) i_fifo_small_ctxt__rd_resp (
                .clk     ( clk_out ),
                .srst    ( srst_out ),
                .wr_rdy  ( ),
                .wr      ( __rd_req ),
                .wr_data ( __sel ),
                .rd      ( __mem_rd_if.ack ),
                .rd_vld  ( ),
                .rd_data ( __rd_ack_sel ),
                .oflow   ( ),
                .uflow   ( )
            );

            assign rd_col_ack [g_col] = __mem_rd_if.ack;
            assign rd_col_sel [g_col] = __rd_ack_sel;
            assign rd_col_data[g_col] = __mem_rd_if.data;

        end : g__col
    endgenerate

    assign mem_wr_if.rdy = mem_wr_rdy[0]; // (Arbitrarily) choose column 0 as the reference for ready
    assign mem_wr_data = mem_wr_if.data;
    assign mem_wr_if.ack = mem_wr_ack[0]; // (Arbitrarily) choose column 0 as the reference for ack
    assign mem_wr_error = mem_wr_ack[0] ^ (|mem_wr_ack[1:N-1]);

    assign mem_init_done = 1'b1;

endmodule : packet_disaggregate
