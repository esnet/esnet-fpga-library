// Reset synchronizer (synchronous)
// - synchronizes synchronous reset on clk_in domain to clk_out domain
// - input reset is registered to prevent combinational logic or fanout > 1
//   on net to synchronizing flops
// - input reset must support synchronous deassertion (assertion can be synchronous or asynchronous)
// - output reset is asserted asynchronously and deasserted synchronously
module sync_reset #(
    parameter bit INPUT_ACTIVE_HIGH = 0, // Default is active-low async reset in
    parameter bit OUTPUT_ACTIVE_LOW = 0  // Default is active-high sync reset out
) (
    // Source reset
    input  logic  clk_in,
    input  logic  rst_in, // (async assert, sync deassert)
    // Destination clock/reset
    input  logic  clk_out,
    output logic  rst_out // (async assert, sync deassert)
);
    // Parameters
    localparam int STAGES = sync_pkg::RETIMING_STAGES;

    // Signals
    logic __rst_n_in;
    (* DONT_TOUCH = "TRUE" *) logic __sync_ff_rst_in_n;

    assign __rst_n_in = INPUT_ACTIVE_HIGH ? !rst_in : rst_in;

    initial __sync_ff_rst_in_n = 1'b0;
    always @(posedge clk_in or negedge __rst_n_in) begin
        if (!__rst_n_in) __sync_ff_rst_in_n <= 1'b0;
        else             __sync_ff_rst_in_n <= 1'b1;
    end

    // Metastability resolution is implemented in sync_areset
    sync_areset #(
        .OUTPUT_ACTIVE_LOW ( OUTPUT_ACTIVE_LOW )
    ) i_sync_areset (
        .rst_in  ( __sync_ff_rst_in_n ),
        .clk_out ( clk_out ),
        .rst_out ( rst_out )
    );

endmodule : sync_reset
