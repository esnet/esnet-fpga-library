interface bus_intf #(
    parameter int DATA_WID = 1
) (
    input logic clk
);

    // Parameter validation
    initial begin
        std_pkg::param_check_gt(DATA_WID, 1, "DATA_WID");
    end

    // Signals
    logic                valid;
    logic                ready;
    logic [DATA_WID-1:0] data;

    // Modports
    modport tx (
        input  clk,
        output valid,
        input  ready,
        output data
    );

    modport rx (
        input  clk,
        input  valid,
        output ready,
        input  data
    );

    // Sample driven signals separately for verification agents.
    wire mon_valid = valid;
    wire mon_ready = ready;
    wire [DATA_WID-1:0] mon_data = data;

    clocking cb @(posedge clk);
        inout valid, ready, data;
        input mon_valid, mon_ready, mon_data;
    endclocking

endinterface : bus_intf


module bus_intf_connector (
    bus_intf.rx from_tx,
    bus_intf.tx to_rx
);
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
    end

    // Connect Tx to Rx signals
    assign to_rx.valid = from_tx.valid;
    assign to_rx.data = from_tx.data;

    // Connect Rx to Tx signals
    assign from_tx.ready = to_rx.ready;

endmodule : bus_intf_connector
