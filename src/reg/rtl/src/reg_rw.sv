module reg_rw #(
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
    output T                              rd_data
);

    localparam int BITS = $bits(T);
    localparam int BYTES = BITS % 8 == 0 ? BITS / 8 : BITS / 8 + 1;

    union packed {
        logic [WR_DATA_BYTES-1:0][7:0] as_bytes;
        logic [WR_DATA_BYTES*8-1:0]    as_bits;
    } _reg;

    initial _reg = INIT_VALUE;
    always @(posedge clk) begin
        if (srst) _reg <= INIT_VALUE;
        else begin
            if (wr && wr_en) begin
                for (int i = 0; i < BYTES; i++) begin
                    if (wr_byte_en[i]) _reg.as_bytes[i] <= wr_data[i];
                end
            end
        end
    end
    assign rd_data = _reg.as_bits[BITS-1:0];

endmodule : reg_rw
