module bus_pipe_slr_wrapper
(
    input  logic        clk,
    input  logic        srst_in,
    input  logic        valid_in,
    input  logic [31:0] data_in,
    output logic        ready_in,
    output logic        srst_out,
    output logic        valid_out,
    output logic [31:0] data_out,
    input  logic        ready_out
);

    bus_intf #(.DATA_T(logic[31:0])) from_tx (.clk(clk));
    bus_intf #(.DATA_T(logic[31:0])) to_rx   (.clk(clk));

    assign from_tx.srst  = srst_in;
    assign from_tx.valid = valid_in;
    assign from_tx.data  = data_in;
    assign ready_in = from_tx.ready;

    assign srst_out = to_rx.srst;
    assign valid_out = to_rx.valid;
    assign data_out = to_rx.data;
    assign to_rx.ready = ready_out;

    bus_pipe_slr #(.DATA_T(logic[31:0])) i_bus_pipe_slr (.*);

endmodule : bus_pipe_slr_wrapper
