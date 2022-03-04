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
// Basic synchronizer
// - implements a pipeline of metastability FFs to synchronize a level
//   (i.e. 'slow') signal
//
module sync_level #(
    parameter int    STAGES = 3,
    parameter type   DATA_T = logic,
    parameter DATA_T RST_VALUE = {$bits(DATA_T){1'bx}}
) (
    // Source clock domain
    input  DATA_T lvl_in,
    // Destination clock domain
    input  logic  clk_out,
    input  logic  rst_out,
    output DATA_T lvl_out
);

    (* ASYNC_REG = "TRUE" *) DATA_T __sync_level_ff_meta [STAGES];

    initial __sync_level_ff_meta = '{STAGES{RST_VALUE}};
    always @(posedge clk_out) begin
        if (rst_out) __sync_level_ff_meta <= '{STAGES{RST_VALUE}};
        else begin
            for (int i = 1; i < STAGES; i++) begin
                __sync_level_ff_meta[i] <= __sync_level_ff_meta[i-1];
            end
            __sync_level_ff_meta[0] <= lvl_in;
        end
    end
    assign lvl_out = __sync_level_ff_meta[STAGES-1];

endmodule
