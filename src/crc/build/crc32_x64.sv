module crc32_x64 (
    input  logic clk,
    input  logic srst,
    input  logic en,
    input  logic [0:63][7:0] data,
    output logic [31:0] crc
);
    import crc_pkg::*;

    logic             _en;
    logic [0:63][7:0] _data;
    logic [31:0]      _crc;

    crc #(
        .CONFIG (crc_pkg::CRC32.cfg),
        .DATA_BYTES (64)
    ) i_crc (
        .clk  (clk),
        .srst (srst),
        .en   (_en),
        .data (_data),
        .crc  (_crc)
    );

    initial begin
        _en = 1'b0;
        _data = 0;
    end
    always @(posedge clk) begin
        _en <= en;
        _data <= data;
    end

    initial crc = 1'b0;
    always @(posedge clk) crc <= _crc;

endmodule : crc32_x64
