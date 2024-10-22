// True Dual-Port (UltraRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_tdp_uram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING
) (
    input logic                  clk,

    // Port A
    input  logic                 en_A,
    input  logic                 wr_A,
    input  logic  [ADDR_WID-1:0] addr_A,
    input  logic  [DATA_WID-1:0] wr_data_A,
    output logic  [DATA_WID-1:0] rd_data_A,

    // Port B
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
    localparam int RD_PIPELINE_STAGES = get_uram_rd_pipeline_stages(ADDR_WID, OPT_MODE);
    localparam int RD_LATENCY = 1 + RD_PIPELINE_STAGES;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [DATA_WID-1:0] data_t;

    // -----------------------------
    // RAM declaration
    // -----------------------------
    (* ram_style = "ultra" *) data_t mem [DEPTH];

    data_t __rd_data_A;
    data_t __rd_data_B;

    // -----------------------------
    // TDP RAM logic
    // -----------------------------
    // Port A
    always @(posedge clk) begin
        if (en_A) begin
            if (wr_A) mem[addr_A] <= wr_data_A;
            else __rd_data_A <= mem[addr_A];
        end
    end
    
    // Port B
    always @(posedge clk) begin
        if (en_B) begin
            if (wr_B) mem[addr_B] <= wr_data_B;
            else __rd_data_B <= mem[addr_B];
        end
    end

    // Read data pipeline
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            logic rd_en_p_A [RD_PIPELINE_STAGES];
            logic rd_en_p_B [RD_PIPELINE_STAGES];
            data_t rd_data_p_A [RD_PIPELINE_STAGES];
            data_t rd_data_p_B [RD_PIPELINE_STAGES];

            // Enable pipeline
            // -- Port A
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_en_p_A[i] <= rd_en_p_A[i-1];
                end
                rd_en_p_A[0] <= en_A;
            end
            // -- Port B
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_en_p_B[i] <= rd_en_p_B[i-1];
                end
                rd_en_p_B[0] <= en_B;
            end

            // Data pipeline
            // -- Port A
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    if (rd_en_p_A[i]) rd_data_p_A[i] <= rd_data_p_A[i-1];
                end
                if (rd_en_p_A[0]) rd_data_p_A[0] <= __rd_data_A;
            end
            assign rd_data_A = rd_data_p_A[RD_PIPELINE_STAGES-1];
            // -- Port B
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    if (rd_en_p_B[i]) rd_data_p_B[i] <= rd_data_p_B[i-1];
                end
                if (rd_en_p_B[0]) rd_data_p_B[0] <= __rd_data_B;
            end
            assign rd_data_B = rd_data_p_B[RD_PIPELINE_STAGES-1];
        end : g__rd_pipe
        else begin : g__rd_no_pipe

            assign rd_data_A = __rd_data_A;
            assign rd_data_B = __rd_data_B;

        end : g__rd_no_pipe

    endgenerate

endmodule : xilinx_ram_tdp_uram
