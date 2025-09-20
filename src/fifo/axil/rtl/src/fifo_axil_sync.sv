module fifo_axil_sync #(
    parameter int DATA_WID = 1,
    parameter int DEPTH = 32,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    // Derived parameters (don't override)
    parameter int CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1)
) (
    // Clock/reset
    input  logic                clk,
    input  logic                srst,

    // Write interface
    output logic                wr_rdy,
    input  logic                wr,
    input  logic [DATA_WID-1:0] wr_data,
    output logic [CNT_WID-1:0]  wr_count,
    output logic                full,
    output logic                oflow,

    // Read interface
    input  logic                rd,
    output logic                rd_ack,
    output logic [DATA_WID-1:0] rd_data,
    output logic [CNT_WID-1:0]  rd_count,
    output logic                empty,
    output logic                uflow,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral       axil_if
);

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_axil_core #(
        .DATA_WID ( DATA_WID ),
        .DEPTH    ( DEPTH ),
        .ASYNC    ( 0 ),
        .FWFT     ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT )
    ) i_fifo_axil_core (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy,
        .wr,
        .wr_data,
        .wr_count,
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd,
        .rd_ack,
        .rd_data,
        .rd_count,
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .axil_if
    );

endmodule : fifo_axil_sync
