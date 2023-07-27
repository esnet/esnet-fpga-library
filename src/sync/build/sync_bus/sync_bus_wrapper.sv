module sync_bus_wrapper
(
    input  logic       clk_in,
    input  logic       rst_in,
    input  logic [7:0] data_in,
    input  logic       clk_out,
    input  logic       rst_out,
    output logic [7:0] data_out
);

    sync_bus_sampled #(
        .DATA_T    ( logic[7:0] ),
        .RST_VALUE ( 1'b0 )
    ) i_sync_bus_sampled (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .data_in   ( data_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .data_out  ( data_out )
    );

endmodule : sync_bus_wrapper
