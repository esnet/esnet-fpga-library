module fifo_core
    import fifo_pkg::*;
#(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 4,
    parameter bit ASYNC = 1,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    parameter opt_mode_t WR_OPT_MODE = fifo_pkg::OPT_MODE_TIMING,
    parameter opt_mode_t RD_OPT_MODE = fifo_pkg::OPT_MODE_TIMING,
    // Debug parameters
    parameter bit AXIL_IF = 1'b0,
    parameter bit DEBUG_ILA = 1'b0
) (
    // Write interface
    input  logic        wr_clk,
    input  logic        wr_srst,
    output logic        wr_rdy,
    input  logic        wr,
    input  DATA_T       wr_data,
    output logic [31:0] wr_count,
    output logic        wr_full,
    output logic        wr_oflow,

    // Read interface
    input  logic        rd_clk,
    input  logic        rd_srst,
    input  logic        rd,
    output logic        rd_ack,
    output DATA_T       rd_data,
    output logic [31:0] rd_count,
    output logic        rd_empty,
    output logic        rd_uflow,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral      axil_if
);

    // -----------------------------
    // Imports
    // -----------------------------
    import mem_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PTR_WID = $clog2(DEPTH);
    localparam int MEM_DEPTH = 2**PTR_WID;
    localparam int __CNT_WID = $clog2(DEPTH+1);

    localparam int DATA_WID = $bits(DATA_T);

    localparam bit __UFLOW_PROT = FWFT ? 1 : UFLOW_PROT;

    localparam int MEM_WR_LATENCY = mem_pkg::get_default_wr_latency(MEM_DEPTH, DATA_WID, ASYNC);
    localparam int MEM_RD_LATENCY = mem_pkg::get_default_rd_latency(MEM_DEPTH, DATA_WID, ASYNC);
    localparam int MEM_RD_LATENCY_CNT_WID = $clog2(MEM_RD_LATENCY+1);

    localparam mem_rd_mode_t MEM_RD_MODE = FWFT ? mem_pkg::FWFT : STD;

    // -----------------------------
    // Signals
    // -----------------------------
    logic                 soft_reset__aclk;
    logic                 rst__async;

    logic                 local_wr_srst;
    logic                 local_rd_srst;

    logic                 wr_safe;
    logic [PTR_WID-1:0]   wr_ptr;
    logic [__CNT_WID-1:0] __wr_count;

    logic                 rd_safe;
    logic [PTR_WID-1:0]   rd_ptr;
    logic                 __rd;
    logic                 __rd_empty;
    logic [__CNT_WID-1:0] __rd_count;
    logic                 __rd_uflow;
    DATA_T                __rd_data;

    logic [MEM_RD_LATENCY-1:0] rd_empty_p; // rd_empty pipeline.

    logic mem_init_done;

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_intf #(.ADDR_WID (PTR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(wr_clk));
    mem_intf #(.ADDR_WID (PTR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(rd_clk));

    axi4l_intf ctrl_axil_if ();

    // -----------------------------
    // Resets
    // -----------------------------
    // Combine resets
    assign rst__async = wr_srst || rd_srst || soft_reset__aclk;

    // Synchronize combined reset to write and read clock domains
    sync_level #(
        .RST_VALUE ( 1'b1 )
    ) i_sync_level__local_wr_srst (
        .lvl_in  ( rst__async ),
        .clk_out ( wr_clk ),
        .rst_out ( wr_srst ),
        .lvl_out ( local_wr_srst )
    );
    sync_level #(
        .RST_VALUE ( 1'b1 )
    ) i_sync_level__local_rd_srst (
        .lvl_in  ( rst__async ),
        .clk_out ( rd_clk ),
        .rst_out ( rd_srst ),
        .lvl_out ( local_rd_srst )
    );

    // -----------------------------
    // Control FSM
    // -----------------------------
    fifo_ctrl_fsm  #(
        .DEPTH      ( DEPTH ),
        .MEM_WR_LATENCY ( MEM_WR_LATENCY ),
        .ASYNC      ( ASYNC ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( __UFLOW_PROT ),
        .WR_OPT_MODE( WR_OPT_MODE ),
        .RD_OPT_MODE( RD_OPT_MODE ),
        .AXIL_IF    ( AXIL_IF ),
        .DEBUG_ILA  ( DEBUG_ILA )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( wr_clk ),
        .wr_srst  ( local_wr_srst ),
        .wr_rdy   ( wr_rdy ),
        .wr       ( wr ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( wr_ptr ),
        .wr_count ( __wr_count ),
        .wr_full  ( wr_full ),
        .wr_oflow ( wr_oflow ),
        .rd_clk   ( rd_clk ),
        .rd_srst  ( local_rd_srst ),
        .rd       ( __rd ),
        .rd_safe  ( rd_safe ),
        .rd_ptr   ( rd_ptr ),
        .rd_count ( __rd_count ),
        .rd_empty ( __rd_empty ),
        .rd_uflow ( __rd_uflow ),
        .mem_rdy  ( mem_init_done ),
        .axil_if  ( ctrl_axil_if )
    );

    // -----------------------------
    // Data memory
    // -----------------------------
    mem_ram_sdp_core #(
        .MEM_RD_MODE ( MEM_RD_MODE ),
        .ADDR_WID  ( PTR_WID ),
        .DATA_WID  ( DATA_WID ),
        .ASYNC     ( ASYNC ),
        .RESET_FSM ( 0 )
    ) i_ram_data (
        .wr_clk    ( wr_clk ),
        .wr_srst   ( local_wr_srst ),
        .mem_wr_if ( mem_wr_if ),
        .rd_clk    ( rd_clk ),
        .rd_srst   ( local_rd_srst ),
        .mem_rd_if ( mem_rd_if ),
        .init_done ( mem_init_done )
    );

    assign mem_wr_if.rst = 1'b0;
    assign mem_wr_if.en = 1'b1;
    assign mem_wr_if.req = wr_safe;
    assign mem_wr_if.addr = wr_ptr;
    assign mem_wr_if.data = wr_data;

    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.en = 1'b1; // Unused
    assign mem_rd_if.req = __rd;  // use __rd signal rather than rd_safe (to advance rd pipeline when memory is empty).
    assign mem_rd_if.addr = rd_ptr;
    assign __rd_data = mem_rd_if.data;


    generate
        // First word flow-through FIFO mode
        if (FWFT) begin : g__fwft
            // large FIFOs (more than one output stage)
            if (MEM_RD_LATENCY > 1) begin : g__fwft_large
                // track empty indication of each pipe stage through FWFT prefetch pipeline.
                initial rd_empty_p = '0;
                always @(posedge rd_clk) begin
                    if (local_rd_srst) rd_empty_p <= '1;
                    else if (__rd)     rd_empty_p <= {rd_empty_p[MEM_RD_LATENCY-2:0], __rd_empty};
                end

                // empty indication reflects presence/absence of data in LAST stage.
                assign rd_empty = rd_empty_p[MEM_RD_LATENCY-1];

                // Adjust count for entries in FWFT prefetch pipeline.
                assign rd_count = {'0, __rd_count} + count_ones(~rd_empty_p[MEM_RD_LATENCY-1:0]);
            end : g__fwft_large

            // small FIFOs (single-stage output)
            else if (MEM_RD_LATENCY == 1) begin : g__fwft_small
                // empty indication reflects presence/absence of data in LAST stage.
                initial rd_empty = 1'b1;
                always @(posedge rd_clk) begin
                    if (local_rd_srst)    rd_empty <= 1'b1;
                    else if (!__rd_empty) rd_empty <= 1'b0;
                    else if (rd)          rd_empty <= 1'b1;
                end

                // Adjust count for entry in FWFT buffer
                assign rd_count = rd_empty ? {'0, __rd_count} : {'0, __rd_count} + 1;
            end : g__fwft_small


            // Data prefetch
            assign __rd = rd_empty || rd;

            assign rd_ack  = !rd_empty;
            assign rd_data = __rd_data;

            // Underflow
            assign rd_uflow = rd && rd_empty;

        end : g__fwft

        // Standard FIFO mode
        else begin : g__std
            assign __rd = rd;
            assign rd_ack   = mem_rd_if.ack;
            assign rd_data  = __rd_data;
            assign rd_count = {'0, __rd_count};
            assign rd_empty = __rd_empty;
            assign rd_uflow = __rd_uflow;

        end : g__std
    endgenerate

    // Write count
    assign wr_count = {'0, __wr_count};

   
    // AXI-L control/monitoring
    generate
        if (AXIL_IF) begin : g__axil
            // (Local) imports
            import fifo_core_reg_pkg::*;

            // (Local) interfaces
            axi4l_intf core_axil_if ();

            fifo_core_reg_intf  core_reg_if ();

            // Main decoder
            fifo_core_decoder i_fifo_core_decoder (
                .axil_if ( axil_if ),
                .core_axil_if ( core_axil_if ),
                .ctrl_axil_if ( ctrl_axil_if )
            );

            // FIFO core register block (AXI-L clock domain)
            fifo_core_reg_blk i_fifo_core_reg_blk (
                .axil_if    ( core_axil_if ),
                .reg_blk_if ( core_reg_if )
            );

            // Export (static) parameterization info
            assign core_reg_if.info_nxt_v = 1'b1;
            assign core_reg_if.info_nxt.fifo_type  = ASYNC      ? INFO_FIFO_TYPE_ASYNC :
                                                                  INFO_FIFO_TYPE_SYNC;
            assign core_reg_if.info_nxt.oflow_prot = OFLOW_PROT ? INFO_OFLOW_PROT_ENABLED :
                                                                  INFO_OFLOW_PROT_DISABLED;
            assign core_reg_if.info_nxt.uflow_prot = UFLOW_PROT ? INFO_UFLOW_PROT_ENABLED :
                                                                  INFO_UFLOW_PROT_DISABLED;
            assign core_reg_if.info_nxt.fwft_mode  = FWFT       ? INFO_FWFT_MODE_STD :
                                                                  INFO_FWFT_MODE_FWFT;

            assign core_reg_if.info_depth_nxt_v = 1'b1;
            assign core_reg_if.info_depth_nxt = DEPTH;

            // Soft reset
            assign soft_reset__aclk = core_reg_if.control.reset;
        end : g__axil
        else begin : g__no_axil
            // Terminate unused AXI-L interfaces
            axi4l_intf_peripheral_term i_axi4l_intf_peripheral_term (.axi4l_if (axil_if));
            axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if (ctrl_axil_if));

            // No soft reset
            assign soft_reset__aclk = 1'b0;
        end
    endgenerate

   // count_ones function
   function automatic logic[MEM_RD_LATENCY_CNT_WID-1:0] count_ones (input logic[MEM_RD_LATENCY-1:0] data);
      automatic logic[MEM_RD_LATENCY_CNT_WID-1:0] count = 0;
      for (int i=0; i < MEM_RD_LATENCY; i++) count = count + data[i];
      return count;
   endfunction

endmodule : fifo_core
