// Exercise standard/FWFT LUTRAM and BRAM FIFOs, a scalar payload and a
// synchronous FIFO. The generic RAM has no pointer protocol and must not be waived.
module fifo_core_cdc_wrapper (
    input logic wr_clk, rd_clk, wr_srst, rd_srst,
    input logic [5:0] wr, rd,
    input logic [22:0] wr_data,
    output logic [79:0] rd_data,
    output logic [5:0] rd_ack, wr_full, rd_empty,
    input logic [4:0] arbitrary_wr_addr, arbitrary_rd_addr,
    input logic arbitrary_wr, arbitrary_rd,
    output logic [10:0] arbitrary_data
);
    fifo_core_cdc_case #(.WIDTH(13), .DEPTH(32), .FWFT(0)) lut_std (
        .wr_clk, .rd_clk, .wr_srst, .rd_srst, .wr(wr[0]), .rd(rd[0]),
        .wr_data(wr_data[12:0]), .rd_data(rd_data[12:0]),
        .rd_ack(rd_ack[0]), .wr_full(wr_full[0]), .rd_empty(rd_empty[0])
    );
    fifo_core_cdc_case #(.WIDTH(17), .DEPTH(128), .FWFT(1)) lut_fwft (
        .wr_clk, .rd_clk, .wr_srst, .rd_srst, .wr(wr[1]), .rd(rd[1]),
        .wr_data(wr_data[16:0]), .rd_data(rd_data[29:13]),
        .rd_ack(rd_ack[1]), .wr_full(wr_full[1]), .rd_empty(rd_empty[1])
    );
    fifo_core_cdc_case #(.WIDTH(1), .DEPTH(16), .FWFT(1)) lut_scalar (
        .wr_clk, .rd_clk, .wr_srst, .rd_srst, .wr(wr[2]), .rd(rd[2]),
        .wr_data(wr_data[0]), .rd_data(rd_data[30]),
        .rd_ack(rd_ack[2]), .wr_full(wr_full[2]), .rd_empty(rd_empty[2])
    );
    fifo_core_cdc_case #(.WIDTH(19), .DEPTH(512), .FWFT(0)) bram_std (
        .wr_clk, .rd_clk, .wr_srst, .rd_srst, .wr(wr[3]), .rd(rd[3]),
        .wr_data(wr_data[18:0]), .rd_data(rd_data[49:31]),
        .rd_ack(rd_ack[3]), .wr_full(wr_full[3]), .rd_empty(rd_empty[3])
    );
    fifo_core_cdc_case #(.WIDTH(23), .DEPTH(512), .FWFT(1)) bram_fwft (
        .wr_clk, .rd_clk, .wr_srst, .rd_srst, .wr(wr[4]), .rd(rd[4]),
        .wr_data, .rd_data(rd_data[72:50]),
        .rd_ack(rd_ack[4]), .wr_full(wr_full[4]), .rd_empty(rd_empty[4])
    );
    fifo_core_cdc_case #(.WIDTH(7), .DEPTH(32), .ASYNC(0), .FWFT(1)) synchronous_fifo (
        .wr_clk, .rd_clk(wr_clk), .wr_srst, .rd_srst(wr_srst),
        .wr(wr[5]), .rd(rd[5]), .wr_data(wr_data[6:0]), .rd_data(rd_data[79:73]),
        .rd_ack(rd_ack[5]), .wr_full(wr_full[5]), .rd_empty(rd_empty[5])
    );
    logic arbitrary_rd_en;
    always @(posedge rd_clk) arbitrary_rd_en <= arbitrary_rd;
    xilinx_ram_sdp_lutram #(.ADDR_WID(5), .DATA_WID(11)) unrelated_ram (
        .wr_clk, .wr_en(1'b1), .wr_req(arbitrary_wr),
        .wr_addr(arbitrary_wr_addr), .wr_data(wr_data[10:0]),
        .rd_clk, .rd_srst(1'b0), .rd_en(arbitrary_rd_en),
        .rd_addr(arbitrary_rd_addr), .rd_data(arbitrary_data)
    );
endmodule

module fifo_core_cdc_case #(
    parameter int WIDTH = 13,
    parameter int DEPTH = 32,
    parameter bit ASYNC = 1,
    parameter bit FWFT = 1
) (
    input logic wr_clk, rd_clk, wr_srst, rd_srst, wr, rd,
    input logic [WIDTH-1:0] wr_data,
    output logic [WIDTH-1:0] rd_data,
    output logic rd_ack, wr_full, rd_empty
);
    fifo_mon_intf wr_mon_if (.clk(wr_clk));
    fifo_mon_intf rd_mon_if (.clk(rd_clk));
    fifo_core #(.DATA_WID(WIDTH), .DEPTH(DEPTH), .ASYNC(ASYNC), .FWFT(FWFT)) fifo (
        .wr_clk, .wr_srst, .wr, .wr_data, .wr_rdy(), .wr_count(), .wr_full, .wr_oflow(),
        .rd_clk, .rd_srst, .rd, .rd_ack, .rd_data, .rd_count(), .rd_empty, .rd_uflow(),
        .wr_mon_if, .rd_mon_if
    );
endmodule
