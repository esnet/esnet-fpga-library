// Single-Port (UltraRAM) implementation
// See Xilinx UG573, UG901
module xilinx_ram_sp_uram
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING
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
    // Single-port RAM logic
    // -----------------------------
    always @(posedge clk) begin
`ifndef SYNTHESIS
        if (srst) mem <= '{DEPTH{'0}};
        else
`endif
        if (en) begin
            if (wr) mem[addr] <= wr_data;
            else __rd_data <= mem[addr];
        end
    end
   
    // Read data pipeline
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            logic  rd_en_p   [RD_PIPELINE_STAGES];
            data_t rd_data_p [RD_PIPELINE_STAGES];

            // Enable pipeline
            always @(posedge clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_en_p[i] <= rd_en_p[i-1];
                end
                rd_en_p[0] <= en;
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

endmodule : xilinx_ram_sp_uram
