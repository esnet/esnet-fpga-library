// Bus interface pipeline stage
//
// Includes register stages and a pipelining FIFO receiver stage
// to accommodate the required number of stages of slack in
// valid <-> ready handshaking protocol
module bus_pipe #(
    parameter int  STAGES = 1 // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int  TOTAL_SLACK = 2*STAGES;
    localparam int  DATA_WID = from_tx.DATA_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
        std_pkg::param_check_gt(STAGES, 1, "STAGES");
    end

    // Clock/reset
    logic clk;
    logic srst;

    assign clk = from_tx.clk;
    assign srst = from_tx.srst;

    // Interfaces
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx (.clk, .srst);

    // Pipeline transmitter
    bus_pipe_tx i_bus_pipe_tx (
        .from_tx,
        .to_rx   ( bus_if__tx )
    );

    // Add pipeline stages as specified
    bus_reg     #(
        .STAGES  ( STAGES )
    ) i_bus_reg  (
        .from_tx ( bus_if__tx ),
        .to_rx   ( bus_if__rx )
    );

    // Pipeline receiver
    bus_pipe_rx #(
        .TOTAL_SLACK ( TOTAL_SLACK )
    ) i_bus_pipe_rx (
        .from_tx ( bus_if__rx ),
        .to_rx
    );

endmodule : bus_pipe
