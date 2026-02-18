module fifo_ctxt #(
    parameter int DATA_WID = 1,
    parameter int DEPTH = 32,
    // Simulation-only parameters
    parameter int REPORT_OFLOW = 1,
    parameter int REPORT_UFLOW = 0
) (
    // Clock/reset
    input  logic                clk,
    input  logic                srst,

    // Write interface
    output logic                wr_rdy,
    input  logic                wr,
    input  logic [DATA_WID-1:0] wr_data,

    input  logic                rd,
    output logic                rd_vld,
    output logic [DATA_WID-1:0] rd_data,

    output logic                oflow,
    output logic                uflow
);

    generate
        if (DEPTH > 1) begin : g__std_latency
            // (Local) Parameters
            localparam int CTXT_DEPTH = DEPTH + 1; // Allow for simultaneous write/read during steady-state operation

            // (Local) Interfaces
            fifo_mon_intf wr_mon_if__unused (.clk(clk));
            fifo_mon_intf rd_mon_if__unused (.clk(clk));

            // Instantiate FIFO core
            fifo_core #(
                .DATA_WID ( DATA_WID ),
                .DEPTH    ( CTXT_DEPTH ),
                .ASYNC    ( 0 ),
                .FWFT     ( 1 ),
                .OFLOW_PROT ( 1 ),
                .UFLOW_PROT ( 1 ),
                .WR_OPT_MODE ( fifo_pkg::OPT_MODE_LATENCY ),
                .RD_OPT_MODE ( fifo_pkg::OPT_MODE_LATENCY ),
                .REPORT_OFLOW ( REPORT_OFLOW ),
                .REPORT_UFLOW ( REPORT_UFLOW )
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
        end : g__std_latency
        else begin : g__min_latency
            assign wr_rdy = !rd_vld || rd;
            assign oflow = wr && !wr_rdy;

            initial rd_vld <= 1'b0;
            always @(posedge clk) begin
                if (srst)    rd_vld <= 1'b0;
                else if (wr) rd_vld <= 1'b1;
                else if (rd) rd_vld <= 1'b0;
            end

            always_ff @(posedge clk) if (wr && wr_rdy) rd_data <= wr_data;

            assign uflow = rd && !rd_vld;
`ifndef SYNTHESIS
            if (REPORT_OFLOW) begin : g__report_oflow
                always @(posedge clk) begin
                    if (!srst && oflow) $display("[%0t] FIFO overflow in: %m", $time);
                end
            end : g__report_oflow
            if (REPORT_UFLOW) begin : g__report_uflow
                always @(posedge clk) begin
                    if (!srst && uflow) $display("[%0t] FIFO underflow in: %m", $time);
                end
            end : g__report_uflow
`endif
        end : g__min_latency
    endgenerate

endmodule : fifo_ctxt
