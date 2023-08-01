// Simple Dual-Port (LUTRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_sdp_lutram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32
) (
    input logic                 wr_clk,
    input logic                 wr_en,
    input logic                 wr_req,
    input logic  [ADDR_WID-1:0] wr_addr,
    input logic  [DATA_WID-1:0] wr_data,

    // Read interface
    input logic                 rd_clk,
    input logic                 rd_srst,
    input logic                 rd_en,
    input logic  [ADDR_WID-1:0] rd_addr,
    output logic [DATA_WID-1:0] rd_data
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DEPTH = 2**ADDR_WID;

    localparam int WR_LATENCY = 1;
    localparam int RD_LATENCY = 1;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [DATA_WID-1:0] data_t;

    // -----------------------------
    // RAM declaration
    // -----------------------------
    (* ram_style = "distributed" *) data_t mem [DEPTH];

    data_t __rd_data;

    // -----------------------------
    // Write logic
    // -----------------------------
    always @(posedge wr_clk) begin
        if (wr_en)
            if (wr_req) mem[wr_addr] <= wr_data;
    end

    // -----------------------------
    // Read logic
    // -----------------------------
    always @(posedge rd_clk) begin
        if (rd_srst) rd_data <= '0;
        else if (rd_en) rd_data <= mem[rd_addr];
    end

endmodule : xilinx_ram_sdp_lutram
