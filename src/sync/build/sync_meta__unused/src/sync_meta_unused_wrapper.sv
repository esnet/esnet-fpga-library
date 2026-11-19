// Independent counter sources prevent equivalent-instance merging. Both
// synchronizers are initially observable; the test removes unused_out only
// after synthesis to model a consumer removed when an OOC core is linked.
module sync_meta_unused_wrapper (
    input  logic       clk_in, clk_out, rst_in, rst_out,
    input  logic       live_enable, unused_enable,
    output logic [5:0] live_out, unused_out
);
    logic [5:0] live_count = 0;
    logic [5:0] unused_count = 0;
    always @(posedge clk_in) begin
        if (rst_in) begin
            live_count <= 0;
            unused_count <= 0;
        end else begin
            if (live_enable) live_count <= live_count + 1;
            if (unused_enable) unused_count <= unused_count + 1;
        end
    end

    sync_ctr #(.CNT_WID(6), .RST_VALUE(0)) live_sync (
        .clk_in, .rst_in, .cnt_in(live_count),
        .clk_out, .rst_out, .cnt_out(live_out)
    );
    sync_ctr #(.CNT_WID(6), .RST_VALUE(0)) unused_sync (
        .clk_in, .rst_in, .cnt_in(unused_count),
        .clk_out, .rst_out, .cnt_out(unused_out)
    );
endmodule
