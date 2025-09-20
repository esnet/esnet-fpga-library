module reg_ro #(
    parameter int WID = 32
)(
    input  logic           clk,
    input  logic           srst,
    input  logic [WID-1:0] INIT_VALUE = '0,
    input  logic           upd_en,
    input  logic [WID-1:0] upd_data,
    output logic [WID-1:0] rd_data
);

    logic [WID-1:0] _reg = '0;
    always_ff @(posedge clk) begin
        if (srst) _reg <= INIT_VALUE;
        else if (upd_en) _reg <= upd_data;
    end
    assign rd_data = _reg;

endmodule : reg_ro

