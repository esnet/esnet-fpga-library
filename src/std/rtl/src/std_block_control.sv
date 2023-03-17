module std_block_control (
    // Control clock
    input  logic ctrl_clk,

    // Control inputs (synchronized to ctrl_clk)
    input  logic ctrl_reset_in,
    input  logic ctrl_enable_in,

    // Block clock
    input  logic blk_clk,

    // Block outputs (synchronized to blk_clk)
    output logic blk_reset_out,
    output logic blk_enable_out
);
    sync_reset #(
        .INPUT_ACTIVE_HIGH ( 1'b1 )
    ) i_sync_reset__reset (
        .rst_in   ( ctrl_reset_in ),
        .clk_out  ( blk_clk ),
        .srst_out ( blk_reset_out )
    );

    // Synchronize enable
    sync_level i_sync_level__enable (
        .lvl_in  ( ctrl_enable_in ),
        .clk_out ( blk_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( blk_enable_out )
    );

endmodule : std_block_control
