// Reset synchronizer (asynchronous)
// - implements metastability FFs to synchronize deassertion of asynchronous reset
// - output reset is asserted asynchronously and deasserted synchronously
module sync_areset #(
    parameter bit INPUT_ACTIVE_HIGH = 0, // Default is active-low async reset in
    parameter bit OUTPUT_ACTIVE_LOW = 0  // Default is active-high sync reset out
) (
    // Source reset (asynchronous)
    input  logic  rst_in,
    // Destination clock/reset
    input  logic  clk_out,
    output logic  rst_out // (async assert, sync deassert)
);
    // Parameters
    localparam int STAGES = sync_pkg::RETIMING_STAGES;

    // Signals
    logic __rst_n_in;
    logic __rst_n_out;
    (* ASYNC_REG = "TRUE" *) logic __sync_ff_reset_n [STAGES];

    assign __rst_n_in = INPUT_ACTIVE_HIGH ? !rst_in : rst_in;

    // First metastability flop (asynchronous clear)
    always_ff @(posedge clk_out or negedge __rst_n_in) begin
        if (!__rst_n_in) __sync_ff_reset_n[0] <= 1'b0;
        else             __sync_ff_reset_n[0] <= 1'b1;
    end

    // Pipeline of metastability flops
    always_ff @(posedge clk_out or negedge __rst_n_in) begin
        if (!__rst_n_in) begin
            for (int i = 1; i < STAGES; i++) __sync_ff_reset_n[i] <= 1'b0;
        end else begin
            for (int i = 1; i < STAGES; i++) __sync_ff_reset_n[i] <= __sync_ff_reset_n[i-1];
        end
    end

    assign __rst_n_out = __sync_ff_reset_n[1];
    assign rst_out = OUTPUT_ACTIVE_LOW ? __rst_n_out : !__rst_n_out;

endmodule : sync_areset
