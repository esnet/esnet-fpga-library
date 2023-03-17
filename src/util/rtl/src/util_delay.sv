// Simple delay module
// - passes `data_in` to `data_out` after `DELAY` cycles
// - all elements of delay line are reset when `srst` is asserted
//   (if no reset is required, set srst = 1'b0)
// - data 'type' is parameterized
module util_delay #(
    parameter type DATA_T = logic, // type representing data interface (examples: logic[7:0], some_struct_type_t)
    parameter int DELAY = 1,
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
        // Positive delay (pass signals from input to output through delay line)
        if (DELAY > 0) begin : g__delay
            // (Local) signals
            DATA_T data_d [DELAY];

            // Data pipeline
            initial data_d = '{default: RESET_VAL};
            always @(posedge clk) begin
                if (srst) data_d <= '{default: RESET_VAL};
                else begin
                    for (int i = 1; i < DELAY; i++) begin
                        data_d[i] <= data_d[i-1];
                    end
                    data_d[0] <= data_in;
                end
            end
            assign data_out = data_d[DELAY-1];
        end : g__delay
        // Zero delay (pass signals directly from input to output)
        else if (DELAY == 0) begin : g__no_delay
            assign data_out = data_in;
        end : g__no_delay
        else if (DELAY < 0) begin : g__invalid_delay
            $error($sformatf("[util_delay] Negative DELAY specified (%d).", DELAY));
        end : g__invalid_delay
    endgenerate

endmodule : util_delay
