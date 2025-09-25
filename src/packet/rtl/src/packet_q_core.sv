module packet_q_core
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

    input logic                 mem_init_done
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
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) scatter_if [NUM_INPUT_IFS]  (.clk, .srst);
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) gather_if  [NUM_OUTPUT_IFS] (.clk, .srst);

    packet_intf #(.DATA_BYTE_WID(MEM_WR_DATA_BYTE_WID), .META_WID(META_WID)) packet_to_q_if   [NUM_INPUT_IFS]  (.clk, .srst);
    packet_intf #(.DATA_BYTE_WID(MEM_RD_DATA_BYTE_WID), .META_WID(META_WID)) packet_from_q_if [NUM_OUTPUT_IFS] (.clk, .srst);

    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_to_q_if   [NUM_INPUT_IFS]  (.clk, .srst);
    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_from_q_if [NUM_OUTPUT_IFS] (.clk, .srst);

    packet_event_intf event_in_if  [NUM_INPUT_IFS]  (.clk);
    packet_event_intf event_out_if [NUM_OUTPUT_IFS] (.clk);

    // -----------------------------
    // Signals
    // -----------------------------
    logic  init_done__alloc_sg;

    // -- Recycle interface
    logic               recycle_req;
    logic               recycle_rdy;
    logic [PTR_WID-1:0] recycle_ptr;

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
    alloc_sg_core #(
        .SCATTER_CONTEXTS ( NUM_INPUT_IFS ),
        .GATHER_CONTEXTS  ( NUM_OUTPUT_IFS ),
        .PTR_WID          ( PTR_WID ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_PKT_SIZE ),
        .META_WID         ( META_WID ),
        .SIM__FAST_INIT   ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL   ( SIM__RAM_MODEL )
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
                .event_if      ( event_in_if  [g_if] ),
                .mem_wr_if     ( mem_wr_if    [g_if] ),
                .mem_init_done
            );

        end : g__input_if

        // Memory read controller
        // - 'Gather' packets from memory
        for (genvar g_if = 0; g_if < NUM_OUTPUT_IFS; g_if++) begin : g__output_if
            packet_gather      #(
                .IGNORE_RDY     ( IGNORE_RDY_OUT ),
                .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
                .NUM_BUFFERS    ( NUM_BUFFERS ),
                .BUFFER_SIZE    ( BUFFER_SIZE  ),
                .MAX_RD_LATENCY ( MAX_RD_LATENCY )
            ) i_packet_gather   (
                .clk,
                .srst,
                .packet_if      ( packet_out_if [g_if] ),
                .gather_if      ( gather_if     [g_if] ),
                .descriptor_if  ( desc_out_if   [g_if] ),
                .event_if       ( event_out_if  [g_if] ),
                .mem_rd_if      ( mem_rd_if     [g_if] ),
                .mem_init_done
            );

        end : g__output_if
    endgenerate

endmodule : packet_q_core
