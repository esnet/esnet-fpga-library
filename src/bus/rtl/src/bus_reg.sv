// (Bidirectional) bus multi-register pipelining stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: For STAGES > 0, valid/ready handshaking protocol
//       will be violated and must be accommodated by e.g.
//       bookending with bus_pipe_tx and bus_pipe_rx modules
module bus_reg #(
    parameter int STAGES = 1
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int DATA_WID = from_tx.DATA_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
        std_pkg::param_check_gt(STAGES, 0, "STAGES");
    end

    // Signals
    logic clk;

    (* shreg_extract = "no" *) logic                valid [STAGES+1];
    (* shreg_extract = "no" *) logic [DATA_WID-1:0] data  [STAGES+1];
    (* shreg_extract = "no" *) logic                ready [STAGES+1];

    // Logic
    assign clk = from_tx.clk;

    assign valid[0] = from_tx.valid;
    assign data [0] = from_tx.data;
    assign ready[0] = to_rx.ready;

    // Forward direction
    always_ff @(posedge clk) begin
        for (int i = 1; i < STAGES+1; i++) begin
            valid[i] <= valid[i-1];
            data [i] <= data [i-1];
        end
    end

    // Reverse direction
    always_ff @(posedge clk) begin
        for (int i = 1; i < STAGES+1; i++) begin
            ready[i] <= ready[i-1];
        end
    end
    
    assign to_rx.valid   = valid[STAGES];
    assign to_rx.data    = data [STAGES];
    assign from_tx.ready = ready[STAGES];

endmodule : bus_reg
