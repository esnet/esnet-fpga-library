// Round-robin arbiter
module arb_rr
    import arb_pkg::*;
#(
    parameter arb_rr_mode_t MODE = RR, // RR = Round-Robin, WCRR = Work-Conserving Round-Robin.
    parameter int N = 2
) (
    input  logic clk,
    input  logic srst,
    input  logic en,
    input  logic [N-1:0] req,   // per-input req
    output logic [N-1:0] grant, // one-hot grant
    input  logic [N-1:0] ack,   // per-input ack (for multi-cycle grant support)
    output integer sel          // binary selector (not gated by enable)
);
    // Parameters
    localparam int SEL_WID = $clog2(N);

    // Typdefs
    typedef enum logic [1:0] {
        RESET,
        GRANT,
        HOLD
    } state_t;

    // Signals
    state_t state;
    state_t nxt_state;

    logic [SEL_WID-1:0] _idx;
    logic reset_idx;
    logic inc_idx;

    logic [SEL_WID-1:0] sel_r;
    logic [N-1:0] grant_r;


    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        reset_idx = 1'b0;
        inc_idx = 1'b0;
        case (state)
            RESET : begin
                reset_idx = 1'b1;
                nxt_state = GRANT;
            end
            GRANT : begin
                inc_idx = 1'b1;
                if (en && req[sel]) begin
                    if (ack[sel]) nxt_state = GRANT;
                    else          nxt_state = HOLD;
                end
            end
            HOLD : begin
                if (ack[sel]) nxt_state = GRANT;
            end
            default : begin
                nxt_state = RESET;
            end
        endcase
    end

    // Round-robin arbitration
    // - maintain arb state
    always_comb begin
       if (reset_idx) _idx = 0;
       else if (en && inc_idx && (req != '0)) begin
          _idx = (sel_r >= N-1) ? 0 : sel_r + 1;
          if (MODE == WCRR)
             for (int i = 0; i < N-1; i++) if (req[_idx] != 1) _idx = (_idx >= N-1) ? 0 : _idx + 1;
       end else _idx = sel_r;
    end

    assign sel = _idx;

    // Synthesize grant vector based on arb decision
    always_comb begin
        if (state == HOLD) grant = grant_r;
        else if (state == GRANT && en && req[sel]) grant = (1 << sel);
        else grant = '0;
    end

    // Register selections
    always_ff @(posedge clk) begin
        sel_r <= sel;
        grant_r <= grant;
    end
    
endmodule : arb_rr
