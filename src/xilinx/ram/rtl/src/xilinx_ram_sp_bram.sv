// Single-Port (BlockRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_sp_bram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING
) (
    input  logic                 clk,
    input  logic                 srst,
    input  logic                 en,
    input  logic                 wr,
    input  logic  [ADDR_WID-1:0] addr,
    input  logic  [DATA_WID-1:0] wr_data,
    output logic  [DATA_WID-1:0] rd_data,
    input  logic                 rd_regce
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
    // Single-port RAM logic
    // -----------------------------
    always @(posedge clk) begin
`ifndef SYNTHESIS
        if (srst) for (int i = 0; i < DEPTH; i++) mem[i] <= '0;
        else
`endif
        if (en) begin 
            if (wr) mem[addr] <= wr_data;
            __rd_data <= mem[addr];
        end
    end

    // -----------------------------
    // Optional output register
    // -----------------------------
    generate
        if (RD_REG_EN) begin : g__rd_reg
            always @(posedge clk) begin
                if (srst) rd_data <= '0;
                else begin
                    if (rd_regce) rd_data <= __rd_data;
                end
            end
        end : g__rd_reg
        else begin : g__rd_no_reg
            assign rd_data = __rd_data;
        end : g__rd_no_reg
    endgenerate

endmodule : xilinx_ram_sp_bram
