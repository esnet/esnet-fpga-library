module packet_q_core
#(
    parameter int  NUM_INPUT_IFS = 1,  // Allowed values are 1 or N * NUM_MEM_WR_IFS
    parameter int  NUM_MEM_WR_IFS = 1, // Allowed values are 1 or N * NUM_INPUT_IFS
    parameter int  NUM_OUTPUT_IFS = 1, // Allowed values are 1 or N * NUM_MEM_RD_IFS
    parameter int  NUM_MEM_RD_IFS = 1, // Allowed values are 1 or N * NUM_OUTPUT_IFS
    parameter bit  IGNORE_RDY_IN = 0,
    parameter bit  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  BUFFER_SIZE = 2048,
    parameter type PTR_T = logic,
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
    mem_wr_intf.controller      mem_wr_if [NUM_MEM_WR_IFS],

    // Packet completion interface (to/from queue controller)
    packet_descriptor_intf.tx   desc_in_if [NUM_INPUT_IFS],
    packet_descriptor_intf.rx   desc_out_if[NUM_OUTPUT_IFS],
    
    // Packet output (synchronous to packet_out_if.clk)
    packet_intf.tx              packet_out_if [NUM_OUTPUT_IFS],

    mem_rd_intf.controller      desc_mem_rd_if,
    mem_rd_intf.controller      mem_rd_if [NUM_MEM_RD_IFS],

    input logic                 mem_init_done
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);
    localparam type SIZE_T = logic[SIZE_WID-1:0];

    localparam int  PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1);
    localparam type PKT_SIZE_T = logic[PKT_SIZE_WID-1:0];

    localparam int  META_WID = $bits(packet_in_if[0].META_T);
    localparam type META_T = logic[META_WID-1:0];

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
        if (NUM_INPUT_IFS < NUM_MEM_WR_IFS) initial std_pkg::param_check(NUM_MEM_WR_IFS % NUM_INPUT_IFS, 0, "NUM_MEM_WR_IFS");
        else                                initial std_pkg::param_check(NUM_INPUT_IFS % NUM_MEM_WR_IFS, 0, "NUM_INPUT_IFS");
        if (NUM_OUTPUT_IFS < NUM_MEM_RD_IFS) initial std_pkg::param_check(NUM_MEM_RD_IFS % NUM_OUTPUT_IFS, 0, "NUM_MEM_RD_IFS");
        else                                 initial std_pkg::param_check(NUM_OUTPUT_IFS % NUM_MEM_RD_IFS, 0, "NUM_OUTPUT_IFS");
        for (genvar i = 0; i < NUM_INPUT_IFS; i++) begin
            initial std_pkg::param_check($bits(packet_in_if[i].META_T), $bits(META_T), $sformatf("packet_in_if[%0d].META_T", i));
            initial std_pkg::param_check(packet_in_if[i].DATA_BYTE_WID, DATA_IN_BYTE_WID, $sformatf("packet_in_if[%0d].DATA_BYTE_WID", i));
            initial std_pkg::param_check($bits(desc_in_if[i].META_T), $bits(META_T), $sformatf("desc_in_if[%0d].META_T", i));
            initial std_pkg::param_check(mem_wr_if[i].DATA_WID, MEM_WR_DATA_WID, $sformatf("mem_wr_if[%0d].DATA_WID", i));
        end
        for (genvar i = 0; i < NUM_OUTPUT_IFS; i++) begin
            initial std_pkg::param_check($bits(packet_out_if[i].META_T), $bits(META_T), $sformatf("packet_out_if[%0d].META_T", i));
            initial std_pkg::param_check(packet_out_if[i].DATA_BYTE_WID, DATA_OUT_BYTE_WID, $sformatf("packet_out_if[%0d].DATA_BYTE_WID", i));
            initial std_pkg::param_check($bits(desc_out_if[i].META_T), $bits(META_T), $sformatf("desc_out_if[%0d].META_T", i));
            initial std_pkg::param_check(mem_rd_if[i].DATA_WID, MEM_RD_DATA_WID, $sformatf("mem_rd_if[%0d].DATA_WID", i));
        end
    endgenerate

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_T(PTR_T), .META_T(META_T)) scatter_if [NUM_MEM_WR_IFS] (.clk, .srst);
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_T(PTR_T), .META_T(META_T)) gather_if  [NUM_MEM_RD_IFS] (.clk, .srst);

    packet_intf #(.DATA_BYTE_WID(MEM_WR_DATA_BYTE_WID), .META_T(META_T)) packet_to_q_if   [NUM_MEM_WR_IFS] (.clk, .srst);
    packet_intf #(.DATA_BYTE_WID(MEM_RD_DATA_BYTE_WID), .META_T(META_T)) packet_from_q_if [NUM_MEM_RD_IFS] (.clk, .srst);

    packet_descriptor_intf #(.ADDR_T(PTR_T), .META_T(META_T)) desc_to_q_if   [NUM_MEM_WR_IFS] (.clk);
    packet_descriptor_intf #(.ADDR_T(PTR_T), .META_T(META_T)) desc_from_q_if [NUM_MEM_RD_IFS] (.clk);

    packet_event_intf event_in_if__unused  [NUM_INPUT_IFS]  (.clk);
    packet_event_intf event_out_if__unused [NUM_OUTPUT_IFS] (.clk);

    // -----------------------------
    // Signals
    // -----------------------------
    logic  init_done__alloc_sg;

    // -- Recycle interface
    logic  recycle_req;
    logic  recycle_rdy;
    PTR_T  recycle_ptr;

    // -- Frame completion
    logic      frame_valid [NUM_MEM_WR_IFS];
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
        .SCATTER_CONTEXTS ( NUM_MEM_WR_IFS ),
        .GATHER_CONTEXTS  ( NUM_MEM_RD_IFS ),
        .PTR_T            ( PTR_T ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_PKT_SIZE ),
        .META_T           ( META_T ),
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

    // Per-input-port processing
    generate
        for (genvar g_if = 0; g_if < NUM_INPUT_IFS; g_if++) begin : g__input_if

            // Disaggregation step
            // - split incoming packets across multiple narrower interfaces to impedance-match to memory write interface
            if (NUM_MEM_WR_IFS > NUM_INPUT_IFS) begin : g__disaggregate_in
                // (Local) parameters
                localparam int N = NUM_MEM_WR_IFS / NUM_INPUT_IFS;
                localparam int SEL_WID = $clog2(N);
                localparam type SEL_T = logic[SEL_WID-1:0];
                // (Local) interfaces
                packet_intf #(.DATA_BYTE_WID(MEM_WR_DATA_BYTE_WID), .META_T(META_T)) __packet_in_if [N] (.clk, .srst);
                packet_descriptor_intf #(.ADDR_T(PTR_T), .META_T(META_T)) __desc_if [N] (.clk);
                packet_event_intf __event_if__unused [N] (.clk);
                // (Local) signals
                logic ctxt_valid;
                SEL_T ctxt;
                logic ctxt_ack;
                logic  __desc_in_if_valid [N];
                PTR_T  __desc_in_if_addr  [N];
                SIZE_T __desc_in_if_size  [N];
                logic  __desc_in_if_err   [N];
                META_T __desc_in_if_meta  [N];

                // Split incoming packets across multiple narrower interfaces
                packet_disaggregate #(
                    .NUM_OUTPUTS   ( N ),
                    .ASYNC         ( 0 ),
                    .IGNORE_RDY_IN ( IGNORE_RDY_IN ),
                    .MAX_PKT_SIZE  ( MAX_PKT_SIZE ),
                    .MIN_PKT_SIZE  ( MIN_PKT_SIZE ),
                    .MUX_MODE      ( packet_pkg::MUX_MODE_RR )
                ) i_packet_disaggregate (
                    .packet_in_if  ( packet_in_if       [g_if] ),
                    .event_in_if   ( event_in_if__unused[g_if] ),
                    .ctxt_out_valid( ctxt_valid ),
                    .ctxt_out      ( ctxt ),
                    .ctxt_out_ack  ( ctxt_ack ),
                    .packet_out_if ( __packet_in_if ),
                    .event_out_if  ( __event_if__unused )
                );

                assign ctxt_ack = desc_in_if[g_if].valid && desc_in_if[g_if].rdy;

                for (genvar g_mem_if = 0; g_mem_if < N; g_mem_if++) begin : g__mem_if
                    packet_intf_connector i_packet_intf_connector (.from_tx (__packet_in_if[g_mem_if]), .to_rx(packet_to_q_if[g_if*N + g_mem_if]));
                    packet_descriptor_fifo #(
                        .DEPTH ( 32 )
                    ) i_packet_descriptor_fifo (
                        .from_tx ( desc_to_q_if [g_if*N + g_mem_if] ),
                        .to_rx   ( __desc_if [g_mem_if])
                    );
                    assign __desc_in_if_valid[g_mem_if] = __desc_if[g_mem_if].valid;
                    assign __desc_in_if_addr[g_mem_if]  = __desc_if[g_mem_if].addr;
                    assign __desc_in_if_size[g_mem_if]  = __desc_if[g_mem_if].size;
                    assign __desc_in_if_err[g_mem_if]   = __desc_if[g_mem_if].err;
                    assign __desc_in_if_meta[g_mem_if]  = __desc_if[g_mem_if].meta;
                    assign __desc_if[g_mem_if].rdy =  ctxt_valid && (ctxt == g_mem_if) ? desc_in_if[g_if].rdy : 1'b0;
                end : g__mem_if

                // Recombine completion stream (in order)
                assign desc_in_if[g_if].valid = ctxt_valid ? __desc_in_if_valid[ctxt] : 1'b0;
                assign desc_in_if[g_if].addr  = __desc_in_if_addr[ctxt];
                assign desc_in_if[g_if].size  = __desc_in_if_size[ctxt];
                assign desc_in_if[g_if].err   = __desc_in_if_err [ctxt];
                assign desc_in_if[g_if].meta  = __desc_in_if_meta[ctxt];

            end : g__disaggregate_in
            else if (NUM_INPUT_IFS > NUM_MEM_WR_IFS) begin : g__aggregate_in
                $fatal(2, "NOT YET SUPPORTED");
            end : g__aggregate_in
            else begin : g__direct_in
                //packet_intf_connector i_packet_intf_connector (.from_tx(packet_in_if[g_if]), .to_rx(packet_to_q_if[g_if]));
                packet_descriptor_intf_connector i_packet_descriptor_intf_connector (.from_tx (desc_to_q_if[g_if]), .to_rx(desc_in_if[g_if]));
            end : g__direct_in
        end : g__input_if

        // Memory write controller
        // - 'Scatter' packets into memory
        for (genvar g_if = 0; g_if < NUM_MEM_WR_IFS; g_if++) begin : g__mem_wr_if
            // (Local) interfaces
            packet_event_intf event_if__unused (.clk);

            // Scatter controller
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
                .packet_if     ( packet_to_q_if[g_if] ),
                .scatter_if    ( scatter_if    [g_if] ),
                .descriptor_if ( desc_to_q_if  [g_if] ),
                .event_if      ( event_if__unused ),
                .mem_wr_if     ( mem_wr_if     [g_if] ),
                .mem_init_done
            );
        end : g__mem_wr_if

        // Memory read controller
        // - 'Gather' packets from memory
        for (genvar g_if = 0; g_if < NUM_MEM_RD_IFS; g_if++) begin : g__mem_rd_if
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
                .packet_if      ( packet_from_q_if[g_if] ),
                .gather_if      ( gather_if       [g_if] ),
                .descriptor_if  ( desc_from_q_if  [g_if] ),
                .event_if       ( event_if__unused ),
                .mem_rd_if      ( mem_rd_if       [g_if] ),
                .mem_init_done
            );

        end : g__mem_rd_if

        // Per-output-port processing
        for (genvar g_if = 0; g_if < NUM_OUTPUT_IFS; g_if++) begin : g__output_if
            
            // Aggregation step
            // - combine packets into larger output interface to impedance-match to memory read interface
            if (NUM_MEM_RD_IFS > NUM_OUTPUT_IFS) begin : g__aggregate_out
                // (Local) parameters
                localparam int N = NUM_MEM_RD_IFS / NUM_OUTPUT_IFS;
                localparam int SEL_WID = $clog2(N);
                localparam type SEL_T = logic[SEL_WID-1:0];
                // (Local) interfaces
                packet_intf #(.DATA_BYTE_WID(MEM_RD_DATA_BYTE_WID), .META_T(META_T)) __packet_out_if [N] (.clk, .srst);
                packet_descriptor_intf #(.ADDR_T(PTR_T), .META_T(META_T)) __desc_if [N] (.clk);
                packet_event_intf __event_if__unused [N] (.clk);
                // (Local) signals
                SEL_T  sel;
                logic  desc_from_q_if_rdy [N];

                // Split incoming packets across multiple narrower interfaces
                initial sel = 0;
                always @(posedge clk) begin
                    if (desc_out_if[g_if].valid && desc_out_if[g_if].rdy) begin
                        if (sel < N-1) sel <= sel + 1;
                        else           sel <= 0;
                    end
                end

                for (genvar g_mem_if = 0; g_mem_if < N; g_mem_if++) begin : g__mem_if
                    packet_intf_connector i_packet_intf_connector (.from_tx (packet_from_q_if[g_if*N + g_mem_if]), .to_rx(__packet_out_if[g_mem_if]));

                    assign desc_from_q_if[g_if*N + g_mem_if].valid = (sel == g_mem_if) ? desc_out_if[g_if].valid : 1'b0;
                    assign desc_from_q_if[g_if*N + g_mem_if].addr  = desc_out_if[g_if].addr;
                    assign desc_from_q_if[g_if*N + g_mem_if].size  = desc_out_if[g_if].size;
                    assign desc_from_q_if[g_if*N + g_mem_if].err   = desc_out_if[g_if].err;
                    assign desc_from_q_if[g_if*N + g_mem_if].meta  = desc_out_if[g_if].meta;
                    assign desc_from_q_if_rdy[g_mem_if]   = desc_from_q_if[g_if*N + g_mem_if].rdy;
                end : g__mem_if

                assign desc_out_if[g_if].rdy = desc_from_q_if_rdy[sel];

                packet_aggregate   #(
                    .NUM_INPUTS     ( N ),
                    .ASYNC          ( 0 ),
                    .IGNORE_RDY_OUT ( IGNORE_RDY_OUT ),
                    .DROP_ERRORED   ( 0 ),
                    .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
                    .MIN_PKT_SIZE   ( MIN_PKT_SIZE ),
                    .MUX_MODE       ( packet_pkg::MUX_MODE_LIST )
                ) i_packet_aggregate (
                    .packet_in_if   ( __packet_out_if ),
                    .event_in_if    ( __event_if__unused ),
                    .ctxt_list_append_req  ( desc_out_if[g_if].valid && desc_out_if[g_if].rdy ),
                    .ctxt_list_append_data ( sel ),
                    .ctxt_list_append_rdy  ( ),
                    .packet_out_if  ( packet_out_if       [g_if] ),
                    .event_out_if   ( event_out_if__unused[g_if] )
                );
            end : g__aggregate_out
            else if (NUM_OUTPUT_IFS > NUM_MEM_WR_IFS) begin : g__disaggregate_out
                $fatal(2, "NOT YET SUPPORTED");
            end : g__disaggregate_out
            else begin : g__direct_in
                packet_intf_connector i_packet_intf_connector (.from_tx(packet_from_q_if[g_if]), .to_rx(packet_out_if[g_if]));
                packet_descriptor_intf_connector i_packet_descriptor_intf_connector (.from_tx (desc_out_if[g_if]), .to_rx(desc_from_q_if[g_if]));
            end : g__direct_in
        end : g__output_if
    endgenerate

endmodule : packet_q_core
