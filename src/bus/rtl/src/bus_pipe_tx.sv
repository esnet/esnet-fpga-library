// Bus pipeline Tx
//
// Implements transmitter end of bus interface pipeline
//
// Evaluates valid <-> ready handshake at Tx boundary; forwarded
// valid indication represents accepted transactions.
module bus_pipe_tx (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameter checking
    bus_intf_parameter_check param_check (.*);

    // Evaluate valid <-> ready handshake at input
    logic valid;

    assign to_rx.valid = from_tx.valid && to_rx.ready;
    assign to_rx.data  = from_tx.data;
    assign from_tx.ready = to_rx.ready;

endmodule : bus_pipe_tx
