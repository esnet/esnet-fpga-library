module fifo_async_wrapper #(
    parameter int DATA_WID = 32,
    parameter int DEPTH = 128,
    parameter bit FWFT = 1,
    // Derived parameters (don't override)
    parameter int  CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1)
) (
    input  logic                wr_clk,
    input  logic                wr_srst,
    output logic                wr_rdy,
    input  logic                wr,
    input  logic [DATA_WID-1:0] wr_data,
    input  logic                rd_clk,
    input  logic                rd_srst,
    input  logic                rd,
    output logic                rd_ack,
    output logic [DATA_WID-1:0] rd_data,
    output logic [CNT_WID-1:0]  wr_count,
    output logic [CNT_WID-1:0]  rd_count,
    output logic                full,
    output logic                empty,
    output logic                oflow,
    output logic                uflow
);

    fifo_async #(
        .DATA_T ( logic[DATA_WID-1:0] ),
        .DEPTH  ( DEPTH )
    ) i_fifo_async (.*);

endmodule : fifo_async_wrapper
