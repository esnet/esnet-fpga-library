module fifo_async #(
    parameter int DATA_WID = 1,
    parameter int DEPTH = 32,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    // Simulation-only parameters
    parameter bit REPORT_OFLOW = 0,
    parameter bit REPORT_UFLOW = 0,
    // Derived parameters (don't override)
    parameter int CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1)
) (
    // Write interface (synchronous to wr_clk)
    input  logic                wr_clk,
    input  logic                wr_srst,
    output logic                wr_rdy,
    input  logic                wr,
    input  logic [DATA_WID-1:0] wr_data,
    output logic [CNT_WID-1:0]  wr_count,
    output logic                wr_full,
    output logic                wr_oflow,

    // Read interface (synchronous to rd_clk)
    input  logic                rd_clk,
    input  logic                rd_srst,
    input  logic                rd,
    output logic                rd_ack,
    output logic [DATA_WID-1:0] rd_data,
    output logic [CNT_WID-1:0]  rd_count,
    output logic                rd_empty,
    output logic                rd_uflow
);

    // -----------------------------
    // Interfaces
    // -----------------------------
    fifo_mon_intf wr_mon_if__unused (.clk(wr_clk));
    fifo_mon_intf rd_mon_if__unused (.clk(rd_clk));

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_core    #(
        .DATA_WID ( DATA_WID ),
        .DEPTH    ( DEPTH ),
        .ASYNC    ( 1 ),
        .FWFT     ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT ),
        .REPORT_OFLOW ( REPORT_OFLOW ),
        .REPORT_UFLOW ( REPORT_UFLOW )
    ) i_fifo_core (
        .wr_clk,
        .wr_srst,
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
        .wr_mon_if ( wr_mon_if__unused ),
        .rd_mon_if ( rd_mon_if__unused )
    );
      
endmodule : fifo_async
