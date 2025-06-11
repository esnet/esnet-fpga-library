// Single-Port (LUTRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_sp_lutram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32
) (
    input  logic                 clk,
`ifndef SYNTHESIS
    input  logic                 srst, // Reset used for fast init in simulation only
`endif
    input  logic                 en,
    input  logic                 wr,
    input  logic  [ADDR_WID-1:0] addr,
    input  logic  [DATA_WID-1:0] wr_data,
    output logic  [DATA_WID-1:0] rd_data
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
    // Single-port RAM logic
    // -----------------------------
    always @(posedge clk) begin
`ifndef SYNTHESIS
        if (srst) for (int i = 0; i < DEPTH; i++) mem[i] <= '0;
        else
`endif
        if (en) begin
            if (wr) mem[addr] <= wr_data;
            rd_data <= mem[addr];
        end
    end

endmodule : xilinx_ram_sp_lutram
