module fifo_sync_axil #(
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
    output logic               wr_rdy,
    input  logic               wr,
    input  DATA_T              wr_data,
    output logic [CNT_WID-1:0] wr_count,
    output logic               full,
    output logic               oflow,

    // Read interface
    input  logic               rd,
    output logic               rd_ack,
    output DATA_T              rd_data,
    output logic [CNT_WID-1:0] rd_count,
    output logic               empty,
    output logic               uflow,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral      axil_if
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic [31:0] __wr_count;
    logic [31:0] __rd_count;

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
        .AXIL_IF    ( 1 ),
        .DEBUG_ILA  ( DEBUG_ILA )
    ) i_fifo_core (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy   ( wr_rdy ),
        .wr       ( wr ),
        .wr_data  ( wr_data ),
        .wr_count ( __wr_count ),
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd       ( rd ),
        .rd_ack   ( rd_ack ),
        .rd_data  ( rd_data ),
        .rd_count ( __rd_count ),
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .axil_if  ( axil_if )
    );

    assign wr_count = __wr_count[CNT_WID-1:0];
    assign rd_count = __rd_count[CNT_WID-1:0];

endmodule : fifo_sync_axil
