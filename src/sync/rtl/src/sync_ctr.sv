// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Peter Bengough hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

module sync_ctr #(
    parameter int      STAGES = 3,
    parameter type     DATA_T = logic,
    parameter DATA_T   RST_VALUE = {$bits(DATA_T){1'bx}},
    parameter bit      DECODE_OUT = 1'b1  // Set to 1'b1 to decode output i.e. gray2bin.
) (
    // Input clock domain
    input  logic  clk_in,
    input  logic  rst_in,
    input  DATA_T cnt_in,
    // Output clock domain
    input  logic  clk_out,
    input  logic  rst_out,
    output DATA_T cnt_out
);

    DATA_T cnt_in_gray, cnt_out_gray;

    // bin2gray encoding function.
    function automatic DATA_T bin2gray (input DATA_T bin_in);
        automatic DATA_T gray_out;
        gray_out = bin_in ^ (bin_in >> 1);                
        return gray_out;
    endfunction

    // gray2bin decoding function.
    function automatic DATA_T gray2bin (input DATA_T gray_in);
        automatic  DATA_T bin_out;
        localparam DATA_WID = $bits(DATA_T);
        bin_out[DATA_WID-1] = gray_in[DATA_WID-1];
        for (int i=DATA_WID-1; i>0; i--) bin_out[i-1] = bin_out[i] ^ gray_in [i-1];
        return bin_out;
    endfunction

    // bin2gray encode cnt_in.
    always @(posedge clk_in) begin
        if (rst_in) cnt_in_gray <= bin2gray(RST_VALUE);
        else        cnt_in_gray <= bin2gray(cnt_in);
    end

    // sync_level_0 instance.
    sync_level    #(
        .STAGES    ( STAGES ),
        .DATA_T    ( DATA_T ),
        .RST_VALUE ( bin2gray(RST_VALUE) )
    ) sync_level_0 (
        .lvl_in    ( cnt_in_gray ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .lvl_out   ( cnt_out_gray )
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

endmodule
