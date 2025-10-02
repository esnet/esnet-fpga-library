// Bus SLR crossing (Tx + Rx)
// Implements Rx registers for forward interface (valid + data),
// and Tx registers for reverse interface (ready) such that the
// interface becomes eligible for implementation in dedicated
// SLR crossing register tiles (Laguna registers)
//
// Also includes a pipelining FIFO receiver stage to accommodate
// four stages of slack in valid <-> ready handshaking protocol
(* keep_hierarchy = "true" *) module bus_pipe_slr #(
    parameter int  PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int  POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int  TOTAL_SLACK = 2*PRE_PIPE_STAGES + 2 + 2 + 2*POST_PIPE_STAGES; // pre + SLRx + SLRy + post
    localparam int  DATA_WID = from_tx.DATA_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
        std_pkg::param_check_gt(PRE_PIPE_STAGES, 0, "PRE_PIPE_STAGES");
        std_pkg::param_check_gt(POST_PIPE_STAGES, 0, "PRE_PIPE_STAGES");
    end

    // Clock/reset
    logic clk;
    logic srst;

    assign clk = from_tx.clk;
    assign srst = from_tx.srst;

    // Interfaces
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx   (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx_p (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__sll  (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx_p (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx   (.clk, .srst);

    // Pipeline transmitter
    bus_pipe_tx i_bus_pipe_tx (
        .from_tx,
        .to_rx   ( bus_if__tx )
    );

    // (Optional) extra pipelining registers on Tx side
    bus_reg       #(
        .STAGES    ( PRE_PIPE_STAGES )
    ) i_bus_reg_tx (
        .from_tx   ( bus_if__tx ),
        .to_rx     ( bus_if__tx_p )
    );

    // Tx registers (SLRx)
    (* dont_touch = "yes" *) bus_reg i_bus_slr_tx (
        .from_tx  ( bus_if__tx_p ),
        .to_rx    ( bus_if__sll )
    );

    // Rx registers (SLRy)
    (* dont_touch = "yes" *) bus_reg i_bus_slr_rx (
        .from_tx  ( bus_if__sll ),
        .to_rx    ( bus_if__rx_p )
    );

    // (Optional) extra pipelining registers on Rx side
    bus_reg       #(
        .STAGES    ( POST_PIPE_STAGES )
    ) i_bus_reg_rx (
        .from_tx   ( bus_if__rx_p ),
        .to_rx     ( bus_if__rx )
    );

    // Pipeline receiver
    bus_pipe_rx #(
        .TOTAL_SLACK ( TOTAL_SLACK )
    ) i_bus_pipe_rx (
        .from_tx ( bus_if__rx ),
        .to_rx
    );

endmodule : bus_pipe_slr
