// -----------------------------------------------------------------------------
// Word-based asynchronous AXI-S FIFO
// - asynchronous word-based (i.e. not packet-aware) FIFO
//   with AXI-S write/read interfaces
// -----------------------------------------------------------------------------

module axi4s_fifo_async
#(
    parameter int DEPTH = 32
) (
    axi4s_intf.rx from_tx,
    input logic   from_tx_srst,
    axi4s_intf.tx to_rx,
    input logic   to_rx_srst
);
    //----------------------------------------------
    // AXI-S FIFO instance
    //----------------------------------------------
    axi4s_fifo_core       #(
        .DEPTH             ( DEPTH ),
        .ASYNC             ( 1 )
    ) i_axi4s_fifo_core    ( .* );

endmodule : axi4s_fifo_async
