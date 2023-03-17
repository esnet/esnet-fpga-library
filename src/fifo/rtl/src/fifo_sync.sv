module fifo_sync #(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 32,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    // Derived parameters (don't override)
    parameter int CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1),
    // Debug parameters
    parameter bit DEBUG_ILA = 1'b0
) (
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    // Write interface
    input  logic               wr,
    input  DATA_T              wr_data,

    // Read interface
    input  logic               rd,
    output logic               rd_ack,
    output DATA_T              rd_data,

    // Status
    output logic [CNT_WID-1:0] count,
    output logic               full,
    output logic               empty,

    output logic               oflow,
    output logic               uflow
);

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf axil_if__unused ();

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_core #(
        .DATA_T ( DATA_T ),
        .DEPTH  ( DEPTH ),
        .ASYNC  ( 0 ),
        .FWFT   ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT ),
        .AXIL_IF    ( 0 ),
        .DEBUG_ILA  ( DEBUG_ILA )
    ) i_fifo_core (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr       ( wr ),
        .wr_data  ( wr_data ),
        .wr_count ( ),
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd       ( rd ),
        .rd_ack   ( rd_ack ),
        .rd_data  ( rd_data ),
        .rd_count ( count ),
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .axil_if  ( axil_if__unused )
    );

    // Tie off (unused AXI-L interface)
    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if(axil_if__unused));
    
endmodule : fifo_sync
