module reg_wo #(
    parameter int WID = 32,
    parameter int WR_DATA_BYTES = 4
)(
    input  logic                          clk,
    input  logic                          srst,
    input  logic [WID-1:0]                INIT_VALUE = '0,
    input  logic                          wr,
    input  logic                          wr_en,
    input  logic [WR_DATA_BYTES-1:0][7:0] wr_data,
    input  logic [WR_DATA_BYTES-1:0]      wr_byte_en,
    output logic [WID-1:0]                rd_data
);
    // Implement underlying register as read/write
    reg_rw #(.WID(WID), .WR_DATA_BYTES(WR_DATA_BYTES)) _reg_wr (.*);

endmodule : reg_wo
