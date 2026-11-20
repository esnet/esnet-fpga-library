// Exercise both output modes and independent parameterized references. The
// arbitrary bus is deliberately not Gray-encoded and must remain unwaived.
module sync_ctr_cdc_wrapper (
    input  logic       clk_in, clk_out, rst_in, rst_out,
    input  logic       binary_enable, gray_enable,
    input  logic [4:0] arbitrary_bus,
    output logic [5:0] binary_out,
    output logic [3:0] gray_out,
    output logic       single_bit_out,
    output logic [4:0] arbitrary_out
);
    logic [5:0] binary_count = 0;
    logic [3:0] gray_count = 0;
    always @(posedge clk_in) begin
        if (rst_in) begin
            binary_count <= 0;
            gray_count <= 0;
        end else begin
            if (binary_enable) binary_count <= binary_count + 1;
            if (gray_enable) gray_count <= gray_count + 1;
        end
    end

    sync_ctr #(.CNT_WID(6), .RST_VALUE(0), .DECODE_OUT(1)) binary_sync (
        .clk_in, .rst_in, .cnt_in(binary_count),
        .clk_out, .rst_out, .cnt_out(binary_out)
    );
    sync_ctr #(.CNT_WID(4), .RST_VALUE(0), .DECODE_OUT(0)) gray_sync (
        .clk_in, .rst_in, .cnt_in(gray_count),
        .clk_out, .rst_out, .cnt_out(gray_out)
    );
    // A one-bit counter has no CDC-6 finding, but the reference-scoped file
    // must still load without empty endpoint queries for this parameterization.
    sync_ctr #(.CNT_WID(1), .RST_VALUE(0), .DECODE_OUT(0)) single_bit_sync (
        .clk_in, .rst_in, .cnt_in(binary_count[0]),
        .clk_out, .rst_out, .cnt_out(single_bit_out)
    );
    sync_meta #(.DATA_WID(5), .RST_VALUE(0)) unrelated_sync (
        .clk_in, .rst_in, .sig_in(arbitrary_bus),
        .clk_out, .rst_out, .sig_out(arbitrary_out)
    );
endmodule
