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

// Simple pipeline module
// - passes `data_in` to `data_out` after `PIPE_STAGES` cycles
// - all elements of delay line are reset when `srst` is asserted
//   (if no reset is required, set srst = 1'b0)
// - data 'type' is parameterized
module util_pipe #(
    parameter type DATA_T = logic, // type representing data interface (examples: logic[7:0], some_struct_type_t)
    parameter int PIPE_STAGES = 1,
    parameter DATA_T RESET_VAL = DATA_T'('0)
) (
    // Clock/reset
    input logic   clk,
    input logic   srst,

    // Data in
    input  DATA_T data_in,
    output DATA_T data_out
);
    generate
        // Pipeline (pass signals from input to output through pipelining flops)
        if (PIPE_STAGES > 0) begin : g__pipe
            // (Local) signals
            (* shreg_extract = "no" *) DATA_T data_d [PIPE_STAGES];

            // Data pipeline
            initial data_d = '{default: RESET_VAL};
            always @(posedge clk) begin
                if (srst) data_d <= '{default: RESET_VAL};
                else begin
                    for (int i = 1; i < PIPE_STAGES; i++) begin
                        data_d[i] <= data_d[i-1];
                    end
                    data_d[0] <= data_in;
                end
            end
            assign data_out = data_d[PIPE_STAGES-1];
        end : g__pipe
        // No pipeline stages (pass signals directly from input to output)
        else if (PIPE_STAGES == 0) begin : g__no_pipe
            assign data_out = data_in;
        end : g__no_pipe
        else if (PIPE_STAGES < 0) begin : g__invalid_pipe
            $error($sformatf("[util_pipe] Negative number of PIPE_STAGES specified (%d).", PIPE_STAGES));
        end : g__invalid_pipe
    endgenerate

endmodule : util_pipe
