module timer_tick
#(
    parameter int TCLK_PER_TICK = 10**3, // Conversion factor describing # of
                                         // input tclk ticks comprising
                                         // one output timer tick
                                         // e.g. for microsecond clock,
                                         //      TCLK_PER_TICK = 10**3
                                         //      yields tick period of 1ms
                                         // Note: TCLK_PER_TICK == 0 sets tclk == clk,
                                         //       so tick is generated continuously
    parameter bit TCLK_DDR = 1           // TCLK_DDR == 1: Process both positive and
                                         //   negative edges of tclk (consistent with
                                         //   generating the clock from the LSb of a timestamp)
                                         // TCLK_DDR == 0: Process positive edges of tclk only
)(
    // Clock/reset
    input logic  clk,
    input logic  srst,

    // Control
    input logic  squelch,

    // Input 'timer' clock
    input logic  tclk,

    // Output timer pulse
    output logic tick
);
    // -----------------------------------
    // Signals
    // -----------------------------------
    logic tclk_reg;
    logic tclk_event;
    logic tclk_pulse;
    logic __tick;

    // -----------------------------------
    // Logic
    // -----------------------------------
    // Detect tclk edges
    initial tclk_reg = 0;
    always @(posedge clk) tclk_reg <= tclk;

    assign tclk_event = TCLK_DDR ? tclk != tclk_reg : tclk && !tclk_reg;

    initial tclk_pulse = 1'b0;
    always @(posedge clk) begin
        if (srst)            tclk_pulse <= 1'b0;
        else if (tclk_event) tclk_pulse <= 1'b1;
        else                 tclk_pulse <= 1'b0;
    end

    // Convert tclk rising edge events to tick
    generate
        if (TCLK_PER_TICK > 1) begin : g__tclk_div
            // (Local) parameters
            localparam int TCLK_COUNT_WID = $clog2(TCLK_PER_TICK);
            // (Local) signals
            logic [TCLK_COUNT_WID-1:0] tclk_cnt;

            initial tclk_cnt = 0;
            always @(posedge clk) begin
                if (srst) tclk_cnt <= 0;
                else if (tclk_pulse) begin
                    if (tclk_cnt == TCLK_PER_TICK-1) tclk_cnt <= 0;
                    else                             tclk_cnt <= tclk_cnt + 1;
                end
            end

            initial __tick = 0;
            always @(posedge clk) begin
                if (srst)                                           __tick <= 1'b0;
                else if (tclk_pulse && tclk_cnt == TCLK_PER_TICK-1) __tick <= 1'b1;
                else                                                __tick <= 1'b0;
            end
        end : g__tclk_div
        else if (TCLK_PER_TICK == 1) begin : g__tclk_no_div
            assign __tick = tclk_pulse;
        end : g__tclk_no_div
        else if (TCLK_PER_TICK == 0) begin : g__no_tclk
            // Ignore tclk; tick is generated on every clk cycle when not in reset
            initial __tick = 1'b0;
            always @(posedge clk) begin
                if (srst) __tick <= 1'b0;
                else      __tick <= 1'b1;
            end
        end : g__no_tclk
    endgenerate

    always_ff @(posedge clk) tick <= squelch ? 1'b0 : __tick;

endmodule : timer_tick
