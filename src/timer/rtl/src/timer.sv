module timer #(
    parameter type TIMER_T = logic
)(
    // Clock/reset
    input  logic   clk,
    input  logic   srst,

    // Control
    input  logic   reset,
    input  logic   freeze,

    // Tick input
    input  logic   tick,

    // Timer output
    output TIMER_T timer
);

    initial timer = '0;
    always @(posedge clk) begin
        if (srst || reset) timer <= '0;
        else if (tick && !freeze) timer <= timer + 1;
    end
 
endmodule : timer
