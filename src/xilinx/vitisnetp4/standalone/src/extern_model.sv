module extern_model #(
    parameter int LATENCY = 1,
    parameter type DATA_IN_T = bit,
    parameter type DATA_OUT_T = bit,
    parameter DATA_OUT_T DATA_OUT = '0
)(
    input logic       clk,
    input logic       srst,
    input logic       valid_in,
    input DATA_IN_T   data_in,
    output logic      valid_out,
    output DATA_OUT_T data_out
);
    logic valid_p [LATENCY];

    initial valid_p = '{LATENCY{1'b0}};
    always @(posedge clk) begin
        if (srst) valid_p <= '{LATENCY{1'b0}};
        else begin
            for (int i = 1; i < LATENCY; i++) valid_p[i] <= valid_p[i-1];
            valid_p[0] <= valid_in;
        end
    end
    assign valid_out = valid_p[LATENCY-1];

    assign data_out = DATA_OUT;

endmodule : extern_model
