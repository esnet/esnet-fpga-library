// True Dual-Port (LUTRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_tdp_lutram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32
) (
    // Port A
    input  logic                 clk_A,
`ifndef SYNTHESIS
    input  logic                 srst_A, // Reset used for fast init in simulation only
`endif
    input  logic                 en_A,
    input  logic                 wr_A,
    input  logic  [ADDR_WID-1:0] addr_A,
    input  logic  [DATA_WID-1:0] wr_data_A,
    output logic  [DATA_WID-1:0] rd_data_A,

    // Port B
    input  logic                 clk_B,
    input  logic                 en_B,
    input  logic                 wr_B,
    input  logic  [ADDR_WID-1:0] addr_B,
    input  logic  [DATA_WID-1:0] wr_data_B,
    output logic  [DATA_WID-1:0] rd_data_B
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
    // Port A
    // -----------------------------
    always @(posedge clk_A) begin
`ifndef SYNTHESIS
        if (srst_A) for (int i = 0; i < DEPTH; i++) mem[i] <= '0;
        else
`endif
        if (en_A) begin
            if (wr_A) mem[addr_A] <= wr_data_A;
            rd_data_A <= mem[addr_A];
        end
    end

    // -----------------------------
    // Port B
    // -----------------------------
    always @(posedge clk_B) begin
        if (en_B) begin
            if (wr_B) mem[addr_B] <= wr_data_B;
            rd_data_B <= mem[addr_B];
        end
    end

endmodule : xilinx_ram_tdp_lutram
