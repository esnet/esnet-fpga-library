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
module state_expiry_fsm #(
    parameter type ID_T = logic[15:0],
    parameter type STATE_T = logic
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    input  logic               en,
    input  logic               init_done,

    // Control interface
    db_ctrl_intf.controller    ctrl_if,

    // Expiry interface
    output STATE_T             state,
    input  logic               expired,

    // Timeout event notification feed
    std_event_intf.publisher   notify_if,

    // Debug interface
    output logic [3:0]         dbg_state,
    output logic               dbg_scan_done,
    output logic               dbg_check,
    output logic               dbg_notify,
    output logic               dbg_error
);

    // -----------------------------
    // 
    // -----------------------------
    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [2:0] {
        RESET         = 0,
        IDLE          = 1,
        STATE_RD_REQ  = 2,
        STATE_RD_WAIT = 3,
        CHECK         = 4,
        NOTIFY        = 5,
        ERROR         = 6,
        DONE          = 7
    } fsm_state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic __en;

    logic local_srst__unbuffered;
    logic local_srst;

    fsm_state_t fsm_state;
    fsm_state_t nxt_fsm_state;

    logic check;
    logic notify;
    logic error;

    ID_T  id;
    logic reset_id;
    logic inc_id;

    // -----------------------------
    // Expiry state machine
    // -----------------------------
    initial fsm_state = RESET;
    always @(posedge clk) begin
        if (local_srst)      fsm_state <= RESET;
        else if (!init_done) fsm_state <= RESET;
        else                 fsm_state <= nxt_fsm_state;
    end

    always_comb begin
        nxt_fsm_state = fsm_state;
        check = 1'b0;
        notify = 1'b0;
        error = 1'b0;
        inc_id = 1'b0;
        reset_id = 1'b0;
        case (fsm_state)
            RESET : begin
                reset_id = 1'b1;
                nxt_fsm_state = IDLE;
            end
            IDLE : begin
                if (__en) nxt_fsm_state = STATE_RD_REQ;
            end
            STATE_RD_REQ : begin
                ctrl_if.req = 1'b1;
                if (ctrl_if.rdy) nxt_fsm_state = STATE_RD_WAIT;
            end
            STATE_RD_WAIT : begin
                if (ctrl_if.ack) begin
                    if (ctrl_if.status != db_pkg::STATUS_OK) nxt_fsm_state = ERROR;
                    else if (ctrl_if.get_valid)              nxt_fsm_state = CHECK;
                    else                                     nxt_fsm_state = DONE;
                end
            end
            CHECK : begin
                check = 1'b1;
                if (expired) nxt_fsm_state = NOTIFY;
                else         nxt_fsm_state = DONE;
            end
            NOTIFY : begin
                notify = 1'b1;
                nxt_fsm_state = DONE;
            end
            ERROR : begin
                error = 1'b1;
                nxt_fsm_state = DONE;
            end
            DONE : begin
                inc_id = 1'b1;
                nxt_fsm_state = IDLE;
            end
        endcase
    end

    // -----------------------------
    // ID management
    // -----------------------------
    initial id = 0;
    always @(posedge clk) begin
        if (reset_id)    id <= 0;
        else if (inc_id) id <= id + 1;
    end

    // ----------------------------------
    // Drive state read interface
    // ----------------------------------
    assign ctrl_if.key = id;
    assign ctrl_if.command = db_pkg::COMMAND_GET;
    assign ctrl_if.set_value = '0;
    
    always_ff @(posedge clk) if (ctrl_if.ack) state <= ctrl_if.get_value;

    initial notify_if.evt = 1'b0;
    always @(posedge clk) begin
        if (local_srst) notify_if.evt <= 1'b0;
        else            notify_if.evt <= notify;
    end

    always_ff @(posedge clk) notify_if.msg <= id;

    // ----------------------------------
    // Debug status
    // ----------------------------------
    assign dbg_state = fsm_state;
    assign dbg_scan_done = (fsm_state == DONE) && (id == '1);
    assign dbg_check = check;
    assign dbg_notify = notify;
    assign dbg_error = error;
 
endmodule : state_expiry_fsm
