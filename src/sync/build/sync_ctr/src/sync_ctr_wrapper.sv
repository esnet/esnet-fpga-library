module sync_ctr_wrapper
(
    input  logic       clk_in,
    input  logic       rst_in,
    input  logic [7:0] cnt_in,
    input  logic       clk_out,
    input  logic       rst_out,
    output logic [7:0] cnt_out
);

    sync_ctr #(
        .DATA_T    ( logic[7:0] ),
        .RST_VALUE ( '0 )
    ) i_sync_ctr   (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .cnt_in    ( cnt_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .cnt_out   ( cnt_out )
    );

endmodule : sync_ctr_wrapper
