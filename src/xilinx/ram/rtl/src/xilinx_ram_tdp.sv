// True Dual-Port RAM implementation
module xilinx_ram_tdp
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit ASYNC = 0,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING // Determines whether RAM configuration is optimized for
                                                    // best timing performance (OPT_MODE_TIMING) or minimum
                                                    // latency (OPT_MODE_LATENCY).
                                                    // OPT_MODE_TIMING is recommended in most cases.
) (
    // Port A
    input  logic                clk_A,
    input  logic                en_A,
    input  logic                wr_A,
    input  logic [ADDR_WID-1:0] addr_A,
    input  logic [DATA_WID-1:0] wr_data_A,
    output logic                wr_ack_A,
    output logic [DATA_WID-1:0] rd_data_A,
    output logic                rd_ack_A,

    // Port B
    input  logic                clk_B,
    input  logic                en_B,
    input  logic                wr_B,
    input  logic [ADDR_WID-1:0] addr_B,
    input  logic [DATA_WID-1:0] wr_data_B,
    output logic                wr_ack_B,
    output logic [DATA_WID-1:0] rd_data_B,
    output logic                rd_ack_B
);

    // -----------------------------
    // PARAMETERS
    // -----------------------------
    // RAM style is auto-determined by size, aspect ratio and 
    localparam ram_style_t _RAM_STYLE = get_default_ram_style(ADDR_WID, DATA_WID, ASYNC, OPT_MODE);

    localparam int WR_LATENCY = get_wr_latency(ADDR_WID, DATA_WID, ASYNC, OPT_MODE);
    localparam int RD_LATENCY = get_rd_latency(ADDR_WID, DATA_WID, ASYNC, OPT_MODE);

    generate
        if (_RAM_STYLE == RAM_STYLE_ULTRA) begin : g__uram
            xilinx_ram_tdp_uram #(
                .ADDR_WID ( ADDR_WID ),
                .DATA_WID ( DATA_WID ),
                .OPT_MODE ( OPT_MODE )
            ) i_xilinx_ram_tdp_uram (
                .clk ( clk_A ),
                .*
            );
        end : g__uram
        else if (_RAM_STYLE == RAM_STYLE_BLOCK) begin : g__bram
            logic srst_A;
            logic srst_B;
            logic rd_regce_A;
            logic rd_regce_B;
            assign srst_A = 1'b0;
            assign srst_B = 1'b0;
            assign rd_regce_A = 1'b1;
            assign rd_regce_B = 1'b1;

            xilinx_ram_tdp_bram #(
                .ADDR_WID ( ADDR_WID ),
                .DATA_WID ( DATA_WID ),
                .OPT_MODE ( OPT_MODE )
            ) i_xilinx_ram_tdp_bram (
                .*
            );
        end : g__bram
        else if (_RAM_STYLE == RAM_STYLE_DISTRIBUTED) begin : g__lutram
            xilinx_ram_tdp_lutram #(
                .ADDR_WID ( ADDR_WID ),
                .DATA_WID ( DATA_WID )
            ) i_xilinx_ram_tdp_lutram (
                .*
            );
        end : g__lutram
    endgenerate

    generate
        if (WR_LATENCY > 0) begin : g__wr_ack_pipe
            logic wr_p_A [WR_LATENCY];
            logic wr_p_B [WR_LATENCY];
            // Port A
            always @(posedge clk_A) begin
                for (int i = 1; i < WR_LATENCY; i++) begin
                    wr_p_A[i] <= wr_p_A[i-1];
                end
                wr_p_A[0] <= en_A && wr_A;
            end
            assign wr_ack_A = wr_p_A[WR_LATENCY-1];
            // Port B
            always @(posedge clk_B) begin
                for (int i = 1; i < WR_LATENCY; i++) begin
                    wr_p_B[i] <= wr_p_B[i-1];
                end
                wr_p_B[0] <= en_B && wr_B;
            end
            assign wr_ack_B = wr_p_B[WR_LATENCY-1];
        end : g__wr_ack_pipe
        else begin : g__wr_ack_no_pipe
            assign wr_ack_A = en_A && wr_A;
            assign wr_ack_B = en_B && wr_B;
        end : g__wr_ack_no_pipe

        if (RD_LATENCY > 0 ) begin : g__rd_ack_pipe
            logic rd_p_A [RD_LATENCY];
            logic rd_p_B [RD_LATENCY];
            // Port A
            always @(posedge clk_A) begin
                for (int i = 1; i < RD_LATENCY; i++) begin
                    rd_p_A[i] <= rd_p_A[i-1];
                end
                rd_p_A[0] <= en_A && !wr_A;
            end
            assign rd_ack_A = rd_p_A[RD_LATENCY-1];
            // Port B
            always @(posedge clk_B) begin
                for (int i = 1; i < RD_LATENCY; i++) begin
                    rd_p_B[i] <= rd_p_B[i-1];
                end
                rd_p_B[0] <= en_B && !wr_B;
            end
            assign rd_ack_B = rd_p_B[RD_LATENCY-1];
        end : g__rd_ack_pipe
        else begin : g__rd_ack_no_pipe
            assign rd_ack_A = en_A;
            assign rd_ack_B = en_B;
        end : g__rd_ack_no_pipe
    endgenerate
 
endmodule : xilinx_ram_tdp
