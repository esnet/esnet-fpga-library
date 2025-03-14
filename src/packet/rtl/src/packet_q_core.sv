module packet_q_core
#(
    parameter int  NUM_INPUT_IFS = 1,
    parameter int  NUM_OUTPUT_IFS = 1,
    parameter int  DATA_BYTE_WID = 1,
    parameter bit  IGNORE_RDY_IN = 0,
    parameter bit  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  BUFFER_SIZE = 2048,
    parameter type PTR_T = logic,
    parameter type META_T = logic,
    parameter int  MAX_RD_LATENCY = 8
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

    input logic                 mem_init_done
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);
    localparam type SIZE_T = logic[SIZE_WID-1:0];

    localparam int  PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1);
    localparam type PKT_SIZE_T = logic[PKT_SIZE_WID-1:0];

    // -----------------------------
    // Parameter checking
    // -----------------------------
    generate
        for (genvar i = 0; i < NUM_INPUT_IFS; i++) begin
            initial std_pkg::param_check($bits(packet_in_if[i].META_T), $bits(META_T), $sformatf("packet_in_if[%0d].META_T", i));
            initial std_pkg::param_check(packet_in_if[i].DATA_BYTE_WID, DATA_BYTE_WID, $sformatf("packet_in_if[%0d].DATA_BYTE_WID", i));
            initial std_pkg::param_check($bits(desc_in_if[i].META_T), $bits(META_T), $sformatf("desc_in_if[%0d].META_T", i));
        end
        for (genvar i = 0; i < NUM_OUTPUT_IFS; i++) begin
            initial std_pkg::param_check($bits(packet_out_if[i].META_T), $bits(META_T), $sformatf("packet_out_if[%0d].META_T", i));
            initial std_pkg::param_check(packet_out_if[i].DATA_BYTE_WID, DATA_BYTE_WID, $sformatf("packet_out_if[%0d].DATA_BYTE_WID", i));
            initial std_pkg::param_check($bits(desc_out_if[i].META_T), $bits(META_T), $sformatf("desc_out_if[%0d].META_T", i));
        end
    endgenerate

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_T(PTR_T), .META_T(META_T)) scatter_if [NUM_INPUT_IFS]  (.clk, .srst);
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_T(PTR_T), .META_T(META_T)) gather_if  [NUM_OUTPUT_IFS] (.clk, .srst);

    packet_event_intf event_in_if__unused  [NUM_INPUT_IFS]  ();
    packet_event_intf event_out_if__unused [NUM_OUTPUT_IFS] ();

    // -----------------------------
    // Signals
    // -----------------------------
    logic  init_done__alloc_sg;

    // -- Recycle interface
    logic  recycle_req;
    logic  recycle_rdy;
    PTR_T  recycle_ptr;

    // -- Frame completion
    logic      frame_valid [NUM_INPUT_IFS];
    logic      frame_error;
    PTR_T      frame_ptr;
    PKT_SIZE_T frame_size;

    // -----------------------------
    // Status
    // -----------------------------
    assign init_done = mem_init_done && init_done__alloc_sg;

    // -----------------------------
    // Scatter-gather controller
    // -----------------------------
    alloc_sg_core #(
        .SCATTER_CONTEXTS ( NUM_INPUT_IFS ),
        .GATHER_CONTEXTS  ( NUM_OUTPUT_IFS ),
        .PTR_T            ( PTR_T ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_PKT_SIZE ),
        .META_T           ( META_T )
    ) i_alloc_sg_core (
        .clk,
        .srst,
        .en ( 1'b1 ),
        .init_done ( init_done__alloc_sg ),
        .BUFFERS   ( 0 ), // No limit, i.e. BUFFERS = 2**PTR_WID
        .scatter_if,
        .gather_if,
        .recycle_req,
        .recycle_rdy,
        .recycle_ptr,
        .desc_mem_wr_if,
        .desc_mem_rd_if,
        .desc_mem_init_done ( mem_init_done ),
        .frame_valid,
        .frame_error,
        .frame_ptr,
        .frame_size
    );

    generate
        // 'Scatter' packets into memory on input
        for (genvar g_if = 0; g_if < NUM_INPUT_IFS; g_if++) begin : g__input_if
            // (Local) interfaces
            packet_event_intf event_if__unused (.clk);

            packet_scatter    #(
                .IGNORE_RDY    ( IGNORE_RDY_IN ),
                .DROP_ERRORED  ( DROP_ERRORED ),
                .MIN_PKT_SIZE  ( MIN_PKT_SIZE ),
                .MAX_PKT_SIZE  ( MAX_PKT_SIZE ),
                .BUFFER_SIZE   ( BUFFER_SIZE ),
                .PTR_T         ( PTR_T ),
                .META_T        ( META_T )
            ) i_packet_scatter ( 
                .clk,
                .srst,
                .packet_if     ( packet_in_if[g_if] ),
                .scatter_if    ( scatter_if  [g_if] ),
                .descriptor_if ( desc_in_if  [g_if] ),
                .event_if      ( event_in_if__unused [g_if] ),
                .mem_wr_if     ( mem_wr_if   [g_if] ),
                .mem_init_done
            );
        end : g__input_if

        // 'Gather' packets from memory on output
        for (genvar g_if = 0; g_if < NUM_OUTPUT_IFS; g_if++) begin : g__output_if
            // (Local) interfaces
            packet_event_intf event_if__unused (.clk);

            packet_gather      #(
                .IGNORE_RDY     ( IGNORE_RDY_OUT ),
                .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
                .BUFFER_SIZE    ( BUFFER_SIZE  ),
                .PTR_T          ( PTR_T ),
                .META_T         ( META_T ),
                .MAX_RD_LATENCY ( MAX_RD_LATENCY )
            ) i_packet_gather   (
                .clk,
                .srst,
                .packet_if      ( packet_out_if[g_if] ),
                .gather_if      ( gather_if    [g_if] ),
                .descriptor_if  ( desc_out_if  [g_if] ),
                .event_if       ( event_out_if__unused [g_if] ),
                .mem_rd_if      ( mem_rd_if    [g_if] ),
                .mem_init_done
            );
        end : g__output_if
    endgenerate

endmodule : packet_q_core
