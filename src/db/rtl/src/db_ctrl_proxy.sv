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

module db_ctrl_proxy #(
    parameter int TIMEOUT_CYCLES = 0
) (
    // Clock/reset
    input  logic clk,
    input  logic srst,

    // Control interface (from controller)
    db_ctrl_intf.peripheral ctrl_if_from_controller,

    // Control interface (to peripheral)
    db_ctrl_intf.controller ctrl_if_to_peripheral
);
    // -----------------------------
    // Typedefs
    // -----------------------------
    import db_pkg::*;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [2:0] {
        RESET,
        IDLE,
        REQ_PENDING,
        RESP_PENDING,
        DONE,
        TIMEOUT
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic reset_timer;
    logic inc_timer;
    logic timeout;

    status_t status;

    // -----------------------------
    // Transaction FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        reset_timer = 1'b0;
        inc_timer = 1'b0;
        ctrl_if_from_controller.rdy = 1'b0;
        ctrl_if_to_peripheral.req = 1'b0;
        ctrl_if_from_controller.ack = 1'b0;
        case (state)
            RESET : begin
                nxt_state = IDLE;
            end
            IDLE : begin
                reset_timer = 1'b1;
                ctrl_if_from_controller.rdy = 1'b1;
                if (ctrl_if_from_controller.req) nxt_state = REQ_PENDING;
            end
            REQ_PENDING : begin
                inc_timer = 1'b1;
                ctrl_if_to_peripheral.req = 1'b1;
                if (ctrl_if_to_peripheral.rdy) nxt_state = RESP_PENDING;
                else if (timeout)              nxt_state = TIMEOUT;
            end
            RESP_PENDING : begin
                inc_timer = 1'b1;
                if (ctrl_if_to_peripheral.ack) nxt_state = DONE;
                else if (timeout)              nxt_state = TIMEOUT;
            end
            DONE : begin
                ctrl_if_from_controller.ack = 1'b1;
                ctrl_if_from_controller.status = status;
                nxt_state = IDLE;
            end
            TIMEOUT : begin
                ctrl_if_from_controller.ack = 1'b1;
                ctrl_if_from_controller.status = STATUS_TIMEOUT;
                nxt_state = IDLE;
            end
        endcase
    end

    // Implement (optional) timeout logic
    generate
        if (TIMEOUT_CYCLES > 0) begin : g__timeout
            localparam int TIMEOUT_WID = $clog2(TIMEOUT_CYCLES);
            logic [TIMEOUT_WID-1:0] timer;

            initial timer = 0;
            always @(posedge clk) begin
                if (reset_timer) timer <= 0;
                else if (inc_timer) timer <= timer + 1;
            end
            assign timeout = (timer == TIMEOUT_CYCLES-1);
        end : g__timeout
        else begin : g__no_timeout
            assign timeout = 1'b0;
        end : g__no_timeout
    endgenerate

    // Latch request context
    always_ff @(posedge clk) begin
        if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) begin
            ctrl_if_to_peripheral.command <= ctrl_if_from_controller.command;
            ctrl_if_to_peripheral.key <= ctrl_if_from_controller.key;
            ctrl_if_to_peripheral.set_value <= ctrl_if_from_controller.set_value;
        end
    end

    // Latch response
    always_ff @(posedge clk) begin
        if (ctrl_if_to_peripheral.ack) begin
            status <= ctrl_if_to_peripheral.status;
            ctrl_if_from_controller.valid <= ctrl_if_to_peripheral.valid;
            ctrl_if_from_controller.get_value <= ctrl_if_to_peripheral.get_value;
        end
    end

endmodule : db_ctrl_proxy
