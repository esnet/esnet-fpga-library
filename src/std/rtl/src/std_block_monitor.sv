// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

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
        .lvl_in  ( blk_reset_mon_in ),
        .clk_out ( ctrl_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_reset_mon_out )
    );

    sync_level i_sync_level__enable_mon (
        .lvl_in  ( blk_enable_mon_in ),
        .clk_out ( ctrl_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_enable_mon_out )
    );

    sync_level i_sync_level__ready_mon (
        .lvl_in  ( blk_ready_mon_in ),
        .clk_out ( ctrl_clk ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_ready_mon_out )
    );

    sync_bus_sampled #(
        .DATA_T   ( logic[7:0] )
    ) i_sync_bus__state_mon (
        .clk_in   ( blk_clk ),
        .rst_in   ( 1'b0 ),
        .data_in  ( blk_state_mon_in ),
        .clk_out  ( ctrl_clk ),
        .rst_out  ( 1'b0 ),
        .data_out ( ctrl_state_mon_out )
    );

endmodule : std_block_monitor
