module xilinx_ram_sdp_lutram_wrapper #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 113
)(
    input  logic                 wr_clk,
    input  logic                 wr_en_in,
    input  logic                 wr_req_in,
    input  logic [ADDR_WID-1:0]  wr_addr_in,
    input  logic [DATA_WID-1:0]  wr_data_in,

    input  logic                 rd_clk,
    input  logic                 rd_srst,
    input  logic                 rd_en_in,
    input  logic  [ADDR_WID-1:0] rd_addr_in,
    output logic  [DATA_WID-1:0] rd_data_out
);

    logic wr_en;
    logic wr_req;
    logic [ADDR_WID-1:0] wr_addr;
    logic [DATA_WID-1:0] wr_data;

    logic rd_en;
    logic [ADDR_WID-1:0] rd_addr;
    logic [DATA_WID-1:0] rd_data;

    initial wr_en = 1'b0;
    always @(posedge wr_clk) begin
        wr_en <= wr_en_in;
        wr_req <= wr_req_in;
        wr_addr <= wr_addr_in;
        wr_data <= wr_data_in;
    end

    xilinx_ram_sdp_lutram #(
        .ADDR_WID ( ADDR_WID ),
        .DATA_WID ( DATA_WID )
    ) i_xilinx_ram_sdp_lutram (
        .*
    );

    initial rd_en = 1'b0;
    always @(posedge rd_clk) begin
        rd_en <= rd_en_in;
        rd_addr <= rd_addr_in;
    end

    always_ff @(posedge rd_clk) begin
        if (rd_srst) rd_data_out <= '0;
        else         rd_data_out <= rd_data;
    end

endmodule : xilinx_ram_sdp_lutram_wrapper
