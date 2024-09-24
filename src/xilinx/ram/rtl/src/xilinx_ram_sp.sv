// Single-Port RAM implementation
module xilinx_ram_sp
    import xilinx_ram_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING // Determines whether RAM configuration is optimized for
                                                    // best timing performance (OPT_MODE_TIMING) or minimum
                                                    // latency (OPT_MODE_LATENCY).
                                                    // OPT_MODE_TIMING is recommended in most cases.
) (
    input  logic                clk,
    input  logic                en,
    input  logic                wr,
    input  logic [ADDR_WID-1:0] addr,
    input  logic [DATA_WID-1:0] wr_data,
    output logic                wr_ack,
    output logic [DATA_WID-1:0] rd_data,
    output logic                rd_ack
);

    // -----------------------------
    // PARAMETERS
    // -----------------------------
    // RAM style is auto-determined by size, aspect ratio and 
    localparam ram_style_t _RAM_STYLE = get_default_ram_style(ADDR_WID, DATA_WID, 0, OPT_MODE);

    localparam int WR_LATENCY = get_wr_latency(ADDR_WID, DATA_WID, 0, OPT_MODE);
    localparam int RD_LATENCY = get_rd_latency(ADDR_WID, DATA_WID, 0, OPT_MODE);

    generate
        if (_RAM_STYLE == RAM_STYLE_ULTRA) begin : g__uram
            xilinx_ram_sp_uram #(
                .ADDR_WID ( ADDR_WID ),
                .DATA_WID ( DATA_WID ),
                .OPT_MODE ( OPT_MODE )
            ) i_xilinx_ram_sp_uram (
                .clk ( clk ),
                .*
            );
        end : g__uram
        else if (_RAM_STYLE == RAM_STYLE_BLOCK) begin : g__bram
            logic srst;
            logic rd_regce;
            assign srst = 1'b0;
            assign rd_regce = 1'b1;

            xilinx_ram_sp_bram #(
                .ADDR_WID ( ADDR_WID ),
                .DATA_WID ( DATA_WID ),
                .OPT_MODE ( OPT_MODE )
            ) i_xilinx_ram_sp_bram (
                .*
            );
        end : g__bram
        else if (_RAM_STYLE == RAM_STYLE_DISTRIBUTED) begin : g__lutram
            xilinx_ram_sp_lutram #(
                .ADDR_WID ( ADDR_WID ),
                .DATA_WID ( DATA_WID )
            ) i_xilinx_ram_sp_lutram (
                .*
            );
        end : g__lutram
    endgenerate

    generate
        if (WR_LATENCY > 0) begin : g__wr_ack_pipe
            logic wr_p[WR_LATENCY];
            always @(posedge clk) begin
                for (int i = 1; i < WR_LATENCY; i++) begin
                    wr_p[i] <= wr_p[i-1];
                end
                wr_p[0] <= en && wr;
            end
            assign wr_ack = wr_p[WR_LATENCY-1];
        end : g__wr_ack_pipe
        else begin : g__wr_ack_no_pipe
            assign wr_ack = en && wr;
        end : g__wr_ack_no_pipe

        if (RD_LATENCY > 0 ) begin : g__rd_ack_pipe
            logic rd_p [RD_LATENCY];
            always @(posedge clk) begin
                for (int i = 1; i < RD_LATENCY; i++) begin
                    rd_p[i] <= rd_p[i-1];
                end
                rd_p[0] <= en && !wr;
            end
            assign rd_ack = rd_p[RD_LATENCY-1];
        end : g__rd_ack_pipe
        else begin : g__rd_ack_no_pipe
            assign rd_ack = en;
        end : g__rd_ack_no_pipe
    endgenerate
 
endmodule : xilinx_ram_sp
