module reg_rw #(
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

    localparam int BYTES = WID % 8 == 0 ? WID / 8 : WID / 8 + 1;

    union packed {
        logic [WR_DATA_BYTES-1:0][7:0] as_bytes;
        logic [WR_DATA_BYTES*8-1:0]    as_bits;
    } _reg;

    initial _reg = '0;
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
    assign rd_data = _reg.as_bits[WID-1:0];

endmodule : reg_rw
