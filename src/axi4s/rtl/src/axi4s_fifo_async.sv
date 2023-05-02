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
        .axi4s_out         ( __axi4s_out )
    );

    assign axi4s_out.tvalid = __axi4s_out.tvalid;
    assign axi4s_out.tkeep = __axi4s_out.tkeep;
    assign axi4s_out.tdata = __axi4s_out.tdata;
    assign axi4s_out.tid = __axi4s_out.tid;
    assign axi4s_out.tdest = __axi4s_out.tdest;
    assign axi4s_out.tuser = __axi4s_out.tuser;

    assign __axi4s_out.tready = axi4s_out.tready;

endmodule : axi4s_fifo_async
