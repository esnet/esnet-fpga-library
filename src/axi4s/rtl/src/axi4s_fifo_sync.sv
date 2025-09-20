// -----------------------------------------------------------------------------
// Word-based synchronous AXI-S FIFO
// - synchronous word-based (i.e. not packet-aware) FIFO
//   with AXI-S write/read interfaces
// -----------------------------------------------------------------------------

module axi4s_fifo_sync
#(
    parameter int DEPTH = 32,
    parameter fifo_pkg::opt_mode_t FIFO_OPT_MODE = fifo_pkg::OPT_MODE_TIMING

) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx
);
    //----------------------------------------------
    // AXI-S FIFO instance
    //----------------------------------------------
    axi4s_fifo_core       #(
        .DEPTH             ( DEPTH ),
        .ASYNC             ( 0 ),
        .FIFO_OPT_MODE     ( FIFO_OPT_MODE )
    ) i_axi4s_fifo_core    ( .* );

endmodule : axi4s_fifo_sync
