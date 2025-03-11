// Bus pipeline Tx
//
// Implements transmitter end of  bus interface pipeline
//
// Evaluates valid <-> ready handshake at Tx boundary; forwarded
// valid indication represents accepted transactions.
module bus_pipe_tx #(
    parameter bit IGNORE_READY = 1'b0
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    logic ready;

    assign ready = IGNORE_READY ? 1'b1 : bus_if_to_rx.ready;

    // Evaluate valid <-> ready handshake at input
    assign bus_if_to_rx.srst  = bus_if_from_tx.srst;
    assign bus_if_to_rx.valid = bus_if_from_tx.valid && ready;
    assign bus_if_to_rx.data  = bus_if_from_tx.data;
    assign bus_if_from_tx.ready = ready;

endmodule : bus_pipe_tx
