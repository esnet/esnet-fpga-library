// (Bidirectional) bus register stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: This will violate the valid/ready contract on
//       both Tx and Rx sides, and must be accommodated
//       by e.g. a pipelining FIFO stage
module bus_reg (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int DATA_WID = from_tx.DATA_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
    end

    // Signals
    logic clk;
    (* shreg_extract = "no" *) logic                valid;
    (* shreg_extract = "no" *) logic [DATA_WID-1:0] data;
    (* shreg_extract = "no" *) logic                ready;

    assign clk = from_tx.clk;

    initial valid = 1'b0;
    always @(posedge clk) begin
        if (from_tx.srst) valid <= 1'b0;
        else              valid <= from_tx.valid;
    end

    always_ff @(posedge clk) begin
        data  <= from_tx.data;
    end

    assign to_rx.valid = valid;
    assign to_rx.data = data;

    initial ready = 1'b0;
    always @(posedge clk) begin
        ready <= to_rx.ready;
    end

    assign from_tx.ready = ready;

endmodule : bus_reg
