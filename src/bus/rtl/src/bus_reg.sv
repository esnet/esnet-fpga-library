// (Bidirectional) bus register stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: This will violate the valid/ready contract on
//       both Tx and Rx sides, and must be accommodated
//       by e.g. a pipelining FIFO stage
module bus_reg #(
    parameter bit IGNORE_READY = 1'b0
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    (* DONT_TOUCH *) logic  valid;
    (* DONT_TOUCH *) DATA_T data;

    always @(posedge bus_if_from_tx.clk) begin
        valid <= bus_if_from_tx.valid;
        data  <= bus_if_from_tx.data;
    end

    assign bus_if_to_rx.valid = valid;
    assign bus_if_to_rx.data = data;

    generate
        if (IGNORE_READY) begin : g__ignore_ready
            assign bus_if_from_tx.ready = 1'b1;
        end : g__ignore_ready
        else begin : g__obey_ready
            (* DONT_TOUCH *) logic  ready;
            always @(posedge bus_if_from_tx.clk) ready <= bus_if_to_rx.ready;
            assign bus_if_from_tx.ready = ready;
        end : g__obey_ready
    endgenerate

endmodule : bus_reg
