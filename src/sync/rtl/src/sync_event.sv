// Event synchronizer
// - synchronizes events (pulses) from the input to the
//   output clock domain using a two-way handshake
// - NOTE: slow, but suitable for instances where
//   events occur infrequently by design (i.e. register write event)
//   In many cases, an async FIFO is a better choice.
module sync_event
    import sync_pkg::*;
#(
    parameter handshake_mode_t MODE = HANDSHAKE_MODE_4PHASE
) (
    // Input clock domain
    input  logic clk_in,
    input  logic rst_in,
    output logic rdy_in,
    input  logic evt_in,
    // Output clock domain
    input  logic clk_out,
    input  logic rst_out,
    output logic evt_out
);

    // Signals
    logic _req_in;
    logic _req_out;
    logic _ack_in;
    logic _req_out_d;

    // Handshaking FSM (next-state logic)
    generate
        if (MODE == HANDSHAKE_MODE_4PHASE) begin : g__handshake_4phase
            // Typedefs
            typedef enum logic [1:0] {
                RESET,
                READY,
                REQ,
                WAIT
            } state_t;

            // (Local) signals
            state_t state;
            state_t nxt_state;

            // 4-phase handshaking FSM
            initial state = RESET;
            always @(posedge clk_in) begin
                if (rst_in) state <= RESET;
                else        state <= nxt_state;
            end

            always_comb begin
                nxt_state = state;
                rdy_in = 1'b0;
                _req_in = 1'b0;
                case (state)
                    RESET : begin
                        nxt_state = READY;
                    end
                    READY : begin
                        rdy_in = 1'b1;
                        if (evt_in) nxt_state = REQ;
                    end
                    REQ : begin
                        _req_in = 1'b1;
                        if (_ack_in) nxt_state = WAIT;
                    end
                    WAIT : begin
                        if (!_ack_in) nxt_state = READY;
                    end
                endcase
            end

            // Retimed event (pulse on rising edge of request)
            assign evt_out = _req_out && !_req_out_d;

        end : g__handshake_4phase
        else if (MODE == HANDSHAKE_MODE_2PHASE) begin : g__handshake_2phase
            // Typedefs
            typedef enum logic [1:0] {
                RESET,
                READY,
                WAIT
            } state_t;

            // (Local) signals
            state_t state;
            state_t nxt_state;
            logic _req_in_d;

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
                        if (evt_in) nxt_state = WAIT;
                    end
                    WAIT : begin
                        if (_ack_in == _req_in_d) nxt_state = READY;
                    end
                    default : begin
                        nxt_state = RESET;
                    end
                endcase
            end

            initial _req_in_d = 1'b0;
            always @(posedge clk_in) begin
                if (rst_in) _req_in_d <= 1'b0;
                else        _req_in_d <= _req_in;
            end

            // New events are signaled with edges (rising and falling)
            always_comb begin
                _req_in = _req_in_d;
                if (evt_in && rdy_in) _req_in = !_req_in_d;
            end

            // Retimed event (edge detector)
            assign evt_out = _req_out ^ _req_out_d;

        end : g__handshake_2phase
    endgenerate

    // Synchronize REQ (input -> output)
    sync_meta #(
        .DATA_T    ( logic ),
        .RST_VALUE ( 1'b0 )
    ) i_sync_meta__req  (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .sig_in    ( _req_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .sig_out   ( _req_out )
    );

    // Synchronize ACK (output -> input)
    sync_meta #(
        .DATA_T    ( logic ),
        .RST_VALUE ( 1'b0 )
    ) i_sync_meta__ack  (
        .clk_in    ( clk_out ),
        .rst_in    ( rst_out ),
        .sig_in    ( _req_out ),
        .clk_out   ( clk_in ),
        .rst_out   ( rst_in ),
        .sig_out   ( _ack_in )
    );

    // Register last request for edge detection
    initial _req_out_d = 1'b0;
    always @(posedge clk_out) begin
        if (rst_out) _req_out_d <= 1'b0;
        else         _req_out_d <= _req_out;
    end

endmodule : sync_event
