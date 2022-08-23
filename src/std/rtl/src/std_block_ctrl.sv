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

module std_block_ctrl (
    // Block inputs (synchronized to clk)
    input  logic blk_clk_in,
    input  logic blk_reset_in,
    input  logic blk_en_in,
    input  logic blk_ready_in,

    // Control inputs (synchronized to ctrl_clk)
    input  logic ctrl_clk_in,
    input  logic ctrl_reset_in,
    input  logic ctrl_en_in,

    // Block outputs (synchronized to clk)
    output logic blk_reset_out,
    output logic blk_en_out,

    // Control outputs (synchronized to ctrl_clk)
    output logic ctrl_reset_out,
    output logic ctrl_en_out,
    output logic ctrl_ready_out
);
    // Signals
    logic reset_in;
    logic ctrl_en__blk_clk;

    // Synchronize reset
    // (async assert, synchronous deassert)
    assign reset_in = blk_reset_in || ctrl_reset_in;

    sync_reset #(
        .INPUT_ACTIVE_HIGH ( 1'b1 )
    ) i_sync_reset__srst (
        .rst_in   ( reset_in ),
        .clk_out  ( blk_clk_in ),
        .srst_out ( blk_reset_out )
    );

    // Synchronize enable
    sync_level i_sync_level__ctrl_en_in (
        .lvl_in  ( ctrl_en_in ),
        .clk_out ( blk_clk_in ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_en__blk_clk )
    );
    assign blk_en_out = blk_en_in && ctrl_en__blk_clk;

    // Synchronize monitor outputs to ctrl_clk_in
    sync_level i_sync_level__ctrl_reset_out (
        .lvl_in  ( blk_reset_out ),
        .clk_out ( ctrl_clk_in ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_reset_out )
    );

    sync_level i_sync_level__ctrl_en_out (
        .lvl_in  ( blk_en_out ),
        .clk_out ( ctrl_clk_in ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_en_out )
    );

    sync_level i_sync_level__ctrl_ready_out (
        .lvl_in  ( blk_ready_in ),
        .clk_out ( ctrl_clk_in ),
        .rst_out ( 1'b0 ),
        .lvl_out ( ctrl_ready_out )
    );

endmodule : std_block_ctrl
