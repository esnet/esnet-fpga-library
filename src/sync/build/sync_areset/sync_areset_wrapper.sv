module sync_areset_wrapper
(
    input  logic  clk_in,
    input  logic  rst_in,
    input  logic  clk_out,
    output logic  rst_out
);

    logic __rst_in;

    initial __rst_in = 1'b0;
    always @(posedge clk_in) begin
        if (!rst_in) __rst_in <= 1'b0;
        else         __rst_in <= 1'b1;
    end

    sync_areset  i_sync_areset (
        .rst_in  ( __rst_in),
        .clk_out ( clk_out ),
        .rst_out ( rst_out )
    );

endmodule : sync_areset_wrapper
