// Simple Dual-Port (BlockRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_sdp_bram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING
) (
    input logic                 wr_clk,
`ifndef SYNTHESIS
    input  logic                wr_srst, // Reset used for fast init in simulation only
`endif
    input logic                 wr_en,
    input logic                 wr_req,
    input logic  [ADDR_WID-1:0] wr_addr,
    input logic  [DATA_WID-1:0] wr_data,

    // Read interface
    input logic                 rd_clk,
    input logic                 rd_srst,
    input logic                 rd_en,
    input logic                 rd_regce,
    input logic  [ADDR_WID-1:0] rd_addr,
    output logic [DATA_WID-1:0] rd_data
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DEPTH = 2**ADDR_WID;


    localparam bit RD_REG_EN = OPT_MODE == OPT_MODE_LATENCY ? 0 : 1;

    localparam int WR_LATENCY = 1;
    localparam int RD_LATENCY = 1 + RD_REG_EN;

    localparam int CASCADE_HEIGHT = 4;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [DATA_WID-1:0] data_t;

    // -----------------------------
    // RAM declaration
    // -----------------------------
    // NOTE: Set cascade height here to work around an issue where Vivado doesn't
    //       properly infer the built-in BRAM output register when BRAM is being
    //       operated asynchronously, and when the cascade height differs between columns.
    //       Setting a value here likely leads to suboptimal resource utilization, but
    //       failing to infer the output register is not acceptable for timing closure.
    (* ram_style = "block" , cascade_height = CASCADE_HEIGHT *) data_t mem [DEPTH];

    data_t __rd_data;

    // -----------------------------
    // Write logic
    // -----------------------------
    always @(posedge wr_clk) begin
`ifndef SYNTHESIS
        if (wr_srst) mem <= '{DEPTH{'0}};
        else
`endif
        if (wr_en) 
            if (wr_req) mem[wr_addr] <= wr_data;
    end

    // -----------------------------
    // Read logic
    // -----------------------------
    always @(posedge rd_clk) begin
        if (rd_en) __rd_data <= mem[rd_addr];
    end

    generate
        if (RD_REG_EN) begin : g__rd_reg
            always @(posedge rd_clk) begin
                if (rd_srst) rd_data <= '0;
                else if (rd_regce) rd_data <= __rd_data;
            end
        end : g__rd_reg
        else begin : g__rd_no_reg
            assign rd_data = __rd_data;
        end : g__rd_no_reg
    endgenerate

endmodule : xilinx_ram_sdp_bram
