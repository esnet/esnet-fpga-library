module fifo_axil_async #(
    parameter int DATA_WID = 1,
    parameter int DEPTH = 32,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    // Derived parameters (don't override)
    parameter int CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1)
) (
    // Write interface
    input  logic                wr_clk,
    input  logic                wr_srst,
    output logic                wr_rdy,
    input  logic                wr,
    input  logic [DATA_WID-1:0] wr_data,
    output logic [CNT_WID-1:0]  wr_count,
    output logic                wr_full,
    output logic                wr_oflow,

    // Read interface
    input  logic                rd_clk,
    input  logic                rd_srst,
    input  logic                rd,
    output logic                rd_ack,
    output logic [DATA_WID-1:0] rd_data,
    output logic [CNT_WID-1:0]  rd_count,
    output logic                rd_empty,
    output logic                rd_uflow,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral      axil_if
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic [CNT_WID-1:0] __rd_count;

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_axil_core #(
        .DATA_WID   ( DATA_WID ),
        .DEPTH      ( DEPTH ),
        .ASYNC      ( 1 ),
        .FWFT       ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT )
    ) i_fifo_axil_core (.*);
   
endmodule : fifo_axil_async
