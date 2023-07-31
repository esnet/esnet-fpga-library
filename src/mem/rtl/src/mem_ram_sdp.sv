// Simple Dual-Port RAM
// NOTE: This module provides a simple dual-port (SDP) RAM implementation
module mem_ram_sdp
    import mem_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter xilinx_ram_style_t _RAM_STYLE = RAM_STYLE_AUTO
) (
    // Write interface
    input logic                 wr_clk,
    input logic                 wr_en,
    input logic                 wr_req,
    input logic  [ADDR_WID-1:0] wr_addr,
    input logic  [DATA_WID-1:0] wr_data,

    // Read interface
    input logic                 rd_clk,
    input logic                 rd,
    input logic  [ADDR_WID-1:0] rd_addr,
    output logic [DATA_WID-1:0] rd_data
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DEPTH = 2**ADDR_WID;

    // Method below is workaround for lack of Vivado support for 'string' datatype.
    // Convert enumerated type to (untyped) 'string' representation:
    localparam RAM_STYLE_STR = _RAM_STYLE == RAM_STYLE_DISTRIBUTED ? "distributed" :
                               _RAM_STYLE == RAM_STYLE_BLOCK       ? "block" :
                               _RAM_STYLE == RAM_STYLE_REGISTERS   ? "registers" :
                                                                      "ultra";
    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [DATA_WID-1:0] data_t;

    // -----------------------------
    // RAM declaration
    // -----------------------------
    (* ram_style = RAM_STYLE_STR *) data_t mem [DEPTH];

    // -----------------------------
    // SDP RAM logic
    // -----------------------------
    always @(posedge wr_clk) begin
        if (wr_en) begin
            if (wr_req) mem[wr_addr] <= wr_data;
        end
    end
    always @(posedge rd_clk) begin
        if (rd) rd_data <= mem[rd_addr];
    end

endmodule : mem_ram_sdp
