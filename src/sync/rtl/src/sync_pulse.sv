module sync_pulse #(
    parameter int STAGES = 3,
    parameter bit POLARITY = 1'b1 // Set to 1'b1 for 'positive' polarity pulses
                                  // Set to 1'b0 for 'negative' polarity pulses
) (
    // Input clock domain
    input  logic clk_in,
    input  logic rst_in,
    input  logic pulse_in,
    // Output clock domain
    input  logic clk_out,
    input  logic rst_out,
    output logic pulse_out
);
    // Signals
    logic toggle_in;
    logic toggle_out;
    logic toggle_out_d;

    // Convert pulse to 'toggle' (level) in input domain
    initial toggle_in = 1'b0;
    always @(posedge clk_in) begin
        if (rst_in) toggle_in <= 1'b0;
        else begin
            if (pulse_in ~^ POLARITY) toggle_in <= ~toggle_in;
        end
    end

    // Pass 'toggle' to output domain
    sync_level    #(
        .STAGES    ( STAGES ),
        .DATA_T    ( logic ),
        .RST_VALUE ( 1'b0 )
    ) i_sync_level (
        .lvl_in    ( toggle_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .lvl_out   ( toggle_out )
    );

    // Convert 'toggle' to pulse in output domain
    initial toggle_out_d = 1'b0;
    always @(posedge clk_out) begin
        if (rst_out) toggle_out_d <= 1'b0;
        else begin
            toggle_out_d <= toggle_out;
        end
    end
    assign pulse_out = (POLARITY ~^ (toggle_out ^ toggle_out_d));

endmodule
