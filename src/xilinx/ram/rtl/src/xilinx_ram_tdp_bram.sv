// True Dual-Port (BlockRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_tdp_bram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING
) (
    // Port A
    input  logic                 clk_A,
    input  logic                 srst_A,
    input  logic                 en_A,
    input  logic                 wr_A,
    input  logic  [ADDR_WID-1:0] addr_A,
    input  logic  [DATA_WID-1:0] wr_data_A,
    output logic  [DATA_WID-1:0] rd_data_A,
    input  logic                 rd_regce_A,

    // Port B
    input  logic                 clk_B,
    input  logic                 srst_B,
    input  logic                 en_B,
    input  logic                 wr_B,
    input  logic  [ADDR_WID-1:0] addr_B,
    input  logic  [DATA_WID-1:0] wr_data_B,
    output logic  [DATA_WID-1:0] rd_data_B,
    input  logic                 rd_regce_B
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

    data_t __rd_data_A;
    data_t __rd_data_B;

    // -----------------------------
    // Port A
    // -----------------------------
    always @(posedge clk_A) begin
        if (en_A) begin 
            if (wr_A) mem[addr_A] <= wr_data_A;
            __rd_data_A <= mem[addr_A];
        end
    end

    // -----------------------------
    // Port B
    // -----------------------------
    always @(posedge clk_B) begin
        if (en_B) begin 
            if (wr_B) mem[addr_B] <= wr_data_B;
            __rd_data_B <= mem[addr_B];
        end
    end

    generate
        if (RD_REG_EN) begin : g__rd_reg
            always @(posedge clk_A) begin
                if (srst_A) rd_data_A <= '0;
                else begin
                    if (rd_regce_A) rd_data_A <= __rd_data_A;
                end
            end
            always @(posedge clk_B) begin
                if (srst_B) rd_data_B <= '0;
                else begin
                    if (rd_regce_B) rd_data_B <= __rd_data_B;
                end
            end
        end : g__rd_reg
        else begin : g__rd_no_reg
            assign rd_data_A = __rd_data_A;
            assign rd_data_B = __rd_data_B;
        end : g__rd_no_reg
    endgenerate

endmodule : xilinx_ram_tdp_bram
