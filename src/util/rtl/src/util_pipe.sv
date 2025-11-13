// Simple pipeline module
// - passes `data_in` to `data_out` after `PIPE_STAGES` cycles
// - all elements of delay line are reset when `srst` is asserted
//   (if no reset is required, set srst = 1'b0)
// - data 'type' is parameterized
module util_pipe #(
    parameter int DATA_WID = 1,
    parameter int PIPE_STAGES = 1,
    parameter logic [DATA_WID-1:0] RESET_VAL = '0
) (
    // Clock/reset
    input logic   clk,
    input logic   srst,

    // Data in
    input  logic [DATA_WID-1:0] data_in,
    output logic [DATA_WID-1:0] data_out
);
    generate
        // Pipeline (pass signals from input to output through pipelining flops)
        if (PIPE_STAGES > 0) begin : g__pipe
            // (Local) signals
            (* shreg_extract = "no" *) logic [DATA_WID-1:0] data_d [PIPE_STAGES];

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
