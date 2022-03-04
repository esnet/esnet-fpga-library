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
//
// Reset synchronizer
// - implements metastability FFs to synchronize deassertion of reset
module sync_reset #(
    parameter bit INPUT_ACTIVE_HIGH = 0, // Default is active-low async reset in
    parameter bit OUTPUT_ACTIVE_LOW = 0  // Default is active-high sync reset out
) (
    // Source reset (asynchronous)
    input  logic  rst_in,
    // Destination clock/reset
    input  logic  clk_out,
    output logic  srst_out
);

    logic __rst_n_in;
    logic __srst_out;
    (* ASYNC_REG = "TRUE" *) logic __sync_reset_ff_meta [2];

    assign __rst_n_in = INPUT_ACTIVE_HIGH ? !rst_in : rst_in;

    always_ff @(posedge clk_out or negedge __rst_n_in) begin
        if (!__rst_n_in) __sync_reset_ff_meta[0] <= 1'b0;
        else             __sync_reset_ff_meta[0] <= 1'b1;
    end

    always_ff @(posedge clk_out or negedge __rst_n_in) begin
        if (!__rst_n_in) __sync_reset_ff_meta[1] <= 1'b0;
        else             __sync_reset_ff_meta[1] <= __sync_reset_ff_meta[0];
    end

    assign __srst_out = __sync_reset_ff_meta[1];
    assign srst_out = OUTPUT_ACTIVE_LOW ? __srst_out : !__srst_out;

endmodule
