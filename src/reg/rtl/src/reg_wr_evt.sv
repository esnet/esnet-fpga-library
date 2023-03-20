module reg_wr_evt #(
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
    output T                              rd_data,
    output logic                          wr_evt
);

    // Implement underlying register as read/write
    reg_rw #(.T(T), .INIT_VALUE(INIT_VALUE), .WR_DATA_BYTES(WR_DATA_BYTES)) _reg_rw (.*);

    // Synthesize write event strobe
    logic _evt = 1'b0;
    always_ff @(posedge clk) begin
        if (srst) _evt <= 1'b0;
        else begin
            if (wr && wr_en) _evt <= 1'b1;
            else             _evt <= 1'b0;
        end
    end
    assign wr_evt = _evt;

endmodule : reg_wr_evt
