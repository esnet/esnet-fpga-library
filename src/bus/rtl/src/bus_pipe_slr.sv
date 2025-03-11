// Bus SLR crossing (Tx + Rx)
// Implements Rx registers for forward interface (valid + data),
// and Tx registers for reverse interface (ready) such that the
// interface becomes eligible for implementation in dedicated
// SLR crossing register tiles (Laguna registers)
//
// Also includes a pipelining FIFO receiver stage to accommodate
// four stages of slack in valid <-> ready handshaking protocol
(* keep_hierarchy = "yes" *) module bus_pipe_slr #(
    parameter bit IGNORE_READY = 1'b0,
    parameter int PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    localparam int  TOTAL_SLACK = 4 + 2*PRE_PIPE_STAGES + 2*POST_PIPE_STAGES;

    bus_intf #(.DATA_T(DATA_T)) bus_if__tx   (.clk(bus_if_from_tx.clk));
    bus_intf #(.DATA_T(DATA_T)) bus_if__tx_p (.clk(bus_if_from_tx.clk));
    bus_intf #(.DATA_T(DATA_T)) bus_if__sll  (.clk(bus_if_from_tx.clk));
    bus_intf #(.DATA_T(DATA_T)) bus_if__rx_p (.clk(bus_if_from_tx.clk));
    bus_intf #(.DATA_T(DATA_T)) bus_if__rx   (.clk(bus_if_from_tx.clk));

    // Pipeline transmitter
    bus_pipe_tx #(IGNORE_READY) i_bus_pipe_tx (
        .bus_if_from_tx,
        .bus_if_to_rx ( bus_if__tx )
    );

    bus_reg_multi      #(
        .STAGES         ( PRE_PIPE_STAGES ),
        .IGNORE_READY   ( IGNORE_READY )
    ) i_bus_reg_multi_tx (
        .bus_if_from_tx ( bus_if__tx ),
        .bus_if_to_rx   ( bus_if__tx_p )
    );

    // Tx registers (SLRx)
    // (includes transmit registers for valid/data and receive register for ready)
    bus_reg #(IGNORE_READY) i_bus_slr_tx (
        .bus_if_from_tx  ( bus_if__tx_p ),
        .bus_if_to_rx    ( bus_if__sll )
    );

    // Rx registers (SLRy)
    // (includes receive registers for valid/data and transmit register for ready)
    bus_reg #(IGNORE_READY) i_bus_slr_rx (
        .bus_if_from_tx  ( bus_if__sll ),
        .bus_if_to_rx    ( bus_if__rx_p )
    );

    bus_reg_multi       #(
        .STAGES          ( POST_PIPE_STAGES ),
        .IGNORE_READY    ( IGNORE_READY )
    ) i_bus_reg_multi_rx (
        .bus_if_from_tx  ( bus_if__rx_p ),
        .bus_if_to_rx    ( bus_if__rx )
    );

    // Pipeline receiver
    bus_pipe_rx #(
        .IGNORE_READY ( IGNORE_READY ),
        .TOTAL_SLACK  ( TOTAL_SLACK ) // Account for two stages of in each of forward (valid/data)
                                      // and reverse (ready) directions
    ) i_bus_pipe_rx (
        .bus_if_from_tx ( bus_if__rx ),
        .bus_if_to_rx
    );

endmodule : bus_pipe_slr
