// (Bidirectional) bus register stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: This will violate the valid/ready contract on
//       both Tx and Rx sides, and must be accommodated
//       by e.g. a pipelining FIFO stage
module bus_reg #(
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
    logic clk;
    (* shreg_extract = "no" *) logic  srst;
    (* shreg_extract = "no" *) logic  valid;
    (* shreg_extract = "no" *) DATA_T data;
    (* shreg_extract = "no" *) logic  ready;

    assign clk = from_tx.clk;

    initial begin
        srst = 1'b1;
        valid = 1'b0;
    end
    always @(posedge clk) begin
        srst  <= from_tx.srst;
        valid <= from_tx.valid;
        data  <= from_tx.data;
    end

    assign to_rx.srst = srst;
    assign to_rx.valid = valid;
    assign to_rx.data = data;

    initial ready = 1'b0;
    always @(posedge clk) begin
        ready <= to_rx.ready;
    end

    assign from_tx.ready = ready;

endmodule : bus_reg
