module reg_wo #(
    parameter type T = bit[31:0],
    parameter T INIT_VALUE = 0,
    parameter int WR_DATA_BYTES = 4
)(
    input  logic                          clk,
    input  logic                          srst,
    input  logic                          wr,
    input  logic                          wr_en,
    input  logic [WR_DATA_BYTES-1:0][7:0] wr_data,
    input  logic [WR_DATA_BYTES-1:0]      wr_byte_en,
    output logic                          wr_evt
);
    // Read data is not externally available
    T rd_data;
    
    // Implement underlying register as write event
    reg_wr_evt #(.T(T), .INIT_VALUE(INIT_VALUE), .WR_DATA_BYTES(WR_DATA_BYTES)) _reg_wr_evt (.*);

endmodule : reg_wo
