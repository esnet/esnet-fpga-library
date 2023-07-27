// Level synchronizer
// - synchronizes level (slowly or infrequently-changing signal)
//   from input clock domain to output using two-way handshake
// - converts level change (edge) into an event and passes to
//   output using a two-way handshake. The output is guaranteed to
//   see the edge, but the input level is not sampled again until
//   the synchronization process is complete, so it is possible for
//   closely-spaced transitions to be missed.
// - the rdy_in output in the input clock domain can be used to
//   monitor readiness and detect possible missed transitions.
module sync_level
    import sync_pkg::*;
#(
    parameter logic RST_VALUE = 1'bx
) (
    // Input clock domain
    input  logic clk_in,
    input  logic rst_in,
    output logic rdy_in,
    input  logic lvl_in,
    // Output clock domain
    input  logic clk_out,
    input  logic rst_out,
    output logic lvl_out
);
    // Typedefs
    typedef enum logic [1:0] {
        RESET,
        READY,
        WAIT
    } state_t;

    // Signals
    state_t state;
    state_t nxt_state;

    logic _lvl_in;
    logic _ack_in;

    // 2-phase handshaking FSM
    initial state = RESET;
    always @(posedge clk_in) begin
        if (rst_in) state <= RESET;
        else        state <= nxt_state;
    end
    
    always_comb begin
        nxt_state = state;
        rdy_in = 1'b0;
        case (state)
            RESET : begin
                nxt_state = READY;
            end
            READY : begin
                rdy_in = 1'b1;
                // Detect input transitions
                if (lvl_in != _lvl_in) nxt_state = WAIT;
            end
            WAIT : begin
                // Wait for output level to match input level
                if (_ack_in == _lvl_in) nxt_state = READY;
            end
            default : begin
                nxt_state = RESET;
            end
        endcase
    end

    // State register (last synchronized level)
    initial _lvl_in = RST_VALUE;
    always @(posedge clk_in) begin
        if (rst_in) _lvl_in <= RST_VALUE;
        else if (rdy_in) _lvl_in <= lvl_in;
    end

    // Synchronize input level to output
    sync_meta     #(
        .DATA_T    ( logic ),
        .RST_VALUE ( RST_VALUE )
    ) i_sync_meta__lvl_in (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .sig_in    ( _lvl_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .sig_out   ( lvl_out )
    );

    // Synchronize output level to input
    sync_meta     #(
        .DATA_T    ( logic ),
        .RST_VALUE ( RST_VALUE )
    ) i_sync_meta__lvl_out (
        .clk_in    ( clk_out ),
        .rst_in    ( rst_out ),
        .sig_in    ( lvl_out ),
        .clk_out   ( clk_in ),
        .rst_out   ( rst_in ),
        .sig_out   ( _ack_in )
    );

endmodule : sync_level
