module sync_meta_wrapper
(
    input logic  clk_in,
    input logic  rst_in,
    input logic  sig_in,
    input logic  clk_out,
    input logic  rst_out,
    output logic sig_out
);

    sync_meta     #(
        .DATA_WID  ( 1 ),
        .RST_VALUE ( 1'b0 )
    ) i_sync_meta  (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .sig_in    ( sig_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .sig_out   ( sig_out )
    );

endmodule : sync_meta_wrapper
