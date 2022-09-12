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
