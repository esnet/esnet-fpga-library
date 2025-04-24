// Bus SLR crossing (Tx + Rx)
// Implements Rx registers for forward interface (valid + data),
// and Tx registers for reverse interface (ready) such that the
// interface becomes eligible for implementation in dedicated
// SLR crossing register tiles (Laguna registers)
//
// Also includes a pipelining FIFO receiver stage to accommodate
// four stages of slack in valid <-> ready handshaking protocol
(* keep_hierarchy = "yes" *) module bus_pipe_slr #(
    parameter type DATA_T = logic,
    parameter bit  IGNORE_READY = 1'b0,
    parameter int  PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int  POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int  __PRE_PIPE_STAGES = PRE_PIPE_STAGES > 1 ? PRE_PIPE_STAGES : 1; // Account for bidirectional pipeline stage
                                                                                   // in bus_pipe_tx

    localparam int  TOTAL_SLACK = 2*__PRE_PIPE_STAGES + 2 + 2 + 2*POST_PIPE_STAGES; // (pipe Tx + pre) + SLRx + SLRy + post

    // Parameter checking
    initial begin
        std_pkg::param_check($bits(from_tx.DATA_T), $bits(DATA_T), "from_tx.DATA_T");
        std_pkg::param_check($bits(to_rx.DATA_T),   $bits(DATA_T), "to_rx.DATA_T");
        std_pkg::param_check_gt(PRE_PIPE_STAGES, 0, "PRE_PIPE_STAGES");
        std_pkg::param_check_gt(POST_PIPE_STAGES, 0, "PRE_PIPE_STAGES");
    end

    // Signals
    logic clk;
    assign clk = from_tx.clk;

    // Interfaces
    bus_intf #(.DATA_T(DATA_T)) bus_if__tx   (.clk);
    bus_intf #(.DATA_T(DATA_T)) bus_if__tx_p (.clk);
    bus_intf #(.DATA_T(DATA_T)) bus_if__sll  (.clk);
    bus_intf #(.DATA_T(DATA_T)) bus_if__rx_p (.clk);
    bus_intf #(.DATA_T(DATA_T)) bus_if__rx   (.clk);

    // Pipeline transmitter
    bus_pipe_tx #(
        .DATA_T  ( DATA_T )
    ) i_bus_pipe_tx (
        .from_tx,
        .to_rx ( bus_if__tx )
    );

    bus_reg_multi      #(
        .DATA_T         ( DATA_T ),
        .STAGES         ( __PRE_PIPE_STAGES-1 )
    ) i_bus_reg_multi_tx (
        .from_tx ( bus_if__tx ),
        .to_rx   ( bus_if__tx_p )
    );

    // Tx registers (SLRx)
    // (includes transmit registers for srst/valid/data and receive register for ready)
    (* DONT_TOUCH = "yes" *) bus_reg #(.DATA_T (DATA_T)) i_bus_slr_tx (
        .from_tx  ( bus_if__tx_p ),
        .to_rx    ( bus_if__sll )
    );

    // Rx registers (SLRy)
    // (includes receive registers for srst/valid/data and transmit register for ready)
    (* DONT_TOUCH = "yes" *) bus_reg #(.DATA_T (DATA_T)) i_bus_slr_rx (
        .from_tx  ( bus_if__sll ),
        .to_rx    ( bus_if__rx_p )
    );

    bus_reg_multi       #(
        .DATA_T          ( DATA_T ),
        .STAGES          ( POST_PIPE_STAGES )
    ) i_bus_reg_multi_rx (
        .from_tx  ( bus_if__rx_p ),
        .to_rx    ( bus_if__rx )
    );

    // Pipeline receiver
    bus_pipe_rx #(
        .DATA_T       ( DATA_T ),
        .IGNORE_READY ( IGNORE_READY ),
        .TOTAL_SLACK  ( TOTAL_SLACK )
    ) i_bus_pipe_rx (
        .from_tx ( bus_if__rx ),
        .to_rx
    );

endmodule : bus_pipe_slr
