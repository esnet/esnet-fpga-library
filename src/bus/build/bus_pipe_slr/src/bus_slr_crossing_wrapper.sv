module bus_pipe_slr_wrapper
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

    bus_intf #(.DATA_T(logic[31:0])) bus_if_from_tx (.clk(clk), .srst(srst));
    bus_intf #(.DATA_T(logic[31:0])) bus_if_to_rx   (.clk(clk), .srst(srst));

    assign bus_if_from_tx.valid = valid_in;
    assign bus_if_from_tx.data  = data_in;
    assign ready_in = bus_if_from_tx.ready;

    assign valid_out = bus_if_to_rx.valid;
    assign data_out = bus_if_to_rx.data;
    assign bus_if_to_rx.ready = ready_out;

    bus_pipe_slr i_bus_pipe_slr (.*);

endmodule : bus_pipe_slr_wrapper
