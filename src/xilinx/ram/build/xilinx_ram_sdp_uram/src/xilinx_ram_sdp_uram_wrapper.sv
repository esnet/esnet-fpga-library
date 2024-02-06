module xilinx_ram_sdp_uram_wrapper #(
    parameter int ADDR_WID = 14,
    parameter int DATA_WID = 113
)(
    input  logic                 clk,

    input  logic                 wr_en,
    input  logic                 wr_req,
    input  logic [ADDR_WID-1:0]  wr_addr,
    input  logic [DATA_WID-1:0]  wr_data,

    input  logic                 rd_en,
    input  logic  [ADDR_WID-1:0] rd_addr,
    output logic  [DATA_WID-1:0] rd_data
);

    xilinx_ram_sdp_uram #(
        .ADDR_WID ( ADDR_WID ),
        .DATA_WID ( DATA_WID )
    ) i_xilinx_ram_sdp_uram (
        .*
    );

endmodule : xilinx_ram_sdp_uram_wrapper
