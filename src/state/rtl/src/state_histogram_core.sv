module state_histogram_core #(
    parameter int  DATA_WID = 1,
    parameter int  BINS = 8,
    parameter int  COUNT_WID [BINS] = '{default: 32}
)(
    // Clock/reset
    input  logic                clk,
    input  logic                srst,

    // Data
    input  logic                data_valid,
    input  logic [DATA_WID-1:0] data,
    output logic                bin_update [BINS],

    // -- Low/High bin thresholds; updates will be made to all bins where
    //    bin_thresh_low <= data <= bin_thresh_high
    input  logic [DATA_WID-1:0] bin_thresh_low  [BINS],
    input  logic [DATA_WID-1:0] bin_thresh_high [BINS]
);
    // ----------------------------------
    // Histogram update logic
    // ----------------------------------
    generate
        for (genvar g_bin = 0; g_bin < BINS; g_bin++) begin : g__bin
            // (Local) signals
            logic in_range;
            // Determine if data value is in range for current bin
            assign in_range = (data >= bin_thresh_low[g_bin]) && (data <= bin_thresh_high[g_bin]);
            // Update bin count
            always_comb begin
                bin_update[g_bin] = 1'b0;
                if (data_valid && in_range) bin_update[g_bin] = 1'b1;
            end
        end : g__bin
    endgenerate

endmodule : state_histogram_core
