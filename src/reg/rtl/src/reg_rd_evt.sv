module reg_rd_evt #(
    parameter int WID = 32
)(
    input  logic           clk,
    input  logic           srst,
    input  logic [WID-1:0] INIT_VALUE = '0,
    input  logic           upd_en,
    input  logic [WID-1:0] upd_data,
    output logic [WID-1:0] rd_data,
    input  logic           rd,
    input  logic           rd_en,
    output logic           rd_evt
);

    // Implement underlying register as read only
    reg_ro #(.WID (WID)) _reg_ro (.*);

    // Synthesize read event strobe
    assign rd_evt = rd && rd_en;

endmodule : reg_rd_evt
