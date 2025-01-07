// Reset buffer module
// - passes `srst_in` to `srst_out` after `STAGES` cycles
// - supports reset tree optimization during physical implementation
// - NOTE: assumes fully synchronous (assertion + deassertion) reset behaviour
//   (specifically, this module is not suitable to be used if asynchronous assertion is required)
module util_reset_buffer #(
    parameter int STAGES = 2,           // Create 2-level reset tree, for example
    parameter bit INPUT_ACTIVE_LOW = 0, // Assume active-high input unless otherwise specified
    parameter bit ASSERT_ON_INIT = 0    // When set, output is asserted at init    (i.e. srst_out = 1'b1, srstn_out = 1'b0)
                                        // otherwise, output is deasserted at init (i.e. srst_out = 1'b0, srstn_out = 1'b1)
) (
    input  logic  clk,
    input  logic  srst_in,  // Active-high input reset
    output logic  srst_out, // Active-high output reset
    output logic  srstn_out // Active-low  output reset
);
    // Signals
    logic __srst_in;
    logic __srst;
    logic __srst_out;
    logic __srstn_out;

    // Normalize reset polarity
    assign __srst_in = INPUT_ACTIVE_LOW ? !srst_in : srst_in;

    // Implement reset pipeline with no special properties
    // (SHREG_EXTRACT, DONT_TOUCH, etc.) on pipeline flops.

    // Assumption is that tools are good at reset tree optimization
    // (buffer replication, etc.) and providing maximum flexibility
    // is desirable.

    // Common stages
    generate
        if (STAGES > 1) begin : g__multi_stage
            logic __srst_p [STAGES-1];
            initial __srst_p = '{default: ASSERT_ON_INIT};
            always @(posedge clk) begin
                for (int i = 1; i < STAGES-1; i++) begin
                    __srst_p[i] <= __srst_p[i-1];
                end
                __srst_p[0] <= __srst_in;
            end
            assign __srst = __srst_p[STAGES-2];
        end : g__multi_stage
        else if (STAGES == 1) begin : g__single_stage
            assign __srst = __srst_in;
        end  : g__single_stage
        else begin : g__invalid
            $fatal(1, $sformatf("[util_reset_buffer] At least one stage must be specified."));
        end : g__invalid
    endgenerate

    // Final stage(s) / separate instances for active-high and active-low outputs
    initial __srst_out = ASSERT_ON_INIT;
    always @(posedge clk) __srst_out <= __srst;

    initial __srstn_out = !ASSERT_ON_INIT;
    always @(posedge clk) __srstn_out <= !__srst;

    assign srst_out = __srst_out;
    assign srstn_out = __srstn_out;

endmodule : util_reset_buffer
