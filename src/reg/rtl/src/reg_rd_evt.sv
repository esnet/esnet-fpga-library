module reg_rd_evt #(
    parameter type T = bit[31:0],
    parameter T INIT_VALUE = 0
)(
    input  logic clk,
    input  logic srst,
    input  logic upd_en,
    input  T     upd_data,
    output T     rd_data,
    input  logic rd,
    input  logic rd_en,
    output logic rd_evt
);

    // Implement underlying register as read only
    reg_ro #(.T (T), .INIT_VALUE (INIT_VALUE)) _reg_ro (.*);

    // Synthesize read event strobe
    assign rd_evt = rd && rd_en;

endmodule : reg_rd_evt
