module fifo_ctxt #(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 32
) (
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    // Write interface
    output logic               wr_rdy,
    input  logic               wr,
    input  DATA_T              wr_data,

    input  logic               rd,
    output logic               rd_vld,
    output DATA_T              rd_data,

    output logic               oflow,
    output logic               uflow
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int CTXT_DEPTH = DEPTH + 1; // Allow for simultaneous write/read during steady-state operation

    // -----------------------------
    // Interfaces
    // -----------------------------
    fifo_mon_intf wr_mon_if__unused (.clk(clk));
    fifo_mon_intf rd_mon_if__unused (.clk(clk));

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_core #(
        .DATA_T ( DATA_T ),
        .DEPTH  ( CTXT_DEPTH ),
        .ASYNC  ( 0 ),
        .FWFT   ( 1 ),
        .OFLOW_PROT ( 1 ),
        .UFLOW_PROT ( 1 ),
        .WR_OPT_MODE ( fifo_pkg::OPT_MODE_LATENCY ),
        .RD_OPT_MODE ( fifo_pkg::OPT_MODE_LATENCY )
    ) i_fifo_core (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy,
        .wr,
        .wr_data,
        .wr_count ( ),
        .wr_full  ( ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd,
        .rd_ack   ( rd_vld ),
        .rd_data,
        .rd_count ( ),
        .rd_empty ( ),
        .rd_uflow ( uflow ),
        .wr_mon_if ( wr_mon_if__unused ),
        .rd_mon_if ( rd_mon_if__unused )
    );

endmodule : fifo_ctxt
