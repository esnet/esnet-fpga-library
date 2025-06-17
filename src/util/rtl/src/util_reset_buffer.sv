// Reset buffer module
// - passes `srst_in` to `srst_out` after `STAGES` cycles
// - supports reset tree optimization during physical implementation
// - NOTE: assumes fully synchronous (assertion + deassertion) reset behaviour
//   (specifically, this module is not suitable to be used if asynchronous assertion is required)
module util_reset_buffer #(
    parameter int STAGES = 2,           // Create 2-level reset tree, for example
    parameter bit ASSERT_ON_INIT = 0    // When set, output is asserted at init    (i.e. srst_out = 1'b1, srstn_out = 1'b0)
                                        // otherwise, output is deasserted at init (i.e. srst_out = 1'b0, srstn_out = 1'b1)
) (
    input  logic  clk,
    input  logic  srst_in, // Fully-synchronous active-high input reset
    output logic  srst_out // Fully-synchronous active-high output reset
);
    // Parameters
    localparam logic __INIT_VALUE = ASSERT_ON_INIT ? 1'b1 : 1'b0;

    // Signals
    logic __srst;

    // Implement reset pipeline with no special properties
    // (SHREG_EXTRACT, DONT_TOUCH, etc.) on pipeline flops.

    // Assumption is that tools are good at reset tree optimization
    // (buffer replication, etc.) and providing maximum flexibility
    // is desirable.

    // Common stages
    generate
        if (STAGES > 1) begin : g__multi_stage
            logic __srst_p [STAGES];
            initial begin
                for (int i = 0; i < STAGES; i++) __srst_p[i] = __INIT_VALUE;
            end
            always @(posedge clk) begin
                for (int i = 1; i < STAGES; i++) begin
                    __srst_p[i] <= __srst_p[i-1];
                end
                __srst_p[0] <= srst_in;
            end
            assign __srst = __srst_p[STAGES-1];
        end : g__multi_stage
        else if (STAGES == 1) begin : g__single_stage
            assign __srst = srst_in;
        end  : g__single_stage
        else begin : g__invalid
            $fatal(1, $sformatf("[util_reset_buffer] At least one stage must be specified."));
        end : g__invalid
    endgenerate

    assign srst_out = __srst;

endmodule : util_reset_buffer
