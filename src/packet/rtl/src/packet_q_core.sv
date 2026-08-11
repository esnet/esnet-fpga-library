module packet_q_core
#(
    parameter int  NUM_INPUT_IFS = 1,
    parameter int  NUM_OUTPUT_IFS = 1,
    parameter int  NUM_QS = 8,
    parameter int  Q_DEPTH = 1024,
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
    // Derived parameters (don't override)
    parameter int  PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1),
    parameter int  INPUT_SEL_WID = NUM_INPUT_IFS > 1 ? $clog2(NUM_INPUT_IFS) : 1,
    parameter int  OUTPUT_SEL_WID = NUM_OUTPUT_IFS > 1 ? $clog2(NUM_OUTPUT_IFS) : 1,
    parameter int  Q_SEL_WID = NUM_QS > 1 ? $clog2(NUM_QS) : 1,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1,
    parameter bit  SIM__RAM_MODEL = 1
 ) (
    input  logic                      clk,
    input  logic                      srst,

    output logic                      init_done,

    // Packet input
    packet_intf.rx                    packet_in_if   [NUM_INPUT_IFS],
    input  logic [OUTPUT_SEL_WID-1:0] packet_in_dest [NUM_INPUT_IFS],
    input  logic [Q_SEL_WID-1:0]      packet_in_q    [NUM_INPUT_IFS],

    mem_wr_intf.controller            packet_desc_mem_wr_if,
    mem_wr_intf.controller            packet_data_mem_wr_if [NUM_INPUT_IFS],

    // Packet enqueue status interface
    output logic                      enq_ack  [NUM_OUTPUT_IFS],
    output logic                      enq_nack [NUM_OUTPUT_IFS],
    output logic [INPUT_SEL_WID-1:0]  enq_src  [NUM_OUTPUT_IFS],
    output logic [Q_SEL_WID-1:0]      enq_q    [NUM_OUTPUT_IFS],
    output logic [PKT_SIZE_WID-1:0]   enq_size [NUM_OUTPUT_IFS],

    // Dequeue control interface
    input  logic                      deq_req  [NUM_OUTPUT_IFS],
    output logic                      deq_rdy  [NUM_OUTPUT_IFS],
    input  logic [Q_SEL_WID-1:0]      deq_q    [NUM_OUTPUT_IFS],
    output logic                      deq_ack  [NUM_OUTPUT_IFS],
    output logic                      deq_nack [NUM_OUTPUT_IFS],
    output logic [INPUT_SEL_WID-1:0]  deq_src  [NUM_OUTPUT_IFS],
    output logic [PKT_SIZE_WID-1:0]   deq_size [NUM_OUTPUT_IFS],

    // Q management memory interfaces
    mem_wr_intf.controller            q_mem_wr_if [NUM_OUTPUT_IFS],
    mem_rd_intf.controller            q_mem_rd_if [NUM_OUTPUT_IFS],

    // Packet output
    packet_intf.tx                    packet_out_if  [NUM_OUTPUT_IFS],
    output logic [INPUT_SEL_WID-1:0]  packet_out_src [NUM_OUTPUT_IFS],
    output logic [Q_SEL_WID-1:0]      packet_out_q   [NUM_OUTPUT_IFS],

    mem_rd_intf.controller            packet_desc_mem_rd_if,
    mem_rd_intf.controller            packet_data_mem_rd_if [NUM_OUTPUT_IFS],

    input logic                       mem_init_done,

    axi4l_intf.peripheral             axil_if
);
    localparam int PTR_WID = $clog2(NUM_BUFFERS);
    localparam int META_OPAQUE_WID = packet_in_if[0].META_WID;
    localparam int DATA_BYTE_WID = packet_in_if[0].DATA_BYTE_WID;

    typedef struct packed {
        logic [META_OPAQUE_WID-1:0] opaque;
        logic [Q_SEL_WID-1:0]       q;
        logic [OUTPUT_SEL_WID-1:0]  dest;
        logic [INPUT_SEL_WID-1:0]   src;
    } meta_t;
    localparam int META_WID = $bits(meta_t);

    // Signals
    logic                      packet_sg_core__init_done;
    logic [NUM_OUTPUT_IFS-1:0] packet_q_manager__init_done;
    logic [Q_SEL_WID-1:0] desc_in_q_demux [NUM_OUTPUT_IFS][NUM_INPUT_IFS];
    logic [Q_SEL_WID-1:0] desc_out_q [NUM_OUTPUT_IFS];

    // Interfaces
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) __packet_in_if [NUM_INPUT_IFS] (.clk);
    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_in_if [NUM_INPUT_IFS] (.clk);
    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_in_if_demux [NUM_OUTPUT_IFS][NUM_INPUT_IFS] (.clk);
    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_out_if [NUM_OUTPUT_IFS] (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) __packet_out_if [NUM_OUTPUT_IFS] (.clk);

    localparam int PACKET_Q_DECODER_NUM_OUTPUT_IFS = 4;

    axi4l_intf packet_sg_core__axil_if ();
    axi4l_intf packet_q_manager__axil_if [NUM_OUTPUT_IFS] ();
    axi4l_intf packet_q_decoder__q_mgr_axil_if [PACKET_Q_DECODER_NUM_OUTPUT_IFS] ();

    // AXI-L decoder: sg at 0x0, q_mgr_0..3 at 0x1000..0x4000
    packet_q_decoder i_packet_q_decoder (
        .axil_if         ( axil_if ),
        .sg_axil_if      ( packet_sg_core__axil_if ),
        .q_mgr_0_axil_if ( packet_q_decoder__q_mgr_axil_if[0] ),
        .q_mgr_1_axil_if ( packet_q_decoder__q_mgr_axil_if[1] ),
        .q_mgr_2_axil_if ( packet_q_decoder__q_mgr_axil_if[2] ),
        .q_mgr_3_axil_if ( packet_q_decoder__q_mgr_axil_if[3] )
    );

    generate
        for (genvar g = 0; g < PACKET_Q_DECODER_NUM_OUTPUT_IFS; g++) begin : g__q_mgr_axil
            if (g < NUM_OUTPUT_IFS) begin : g__connect
                axi4l_intf_connector i_axi4l_intf_connector (
                    .axi4l_if_from_controller ( packet_q_decoder__q_mgr_axil_if[g] ),
                    .axi4l_if_to_peripheral   ( packet_q_manager__axil_if[g] )
                );
            end : g__connect
            else begin : g__tieoff
                axi4l_intf_peripheral_term i_axi4l_intf_peripheral_term (
                    .axi4l_if ( packet_q_decoder__q_mgr_axil_if[g] )
                );
            end : g__tieoff
        end : g__q_mgr_axil
    endgenerate

    // Init done
    assign init_done = packet_sg_core__init_done && &packet_q_manager__init_done;

    generate
        for (genvar g_in_if = 0; g_in_if < NUM_INPUT_IFS; g_in_if++) begin : g__input_if
            // (Local) signals
            meta_t __meta;
            meta_t __desc_meta;
            logic [NUM_OUTPUT_IFS-1:0] desc_in_if__rdy;

            // Pack output port and queue selection into metadata
            assign __meta.opaque = packet_in_if[g_in_if].meta;
            assign __meta.q = packet_in_q[g_in_if];
            assign __meta.dest = packet_in_dest[g_in_if];
            assign __meta.src = g_in_if;
            packet_intf_set_meta #(
                .META_WID ( META_WID )
            ) i_packet_intf_set_meta (
                .from_tx ( packet_in_if[g_in_if] ),
                .to_rx   ( __packet_in_if[g_in_if] ),
                .meta    ( __meta )
            );

            // Demux descriptors to physical output ports
            assign __desc_meta = desc_in_if[g_in_if].meta;
            for (genvar g_out_if = 0; g_out_if < NUM_OUTPUT_IFS; g_out_if++) begin : g__output_if
                // (Local) signals
                meta_t __desc_in_meta;
                // (Local) interfaces
                packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) __desc_in_if (.clk);

                assign __desc_in_if.vld  = desc_in_if[g_in_if].vld && (__desc_meta.dest == g_out_if);
                assign __desc_in_if.addr = desc_in_if[g_in_if].addr;
                assign __desc_in_if.size = desc_in_if[g_in_if].size;
                assign __desc_in_if.err  = desc_in_if[g_in_if].err;
                assign __desc_in_if.meta = desc_in_if[g_in_if].meta;
                assign desc_in_if__rdy[g_out_if] = __desc_in_if.rdy;

                packet_descriptor_fifo #(
                    .DEPTH ( 512 )
                ) i_packet_descriptor_fifo (
                    .from_tx      ( __desc_in_if ),
                    .from_tx_srst ( srst ),
                    .to_rx        ( desc_in_if_demux[g_out_if][g_in_if] ),
                    .to_rx_srst   ( srst )
                );
                assign __desc_in_meta = desc_in_if_demux[g_out_if][g_in_if].meta;
                assign desc_in_q_demux[g_out_if][g_in_if] = __desc_in_meta.q;
            end : g__output_if
            always_comb begin
                desc_in_if[g_in_if].rdy = 1'b0;
                if (desc_in_if[g_in_if].vld) desc_in_if[g_in_if].rdy = desc_in_if__rdy[__desc_meta.dest];
            end
        end : g__input_if
    endgenerate

    // Packet scatter-gather core
    packet_sg_core     #(
        .NUM_INPUT_IFS  ( NUM_INPUT_IFS ),
        .NUM_OUTPUT_IFS ( NUM_OUTPUT_IFS ),
        .IGNORE_RDY_IN  ( IGNORE_RDY_IN ),
        .IGNORE_RDY_OUT ( IGNORE_RDY_OUT ),
        .DROP_ERRORED   ( DROP_ERRORED ),
        .MIN_PKT_SIZE   ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
        .NUM_BUFFERS    ( NUM_BUFFERS ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .MAX_RD_LATENCY ( MAX_RD_LATENCY ),
        .MAX_BURST_LEN  ( MAX_BURST_LEN ),
        .N_ALLOC        ( N_ALLOC ),
        .N_GATHER       ( N_GATHER )
    ) i_packet_sg_core  (
        .clk,
        .srst,
        .init_done ( packet_sg_core__init_done ),
        .packet_in_if   ( __packet_in_if ),
        .desc_mem_wr_if ( packet_desc_mem_wr_if ),
        .mem_wr_if      ( packet_data_mem_wr_if ),
        .desc_in_if     ( desc_in_if ),
        .desc_out_if    ( desc_out_if ),
        .packet_out_if  ( __packet_out_if ),
        .desc_mem_rd_if ( packet_desc_mem_rd_if ),
        .mem_rd_if      ( packet_data_mem_rd_if ),
        .mem_init_done,
        .axil_if        ( packet_sg_core__axil_if )
    );

    generate
        for (genvar g_out_if = 0; g_out_if < NUM_OUTPUT_IFS; g_out_if++) begin : g__output_if
            // (Local) signals
            meta_t __meta;
            meta_t __desc_meta;

            // Packet queue manager
            // (one per physical output port)
            packet_q_manager #(
                .NUM_INPUT_IFS ( NUM_INPUT_IFS ),
                .NUM_QS        ( NUM_QS ),
                .Q_DEPTH       ( Q_DEPTH ),
                .MAX_PKT_SIZE  ( MAX_PKT_SIZE ),
                .NUM_TRANSACTIONS ( MAX_RD_LATENCY )
            ) i_packet_q_manager (
                .clk,
                .srst,
                .init_done         ( packet_q_manager__init_done [g_out_if] ),
                .desc_in_q         ( desc_in_q_demux [g_out_if] ),
                .desc_in_if        ( desc_in_if_demux[g_out_if] ),
                .enq_ack           ( enq_ack[g_out_if] ),
                .enq_nack          ( enq_nack[g_out_if] ),
                .enq_src           ( enq_src [g_out_if] ),
                .enq_q             ( enq_q   [g_out_if] ),
                .enq_size          ( enq_size[g_out_if] ),
                .deq_req           ( deq_req [g_out_if] ),
                .deq_rdy           ( deq_rdy [g_out_if] ),
                .deq_q             ( deq_q   [g_out_if] ),
                .deq_ack           ( deq_ack [g_out_if] ),
                .deq_nack          ( deq_nack[g_out_if] ),
                .deq_src           ( deq_src [g_out_if] ),
                .deq_size          ( deq_size[g_out_if] ),
                .desc_out_if       ( desc_out_if[g_out_if] ),
                .desc_out_q        ( desc_out_q [g_out_if] ),
                .mem_init_done,
                .q_mem_wr_if       ( q_mem_wr_if[g_out_if] ),
                .q_mem_rd_if       ( q_mem_rd_if[g_out_if] ),
                .axil_if           ( packet_q_manager__axil_if[g_out_if] )
            );

            // Unpack input port and queue selection from metadata
            assign __meta = __packet_out_if[g_out_if].meta;
            assign packet_out_q  [g_out_if] = __meta.q;
            assign packet_out_src[g_out_if] = __meta.src;
            packet_intf_set_meta #(
                .META_WID ( META_OPAQUE_WID)
            ) i_packet_intf_set_meta (
                .from_tx ( __packet_out_if[g_out_if] ),
                .to_rx   ( packet_out_if[g_out_if] ),
                .meta    ( __meta.opaque )
            );
        end : g__output_if
    endgenerate
endmodule : packet_q_core
