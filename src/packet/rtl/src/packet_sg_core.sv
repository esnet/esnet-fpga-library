module packet_sg_core
#(
    parameter int  NUM_INPUT_IFS = 1,
    parameter int  NUM_OUTPUT_IFS = 1,
    parameter bit  IGNORE_RDY_IN = 0,
    parameter bit  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  NUM_BUFFERS = 1,
    parameter int  BUFFER_SIZE = 2048,
    parameter int  MAX_RD_LATENCY = 8,
    parameter int  MAX_BURST_LEN = 1,
    parameter int  N_ALLOC = 1,
    parameter int  N_GATHER = 1,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1,
    parameter bit  SIM__RAM_MODEL = 1
 ) (
    input  logic                clk,
    input  logic                srst,

    output logic                init_done,

    // Packet input (synchronous to packet_in_if.clk)
    packet_intf.rx              packet_in_if [NUM_INPUT_IFS],

    mem_wr_intf.controller      desc_mem_wr_if,
    mem_wr_intf.controller      mem_wr_if [NUM_INPUT_IFS],

    // Packet completion interface (to/from queue controller)
    packet_descriptor_intf.tx   desc_in_if [NUM_INPUT_IFS],
    packet_descriptor_intf.rx   desc_out_if[NUM_OUTPUT_IFS],
    
    // Packet output (synchronous to packet_out_if.clk)
    packet_intf.tx              packet_out_if [NUM_OUTPUT_IFS],

    mem_rd_intf.controller      desc_mem_rd_if,
    mem_rd_intf.controller      mem_rd_if [NUM_OUTPUT_IFS],

    input logic                 mem_init_done,

    axi4l_intf.peripheral       axil_if
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  PTR_WID = $clog2(NUM_BUFFERS);

    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);

    localparam int  PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    localparam int  META_WID = packet_in_if[0].META_WID;

    localparam int  DATA_IN_BYTE_WID = packet_in_if[0].DATA_BYTE_WID;
    localparam int  MEM_WR_DATA_WID = mem_wr_if[0].DATA_WID;
    localparam int  MEM_WR_DATA_BYTE_WID = MEM_WR_DATA_WID / 8;

    localparam int  DATA_OUT_BYTE_WID = packet_out_if[0].DATA_BYTE_WID;
    localparam int  MEM_RD_DATA_WID = mem_wr_if[0].DATA_WID;
    localparam int  MEM_RD_DATA_BYTE_WID = MEM_RD_DATA_WID / 8;

    localparam int  INPUT_IF_SEL_WID = NUM_INPUT_IFS > 1 ? $clog2(NUM_INPUT_IFS) : 1;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    generate
        for (genvar i = 0; i < NUM_INPUT_IFS; i++) begin
            initial std_pkg::param_check(packet_in_if[i].META_WID, META_WID, $sformatf("packet_in_if[%0d].META_WID", i));
            initial std_pkg::param_check(packet_in_if[i].DATA_BYTE_WID, DATA_IN_BYTE_WID, $sformatf("packet_in_if[%0d].DATA_BYTE_WID", i));
            initial std_pkg::param_check(desc_in_if[i].META_WID, META_WID, $sformatf("desc_in_if[%0d].META_WID", i));
            initial std_pkg::param_check(mem_wr_if[i].DATA_WID, DATA_IN_BYTE_WID*8, $sformatf("mem_wr_if[%0d].DATA_WID", i));
        end
        for (genvar i = 0; i < NUM_OUTPUT_IFS; i++) begin
            initial std_pkg::param_check(packet_out_if[i].META_WID, META_WID, $sformatf("packet_out_if[%0d].META_WID", i));
            initial std_pkg::param_check(packet_out_if[i].DATA_BYTE_WID, DATA_OUT_BYTE_WID, $sformatf("packet_out_if[%0d].DATA_BYTE_WID", i));
            initial std_pkg::param_check(desc_out_if[i].META_WID, META_WID, $sformatf("desc_out_if[%0d].META_WID", i));
            initial std_pkg::param_check(mem_rd_if[i].DATA_WID, DATA_OUT_BYTE_WID*8, $sformatf("mem_rd_if[%0d].DATA_WID", i));
        end
    endgenerate

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) scatter_if [NUM_INPUT_IFS]  (.clk);
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) gather_if  [NUM_OUTPUT_IFS*N_GATHER] (.clk);

    packet_event_intf event_in_if  [NUM_INPUT_IFS]  (.clk);
    packet_event_intf event_out_if [NUM_OUTPUT_IFS] (.clk);

    axi4l_intf axil_if__alloc ();
    axi4l_intf axil_if__input_cnt  [4] ();
    axi4l_intf axil_if__output_cnt [4] ();

    // -----------------------------
    // Signals
    // -----------------------------
    logic  init_done__alloc_sg;

    // -- Recycle interface (to allocator)
    logic               recycle_req;
    logic               recycle_rdy;
    logic [PTR_WID-1:0] recycle_ptr;
    logic               recycle_ack;

    // -- Per-scatter recycle requests
    logic [NUM_INPUT_IFS-1:0] scatter_recycle_req;
    logic [PTR_WID-1:0]       scatter_recycle_ptr [NUM_INPUT_IFS];
    logic [INPUT_IF_SEL_WID-1: 0] recycle_sel;
    logic [NUM_INPUT_IFS-1:0]     recycle_grant;

    // -- Frame completion
    logic                    frame_valid [NUM_INPUT_IFS];
    logic                    frame_error;
    logic [PTR_WID-1:0]      frame_ptr;
    logic [PKT_SIZE_WID-1:0] frame_size;

    // -----------------------------
    // Status
    // -----------------------------
    assign init_done = mem_init_done && init_done__alloc_sg;

    // -----------------------------
    // Scatter-gather controller
    // -----------------------------
    // AXI-L decoder: one alloc slot + 4 input + 4 output counter slots
    packet_sg_core_decoder i_packet_sg_core_decoder (
        .axil_if              ( axil_if ),
        .alloc_axil_if        ( axil_if__alloc ),
        .input_cnt_0_axil_if  ( axil_if__input_cnt[0] ),
        .input_cnt_1_axil_if  ( axil_if__input_cnt[1] ),
        .input_cnt_2_axil_if  ( axil_if__input_cnt[2] ),
        .input_cnt_3_axil_if  ( axil_if__input_cnt[3] ),
        .output_cnt_0_axil_if ( axil_if__output_cnt[0] ),
        .output_cnt_1_axil_if ( axil_if__output_cnt[1] ),
        .output_cnt_2_axil_if ( axil_if__output_cnt[2] ),
        .output_cnt_3_axil_if ( axil_if__output_cnt[3] )
    );

    alloc_axil_sg_core #(
        .SCATTER_CONTEXTS ( NUM_INPUT_IFS ),
        .GATHER_CONTEXTS  ( NUM_OUTPUT_IFS*N_GATHER ),
        .PTR_WID          ( PTR_WID ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_PKT_SIZE ),
        .META_WID         ( META_WID ),
        .STORE_Q_DEPTH    ( 32 ),
        .LOAD_Q_DEPTH     ( 32 ),
        .N_ALLOC          ( N_ALLOC ),
        .SIM__FAST_INIT   ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL   ( SIM__RAM_MODEL )
    ) i_alloc_axil_sg_core (
        .clk,
        .srst,
        .en ( 1'b1 ),
        .init_done ( init_done__alloc_sg ),
        .scatter_if,
        .gather_if,
        .recycle_req,
        .recycle_rdy,
        .recycle_ptr,
        .recycle_ack,
        .desc_mem_wr_if,
        .desc_mem_rd_if,
        .desc_mem_init_done ( mem_init_done ),
        .frame_valid,
        .frame_error,
        .frame_ptr,
        .frame_size,
        .axil_if ( axil_if__alloc )
    );

    // Packet counters — input interfaces
    // packet_scatter emits OK, ERR, LONG, OFLOW, and SHORT (only when
    // MIN_PKT_SIZE > 0).  STATUS_UNDEFINED is never reached so OTHER is off.
    // Instantiate counters for active ports; terminate AXI-L for unused slots.
    generate
        for (genvar g = 0; g < 4; g++) begin : g__input_cnt
            if (g < NUM_INPUT_IFS) begin : g__active
                packet_counters #(
                    .COUNT_SHORT ( MIN_PKT_SIZE > 0 ),
                    .COUNT_OTHER ( 1'b0 )
                ) i_packet_counters (
                    .clk,
                    .axil_if  ( axil_if__input_cnt[g] ),
                    .event_if ( event_in_if[g] )
                );
            end else begin : g__inactive
                axi4l_intf_peripheral_term i_axi4l_intf_peripheral_term (
                    .axi4l_if ( axil_if__input_cnt[g] )
                );
            end
        end
    endgenerate

    // Packet counters — output interfaces
    // packet_gather emits only OK or ERR; OFLOW/SHORT/LONG/OTHER are unused.
    generate
        for (genvar g = 0; g < 4; g++) begin : g__output_cnt
            if (g < NUM_OUTPUT_IFS) begin : g__active
                packet_counters #(
                    .COUNT_OFLOW ( 1'b0 ),
                    .COUNT_SHORT ( 1'b0 ),
                    .COUNT_LONG  ( 1'b0 ),
                    .COUNT_OTHER ( 1'b0 )
                ) i_packet_counters (
                    .clk,
                    .axil_if  ( axil_if__output_cnt[g] ),
                    .event_if ( event_out_if[g] )
                );
            end else begin : g__inactive
                axi4l_intf_peripheral_term i_axi4l_intf_peripheral_term (
                    .axi4l_if ( axil_if__output_cnt[g] )
                );
            end
        end
    endgenerate

    // Arbitrate recycle requests from all scatter instances to the single
    // allocator recycle port. Each scatter holds its request until granted.
    arb_rr #(
        .N    ( NUM_INPUT_IFS ),
        .MODE ( arb_pkg::WCRR )
    ) i_arb_rr__recycle (
        .clk,
        .srst,
        .en    ( recycle_rdy ),
        .req   ( scatter_recycle_req ),
        .grant ( recycle_grant ),
        .ack   ( '1 ),
        .sel   ( recycle_sel )
    );

    assign recycle_req = |scatter_recycle_req;
    assign recycle_ptr = scatter_recycle_ptr[recycle_sel];

    generate
        // Memory write controller
        // - 'Scatter' packets into memory
        for (genvar g_if = 0; g_if < NUM_INPUT_IFS; g_if++) begin : g__input_if
            // Scatter controller
            packet_scatter    #(
                .IGNORE_RDY    ( IGNORE_RDY_IN ),
                .DROP_ERRORED  ( DROP_ERRORED ),
                .MIN_PKT_SIZE  ( MIN_PKT_SIZE ),
                .MAX_PKT_SIZE  ( MAX_PKT_SIZE ),
                .NUM_BUFFERS   ( NUM_BUFFERS ),
                .BUFFER_SIZE   ( BUFFER_SIZE )
            ) i_packet_scatter (
                .clk,
                .srst,
                .packet_if     ( packet_in_if [g_if] ),
                .scatter_if    ( scatter_if   [g_if] ),
                .descriptor_if ( desc_in_if   [g_if] ),
                .frame_valid   ( frame_valid  [g_if] ),
                .recycle_req   ( scatter_recycle_req [g_if] ),
                .recycle_ptr   ( scatter_recycle_ptr [g_if] ),
                .recycle_rdy   ( recycle_grant       [g_if] ),
                .event_if      ( event_in_if  [g_if] ),
                .mem_wr_if     ( mem_wr_if    [g_if] ),
                .mem_init_done
            );

        end : g__input_if

        // Memory read controller
        // - 'Gather' packets from memory
        for (genvar g_if = 0; g_if < NUM_OUTPUT_IFS; g_if++) begin : g__output_if
            // (Local) interfaces
            alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) __gather_if [N_GATHER] (.clk);

            packet_gather      #(
                .IGNORE_RDY     ( IGNORE_RDY_OUT ),
                .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
                .NUM_BUFFERS    ( NUM_BUFFERS ),
                .BUFFER_SIZE    ( BUFFER_SIZE  ),
                .MAX_RD_LATENCY ( MAX_RD_LATENCY ),
                .MAX_BURST_LEN  ( MAX_BURST_LEN ),
                .N              ( N_GATHER )
            ) i_packet_gather   (
                .clk,
                .srst,
                .packet_if      ( packet_out_if [g_if] ),
                .gather_if      ( __gather_if          ),
                .descriptor_if  ( desc_out_if   [g_if] ),
                .event_if       ( event_out_if  [g_if] ),
                .mem_rd_if      ( mem_rd_if     [g_if] ),
                .mem_init_done
            );

            for (genvar g_gather_if = 0; g_gather_if < N_GATHER; g_gather_if++) begin : g__gather_if
                alloc_intf_load_connector i_alloc_intf_load_connector (
                    .from_tx ( __gather_if[g_gather_if] ),
                    .to_rx   ( gather_if[g_if+NUM_OUTPUT_IFS*g_gather_if] )
                );
            end : g__gather_if

        end : g__output_if
    endgenerate

endmodule : packet_sg_core
