module sync_level_wrapper
(
    input logic  clk_in,
    input logic  rst_in,
    input logic  lvl_in,
    input logic  clk_out,
    input logic  rst_out,
    output logic lvl_out
);

    logic __lvl_in;
    logic __lvl_out;

    initial __lvl_in = 1'b0;
    always @(posedge clk_in) begin
        if (rst_in) __lvl_in <= 1'b0;
        else        __lvl_in <= lvl_in;
    end

    sync_level    #(
        .STAGES    ( 3 ),
        .DATA_T    ( logic ),
        .RST_VALUE ( 1'b0 )
    ) i_sync_level (
        .lvl_in    ( __lvl_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .lvl_out   ( __lvl_out )
    );

    initial lvl_out = 1'b0;
    always @(posedge clk_out) begin
        if (rst_out) lvl_out <= 1'b0;
        else         lvl_out <= __lvl_out;
    end

endmodule : sync_level_wrapper
