// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

module state_timer_tick
#(
    parameter int TS_PER_TICK = 10**3, // Conversion factor describing # of
                                       // input ts_clk ticks comprising
                                       // one output timer tick
                                       // e.g. for microsecond timestamp clock,
                                       //      TS_PER_TICK = 10**3
                                       //      yields tick period of 1ms
                                       // Note: TS_PER_TICK == 0 sets ts_clk == clk,
                                       //       so tick is generated continuously
    parameter bit TS_CLK_DDR = 1       // TS_CLK_DDR == 1: Process both positive and
                                       //   negative edges of ts_clk (consistent with
                                       //   generating the clock from the LSb of a timestamp)
                                       // TS_CLK_DDR == 0: Process positive edges of ts_clk only
)(
    // Clock/reset
    input logic  clk,
    input logic  srst,

    // Control
    input logic  squelch,

    // Input 'timestamp' clock
    input logic  ts_clk,

    // Output timer pulse
    output logic tick
);
  
    // -----------------------------------
    // Parameters
    // -----------------------------------
    localparam int TIMER_WID = TS_PER_TICK > 1 ? $clog2(TS_PER_TICK) : 1;

    // -----------------------------------
    // Signals
    // -----------------------------------
    logic ts_clk_reg;
    logic ts_clk_event;
    logic ts_pulse;
    logic __tick;

    // -----------------------------------
    // Logic
    // -----------------------------------
    // Detect ts_clk edges
    initial ts_clk_reg = 0;
    always @(posedge clk) ts_clk_reg <= ts_clk;

    assign ts_clk_event = TS_CLK_DDR ? ts_clk != ts_clk_reg : ts_clk && !ts_clk_reg;

    initial ts_pulse = 1'b0;
    always @(posedge clk) begin
        if (srst)              ts_pulse <= 1'b0;
        else if (ts_clk_event) ts_pulse <= 1'b1;
        else                   ts_pulse <= 1'b0;
    end

    // Convert ts_clk rising edge events to tick
    generate
        if (TS_PER_TICK > 1) begin : g__ts_clk_div
            logic [TIMER_WID-1:0] timer;

            initial timer = 0;
            always @(posedge clk) begin
                if (srst) timer <= 0;
                else if (ts_pulse) begin
                    if (timer == TS_PER_TICK-1) timer <= 0;
                    else                        timer <= timer + 1;
                end
            end

            initial __tick = 0;
            always @(posedge clk) begin
                if (srst)                                    __tick <= 1'b0;
                else if (ts_pulse && timer == TS_PER_TICK-1) __tick <= 1'b1;
                else                                         __tick <= 1'b0;
            end
        end : g__ts_clk_div
        else if (TS_PER_TICK == 1) begin : g__ts_clk_no_div
            assign __tick = ts_pulse;
        end : g__ts_clk_no_div
        else if (TS_PER_TICK == 0) begin : g__no_ts_clk
            // Ignore ts_clk; tick is generated on every clk cycle when not in reset
            initial __tick = 1'b0;
            always @(posedge clk) begin
                if (srst) __tick <= 1'b0;
                else      __tick <= 1'b1;
            end
        end : g__no_ts_clk
    endgenerate

    always_ff @(posedge clk) tick <= squelch ? 1'b0 : __tick;

endmodule : state_timer_tick
