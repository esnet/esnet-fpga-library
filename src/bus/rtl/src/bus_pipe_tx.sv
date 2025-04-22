// Bus pipeline Tx
//
// Implements transmitter end of bus interface pipeline
//
// Evaluates valid <-> ready handshake at Tx boundary; forwarded
// valid indication represents accepted transactions.
module bus_pipe_tx #(
    parameter type DATA_T = logic
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameter checking
    initial begin
        std_pkg::param_check($bits(from_tx.DATA_T), $bits(DATA_T), "from_tx.DATA_T");
        std_pkg::param_check($bits(to_rx.DATA_T),   $bits(DATA_T), "to_rx.DATA_T");
    end

    // Signals
    (* shreg_extract = "no" *) logic srst;
    (* shreg_extract = "no" *) logic valid;
    (* shreg_extract = "no" *) DATA_T data;
    (* shreg_extract = "no" *) logic ready;

    // Evaluate valid <-> ready handshake at input
    initial valid = 1'b0;
    always @(posedge from_tx.clk) begin
        if (from_tx.srst) valid <= 1'b0;
        else              valid <= from_tx.valid && from_tx.ready;
    end

    initial srst = 1'b1;
    always @(posedge from_tx.clk) begin
        srst <= from_tx.srst;
        data <= from_tx.data;
    end

    assign to_rx.srst = srst;
    assign to_rx.valid = valid;
    assign to_rx.data = data;

    initial ready = 1'b0;
    always @(posedge from_tx.clk) begin
        if (from_tx.srst) ready <= 1'b0;
        else              ready <= to_rx.ready;
    end

    assign from_tx.ready = ready;

endmodule : bus_pipe_tx
