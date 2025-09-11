module bus_pipe_auto_wrapper
(
    input  logic        clk,
    input  logic        srst,
    input  logic        valid_in,
    input  logic [31:0] data_in,
    output logic        ready_in,
    output logic        valid_out,
    output logic [31:0] data_out,
    input  logic        ready_out
);

    bus_intf #(.DATA_WID(32)) from_tx (.clk, .srst);
    bus_intf #(.DATA_WID(32)) to_rx   (.clk, .srst);

    assign from_tx.valid = valid_in;
    assign from_tx.data  = data_in;
    assign ready_in = from_tx.ready;

    assign valid_out = to_rx.valid;
    assign data_out = to_rx.data;
    assign to_rx.ready = ready_out;

    bus_pipe_auto i_bus_pipe_auto (.*);

endmodule : bus_pipe_auto_wrapper
