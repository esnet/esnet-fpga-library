// (Bidirectional) bus register stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: This will violate the valid/ready contract on
//       both Tx and Rx sides, and must be accommodated
//       by e.g. a pipelining FIFO stage
module bus_reg (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    // Parameters
    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    // Parameter checking
    initial begin
        std_pkg::param_check($bits(bus_if_to_rx.DATA_T), DATA_WID, "bus_if_to_rx.DATA_T");
    end

    // Signals
    (* shreg_extract = "no" *) logic  srst;
    (* shreg_extract = "no" *) logic  valid;
    (* shreg_extract = "no" *) DATA_T data;
    (* shreg_extract = "no" *) logic  ready;

    initial begin
        srst = 1'b1;
        valid = 1'b0;
    end
    always @(posedge bus_if_from_tx.clk) begin
        srst  <= bus_if_from_tx.srst;
        valid <= bus_if_from_tx.valid;
        data  <= bus_if_from_tx.data;
    end

    assign bus_if_to_rx.srst = srst;
    assign bus_if_to_rx.valid = valid;
    assign bus_if_to_rx.data = data;

    initial ready = 1'b0;
    always @(posedge bus_if_from_tx.clk) begin
        ready <= bus_if_to_rx.ready;
    end

    assign bus_if_from_tx.ready = ready;

endmodule : bus_reg
