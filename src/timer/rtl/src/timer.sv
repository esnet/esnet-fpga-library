module timer #(
    parameter int TIMER_WID = 1
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
    output logic [TIMER_WID-1:0] timer
);

    initial timer = '0;
    always @(posedge clk) begin
        if (srst || reset) timer <= '0;
        else if (tick && !freeze) timer <= timer + 1;
    end
 
endmodule : timer
