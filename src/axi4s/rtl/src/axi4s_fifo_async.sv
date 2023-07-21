// -----------------------------------------------------------------------------
// Word-based asynchronous AXI-S FIFO
// - asynchronous word-based (i.e. not packet-aware) FIFO
//   with AXI-S write/read interfaces
// -----------------------------------------------------------------------------

module axi4s_fifo_async
#(
    parameter int DEPTH = 32
) (
    axi4s_intf.rx       axi4s_in,
    axi4s_intf.tx_async axi4s_out
);
    //----------------------------------------------
    // AXI-S FIFO instance
    //----------------------------------------------
    axi4s_fifo_core       #(
        .DEPTH             ( DEPTH ),
        .ASYNC             ( 1 )
    ) i_axi4s_fifo_core    (
        .axi4s_in          ( axi4s_in ),
        .axi4s_out_clk     ( axi4s_out.aclk ),
        .axi4s_out_aresetn ( axi4s_out.aresetn ),
        .axi4s_out         ( axi4s_out )
    );

endmodule : axi4s_fifo_async
