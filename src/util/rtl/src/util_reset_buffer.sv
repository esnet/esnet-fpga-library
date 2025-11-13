// Reset buffer module
// - passes `srst_in` to `srst_out` after `STAGES` cycles
// - supports reset tree optimization during physical implementation
// - NOTE: assumes fully synchronous (assertion + deassertion) reset behaviour
//   (specifically, this module is not suitable to be used if asynchronous assertion is required)
module util_reset_buffer #(
    parameter int STAGES = 2,           // Create 2-level reset tree, for example
    parameter bit ASSERT_ON_INIT = 1'b1 // When set, output is asserted at init    (i.e. srst_out = 1'b1, srstn_out = 1'b0)
                                        // otherwise, output is deasserted at init (i.e. srst_out = 1'b0, srstn_out = 1'b1)
) (
    input  logic  clk,
    input  logic  srst_in,  // Fully-synchronous active-high input reset
    output logic  srst_out, // Fully-synchronous active-high output reset
    output logic  srstn_out
);
    // Parameters
    localparam logic INIT_VALUE_ACTIVE_HIGH = ASSERT_ON_INIT ? 1'b1 : 1'b0;
    localparam logic INIT_VALUE_ACTIVE_LOW  = ASSERT_ON_INIT ? 1'b0 : 1'b1;

    // Parameter check
    initial begin
        std_pkg::param_check_gt(STAGES, 2, "STAGES");
    end

    // Signals
    (* shreg_extract = "no" *) logic __srst [STAGES-1];
    logic  __srst_out;
    logic  __srstn_out;

    initial begin
        for (int i = 0; i < STAGES-1; i++) __srst[i] = INIT_VALUE_ACTIVE_HIGH;
    end
    always @(posedge clk) begin
        for (int i = 1; i < STAGES-1; i++) begin
            __srst[i] <= __srst[i-1];
        end
        __srst[0] <= srst_in;
    end

    initial __srst_out = INIT_VALUE_ACTIVE_HIGH;
    always @(posedge clk) __srst_out <= __srst[STAGES-2];
    assign srst_out = __srst_out;

    initial __srstn_out = !INIT_VALUE_ACTIVE_LOW;
    always @(posedge clk) __srstn_out <= !__srst[STAGES-2];
    assign srstn_out = __srstn_out;

endmodule : util_reset_buffer
