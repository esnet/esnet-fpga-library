module xilinx_ram_sdp_low_latency_wrapper #(
    parameter int ADDR_WID = 12,
    parameter int DATA_WID = 113,
    parameter int ASYNC = 1
)(
    input  logic                 wr_clk,
    input  logic                 wr_en,
    input  logic                 wr_req,
    input  logic [ADDR_WID-1:0]  wr_addr,
    input  logic [DATA_WID-1:0]  wr_data,
    output logic                 wr_ack,

    input  logic                 rd_clk,
    input  logic                 rd_en,
    input  logic  [ADDR_WID-1:0] rd_addr,
    output logic  [DATA_WID-1:0] rd_data,
    output logic                 rd_ack
);

    xilinx_ram_sdp #(
        .ADDR_WID ( ADDR_WID ),
        .DATA_WID ( DATA_WID ),
        .ASYNC    ( ASYNC ),
        .OPT_MODE ( xilinx_ram_pkg::OPT_MODE_LATENCY )
    ) i_xilinx_ram_sdp (
        .*
    );

endmodule : xilinx_ram_sdp_low_latency_wrapper
