module sync_ctr #(
    parameter int                 CNT_WID = 1,
    parameter logic [CNT_WID-1:0] RST_VALUE = 'x,
    parameter bit                 DECODE_OUT = 1'b1  // Set to 1'b1 to decode output i.e. gray2bin.
) (
    // Input clock domain
    input  logic               clk_in,
    input  logic               rst_in,
    input  logic [CNT_WID-1:0] cnt_in,
    // Output clock domain
    input  logic               clk_out,
    input  logic               rst_out,
    output logic [CNT_WID-1:0] cnt_out
);

    logic [CNT_WID-1:0] cnt_in_gray, cnt_out_gray;

    // bin2gray encoding function.
    function automatic logic[CNT_WID-1:0] bin2gray (input logic[CNT_WID-1:0] bin_in);
        automatic logic[CNT_WID-1:0] gray_out;
        gray_out = bin_in ^ (bin_in >> 1);                
        return gray_out;
    endfunction

    // gray2bin decoding function.
    function automatic logic[CNT_WID-1:0] gray2bin (input logic[CNT_WID-1:0] gray_in);
        automatic logic [CNT_WID-1:0] bin_out;
        bin_out[CNT_WID-1] = gray_in[CNT_WID-1];
        for (int i=CNT_WID-1; i>0; i--) bin_out[i-1] = bin_out[i] ^ gray_in [i-1];
        return bin_out;
    endfunction

    // bin2gray encode cnt_in.
    always_comb cnt_in_gray = bin2gray(cnt_in);

    // basic synchronizer
    sync_meta     #(
        .DATA_WID  ( CNT_WID ),
        .RST_VALUE ( bin2gray(RST_VALUE) )
    ) sync_meta_0  (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .sig_in    ( cnt_in_gray ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .sig_out   ( cnt_out_gray )
    );

    // gray2bin decoding (if enabled).
    generate
        if (DECODE_OUT) begin : g_decode
            // gray2bin decode cnt_out.
            always @(posedge clk_out)
                if (rst_out) cnt_out <= RST_VALUE;
                else         cnt_out <= gray2bin(cnt_out_gray);
        end : g_decode
        else begin : g_no_decode
            assign cnt_out = cnt_out_gray;
        end : g_no_decode
    endgenerate

endmodule : sync_ctr
