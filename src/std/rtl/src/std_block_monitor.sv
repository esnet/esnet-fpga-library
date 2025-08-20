module std_block_monitor (
    // Block clock
    input  logic       blk_clk,

    // Block monitor inputs (synchronized to blk_clk)
    input  logic       blk_reset_mon_in,
    input  logic       blk_enable_mon_in,
    input  logic       blk_ready_mon_in,
    input  logic [7:0] blk_state_mon_in,

    // Control clock
    input  logic       ctrl_clk,

    // Control monitor outputs (synchronized to ctrl_clk)
    output logic       ctrl_reset_mon_out,
    output logic       ctrl_enable_mon_out,
    output logic       ctrl_ready_mon_out,
    output logic [7:0] ctrl_state_mon_out
);
    // Synchronize monitor outputs to ctrl_clk
    sync_level i_sync_level__reset_mon (
        .clk_in  ( blk_clk ),
        .rst_in  ( 1'b0 ),
        .rdy_in  ( ),
        .lvl_in  ( blk_reset_mon_in ),
        .clk_out ( ctrl_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_reset_mon_out )
    );

    sync_level i_sync_level__enable_mon (
        .clk_in  ( blk_clk ),
        .rst_in  ( 1'b0 ),
        .rdy_in  ( ),
        .lvl_in  ( blk_enable_mon_in ),
        .clk_out ( ctrl_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_enable_mon_out )
    );

    sync_level i_sync_level__ready_mon (
        .clk_in  ( blk_clk ),
        .rst_in  ( 1'b0 ),
        .rdy_in  ( ),
        .lvl_in  ( blk_ready_mon_in ),
        .clk_out ( ctrl_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_ready_mon_out )
    );

    sync_bus_sampled #(
        .DATA_WID ( 8 )
    ) i_sync_bus_sampled__state_mon (
        .clk_in   ( blk_clk ),
        .rst_in   ( 1'b0 ),
        .data_in  ( blk_state_mon_in ),
        .clk_out  ( ctrl_clk ),
        .rst_out  ( 1'b0 ),
        .data_out ( ctrl_state_mon_out )
    );

endmodule : std_block_monitor
