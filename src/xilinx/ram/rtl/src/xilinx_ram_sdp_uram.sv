// Simple Dual-Port (UltraRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_sdp_uram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING
) (
    input logic                 clk,

    input logic                 wr_en,
    input logic                 wr_req,
    input logic  [ADDR_WID-1:0] wr_addr,
    input logic  [DATA_WID-1:0] wr_data,

    // Read interface
    input logic                 rd_en,
    input logic  [ADDR_WID-1:0] rd_addr,
    output logic [DATA_WID-1:0] rd_data
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

    data_t __rd_data;

    // -----------------------------
    // SDP RAM logic
    // -----------------------------
    always @(posedge clk) begin
        if (wr_en) begin
            if (wr_req) mem[wr_addr] <= wr_data;
        end
        if (rd_en) begin
            __rd_data <= mem[rd_addr];
        end
    end

    // Read data pipeline
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            logic rd_en_p [RD_PIPELINE_STAGES];
            data_t rd_data_p [RD_PIPELINE_STAGES];

            // Enable pipeline
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_en_p[i] <= rd_en_p[i-1];
                end
                rd_en_p[0] <= rd_en;
            end

            // Data pipeline
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    if (rd_en_p[i]) rd_data_p[i] <= rd_data_p[i-1];
                end
                if (rd_en_p[0]) rd_data_p[0] <= __rd_data;
            end

            assign rd_data = rd_data_p[RD_PIPELINE_STAGES-1];

        end : g__rd_pipe
        else begin : g__rd_no_pipe

            assign rd_data = __rd_data;

        end : g__rd_no_pipe

    endgenerate

endmodule : xilinx_ram_sdp_uram
