// Bus pipeline Tx
//
// Implements transmitter end of  bus interface pipeline
//
// Evaluates valid <-> ready handshake at Tx boundary; forwarded
// valid indication represents accepted transactions.
module bus_pipe_tx #(
    parameter type DATA_T = logic
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    // Parameter checking
    initial begin
        std_pkg::param_check($bits(bus_if_from_tx.DATA_T), $bits(DATA_T), "bus_if_from_tx.DATA_T");
        std_pkg::param_check($bits(bus_if_to_rx.DATA_T),   $bits(DATA_T), "bus_if_to_rx.DATA_T");
    end

    // Signals
    (* shreg_extract = "no" *) logic srst;
    (* shreg_extract = "no" *) logic valid;
    (* shreg_extract = "no" *) DATA_T data;
    (* shreg_extract = "no" *) logic ready;

    // Evaluate valid <-> ready handshake at input
    initial valid = 1'b0;
    always @(posedge bus_if_from_tx.clk) begin
        if (bus_if_from_tx.srst) valid <= 1'b0;
        else                     valid <= bus_if_from_tx.valid && bus_if_from_tx.ready;
    end

    initial srst = 1'b1;
    always @(posedge bus_if_from_tx.clk) begin
        srst <= bus_if_from_tx.srst;
        data <= bus_if_from_tx.data;
    end

    assign bus_if_to_rx.srst = srst;
    assign bus_if_to_rx.valid = valid;
    assign bus_if_to_rx.data = data;

    initial ready = 1'b0;
    always @(posedge bus_if_from_tx.clk) begin
        if (bus_if_from_tx.srst) ready <= 1'b0;
        else                     ready <= bus_if_to_rx.ready;
    end

    assign bus_if_from_tx.ready = ready;

endmodule : bus_pipe_tx
