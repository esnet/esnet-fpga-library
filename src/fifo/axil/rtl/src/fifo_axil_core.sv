module fifo_axil_core
    import fifo_pkg::*;
#(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 4,
    parameter bit ASYNC = 1,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    parameter opt_mode_t WR_OPT_MODE = OPT_MODE_TIMING,
    parameter opt_mode_t RD_OPT_MODE = OPT_MODE_TIMING,
    // Derived parameters (don't override)
    parameter int CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1)
) (
    // Write interface
    input  logic                wr_clk,
    input  logic                wr_srst,
    output logic                wr_rdy,
    input  logic                wr,
    input  DATA_T               wr_data,
    output logic [CNT_WID-1:0]  wr_count,
    output logic                wr_full,
    output logic                wr_oflow,

    // Read interface
    input  logic                rd_clk,
    input  logic                rd_srst,
    input  logic                rd,
    output logic                rd_ack,
    output DATA_T               rd_data,
    output logic [CNT_WID-1:0]  rd_count,
    output logic                rd_empty,
    output logic                rd_uflow,

    // AXI-L control/monitoring
    axi4l_intf.peripheral       axil_if
);
    // -----------------------------
    // Signals
    // -----------------------------
    logic soft_reset__wr_clk;
    logic __wr_srst;

    // -----------------------------
    // Interfaces
    // -----------------------------
    fifo_wr_mon_intf wr_mon_if (.clk(wr_clk));
    fifo_rd_mon_intf rd_mon_if (.clk(rd_clk));

    fifo_wr_mon_intf __wr_mon_if (.clk(wr_clk));
    fifo_rd_mon_intf __rd_mon_if (.clk(rd_clk));

    axi4l_intf axil_ctrl_if   ();
    axi4l_intf axil_wr_mon_if ();
    axi4l_intf axil_rd_mon_if ();

    axi4l_intf axil_wr_mon_if__wr_clk ();
    axi4l_intf axil_rd_mon_if__rd_clk ();

    fifo_ctrl_reg_intf ctrl_reg_if ();
    fifo_wr_mon_reg_intf wr_mon_reg_if ();
    fifo_rd_mon_reg_intf rd_mon_reg_if ();

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_core #(
        .DATA_T ( DATA_T ),
        .DEPTH  ( DEPTH ),
        .ASYNC  ( ASYNC ),
        .FWFT   ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT )
    ) i_fifo_core (
        .wr_clk,
        .wr_srst  ( __wr_srst ),
        .wr_rdy,
        .wr,
        .wr_data,
        .wr_count,
        .wr_full,
        .wr_oflow,
        .rd_clk,
        .rd_srst,
        .rd,
        .rd_ack,
        .rd_data,
        .rd_count,
        .rd_empty,
        .rd_uflow,
        .wr_mon_if ( wr_mon_if ),
        .rd_mon_if ( rd_mon_if )
    );

    // -----------------------------
    // AXI-L control and monitoring
    // -----------------------------
    // Main decoder
    // TEMP: Workaround elaboration bug in Vivado 2023.2 where interface array port
    //       (axil_client_if[2]) in axi4l_decoder submodule is reported as not present.
    //       Instantiating the axi4l_decoder module here directly seems to avoid the issue.
    /*
    // FIFO block-level decoder
    fifo_decoder i_fifo_decoder (
        .axil_if        ( axil_if ),
        .ctrl_axil_if   ( axil_ctrl_if ),
        .wr_mon_axil_if ( axil_wr_mon_if ),
        .rd_mon_axil_if ( axil_rd_mon_if )
    );
    */
    axi4l_decoder #(
        .MEM_MAP   ( fifo_decoder_pkg::MEM_MAP)
    ) i_axi4l_decoder (
        .axi4l_if        ( axil_if ),
        .axi4l_client_if ( '{axil_ctrl_if, axil_wr_mon_if, axil_rd_mon_if} )
    );

    fifo_ctrl_reg_blk i_fifo_ctrl_reg_blk (
        .axil_if    ( axil_ctrl_if ),
        .reg_blk_if ( ctrl_reg_if )
    );

    // Soft reset (retime to write domain)
    sync_level #(
        .RST_VALUE ( 1'b0 )
    ) i_sync_level__soft_reset_wr_clk (
        .clk_in   ( axil_if.aclk ),
        .rst_in   ( !axil_if.aresetn ),
        .rdy_in   ( ),
        .lvl_in   ( ctrl_reg_if.control.reset ),
        .clk_out  ( wr_clk ),
        .rst_out  ( 1'b0 ),
        .lvl_out  ( soft_reset__wr_clk )
    );

    // Combine block-level and soft resets
    initial __wr_srst = 1'b1;
    always @(posedge wr_clk) begin
        if (wr_srst || soft_reset__wr_clk) __wr_srst <= 1'b1;
        else                               __wr_srst <= 1'b0;
    end

    // Export parameterization info
    assign ctrl_reg_if.info_nxt_v = 1'b1;
    assign ctrl_reg_if.info_nxt.fifo_type  = ASYNC      ? fifo_ctrl_reg_pkg::INFO_FIFO_TYPE_ASYNC :
                                                          fifo_ctrl_reg_pkg::INFO_FIFO_TYPE_SYNC;
    assign ctrl_reg_if.info_nxt.oflow_prot = OFLOW_PROT ? fifo_ctrl_reg_pkg::INFO_OFLOW_PROT_ENABLED :
                                                          fifo_ctrl_reg_pkg::INFO_OFLOW_PROT_DISABLED;
    assign ctrl_reg_if.info_nxt.uflow_prot = UFLOW_PROT ? fifo_ctrl_reg_pkg::INFO_UFLOW_PROT_ENABLED :
                                                          fifo_ctrl_reg_pkg::INFO_UFLOW_PROT_DISABLED;
    assign ctrl_reg_if.info_nxt.fwft_mode  = FWFT       ? fifo_ctrl_reg_pkg::INFO_FWFT_MODE_FWFT :
                                                          fifo_ctrl_reg_pkg::INFO_FWFT_MODE_STD;
    assign ctrl_reg_if.info_depth_nxt_v = 1'b1;
    assign ctrl_reg_if.info_depth_nxt = DEPTH;

    assign ctrl_reg_if.info_width_nxt_v = 1'b1;
    assign ctrl_reg_if.info_width_nxt = $bits(DATA_T);


    // Write monitoring (cross to wr_clk domain)
    axi4l_intf_cdc i_axi4l_cdc_wr_mon (
        .axi4l_if_from_controller( axil_wr_mon_if ),
        .clk_to_peripheral       ( wr_clk ),
        .axi4l_if_to_peripheral  ( axil_wr_mon_if__wr_clk )
    );

    fifo_wr_mon_reg_blk i_fifo_wr_mon_reg_blk (
        .axil_if    ( axil_wr_mon_if__wr_clk ),
        .reg_blk_if ( wr_mon_reg_if )
    );

    // Pipeline monitored signals
    fifo_wr_mon_intf_pipe i_fifo_wr_mon_pipe (
        .fifo_wr_mon_if_from_peripheral ( wr_mon_if ),
        .fifo_wr_mon_if_to_controller   ( __wr_mon_if )
    );

    assign wr_mon_reg_if.status_nxt_v = 1'b1;
    assign wr_mon_reg_if.status_count_nxt_v = 1'b1;
    assign wr_mon_reg_if.status_wr_ptr_nxt_v = 1'b1;
    
    assign wr_mon_reg_if.status_nxt.reset  = __wr_mon_if.reset;
    assign wr_mon_reg_if.status_nxt.full   = __wr_mon_if.full;
    assign wr_mon_reg_if.status_nxt.oflow  = __wr_mon_if.oflow;
    assign wr_mon_reg_if.status_count_nxt  = __wr_mon_if.count;
    assign wr_mon_reg_if.status_wr_ptr_nxt = __wr_mon_if.ptr;

    // Read monitoring (cross to rd_clk domain)
    axi4l_intf_cdc i_axi4l_cdc_rd_mon (
        .axi4l_if_from_controller ( axil_rd_mon_if ),
        .clk_to_peripheral        ( rd_clk ),
        .axi4l_if_to_peripheral   ( axil_rd_mon_if__rd_clk )
    );

    fifo_rd_mon_reg_blk i_fifo_rd_mon_reg_blk (
        .axil_if    ( axil_rd_mon_if__rd_clk ),
        .reg_blk_if ( rd_mon_reg_if )
    );

    // Pipeline monitored signals
    fifo_rd_mon_intf_pipe i_fifo_rd_mon_pipe (
        .fifo_rd_mon_if_from_peripheral ( rd_mon_if ),
        .fifo_rd_mon_if_to_controller   ( __rd_mon_if )
    );

    assign rd_mon_reg_if.status_nxt_v = 1'b1;
    assign rd_mon_reg_if.status_count_nxt_v = 1'b1;
    assign rd_mon_reg_if.status_rd_ptr_nxt_v = 1'b1;
    
    assign rd_mon_reg_if.status_nxt.reset  = __rd_mon_if.reset;
    assign rd_mon_reg_if.status_nxt.empty  = __rd_mon_if.empty;
    assign rd_mon_reg_if.status_nxt.uflow  = __rd_mon_if.uflow;
    assign rd_mon_reg_if.status_count_nxt  = __rd_mon_if.count;
    assign rd_mon_reg_if.status_rd_ptr_nxt = __rd_mon_if.ptr;

endmodule : fifo_axil_core
