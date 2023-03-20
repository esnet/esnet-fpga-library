module reg_ro #(
    parameter type T = bit[31:0],
    parameter T INIT_VALUE = 0
)(
    input  logic clk,
    input  logic srst,
    input  logic upd_en,
    input  T     upd_data,
    output T     rd_data
);

    T _reg = INIT_VALUE;
    always_ff @(posedge clk) begin
        if (srst) _reg <= INIT_VALUE;
        else if (upd_en) _reg <= upd_data;
    end
    assign rd_data = _reg;

endmodule : reg_ro

