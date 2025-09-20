module sar_reassembly_state_check #(
    parameter int BUF_ID_WID = 1,
    parameter int OFFSET_WID = 1,
    parameter int TIMER_WID = 1 // Width (in bits) of frame expiry timer
) (
    // Clock/reset
    input logic                 clk,
    input logic                 srst,

    // AXI-L control
    axi4l_intf.peripheral       axil_if,

    // Check interface
    state_check_intf.target     check_if,

    // Timers
    input logic [TIMER_WID-1:0] timer
);
    // -----------------------------
    // Imports
    // -----------------------------
    import sar_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    typedef struct packed {
        logic [BUF_ID_WID-1:0] buf_id;
        logic [OFFSET_WID-1:0] offset_start;
        logic [OFFSET_WID-1:0] offset_end;
    } notify_ctxt_t;

    typedef struct packed {
        reassembly_notify_type_t _type;
        notify_ctxt_t            ctxt;
    } notify_msg_t;
    localparam NOTIFY_MSG_WID = $bits(notify_msg_t);

    typedef struct packed {
        logic                  valid;
        logic [BUF_ID_WID-1:0] buf_id;
        logic [OFFSET_WID-1:0] offset_start;
        logic [OFFSET_WID-1:0] offset_end;
        logic [TIMER_WID-1:0]  timer;
        logic                  last;
    } state_t;
    localparam int STATE_WID = $bits(state_t);

    initial begin
        std_pkg::param_check(NOTIFY_MSG_WID, check_if.MSG_WID,   "check_if.MSG_WID");
        std_pkg::param_check(STATE_WID,      check_if.STATE_WID, "check_if.STATE_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [1:0] {
        RESET   = 0,
        IDLE    = 1,
        PROCESS = 2,
        CHECK   = 3
    } fsm_state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic __srst;

    fsm_state_t fsm_state;
    fsm_state_t nxt_fsm_state;

    state_t __state;

    logic buffer_done;

    logic [TIMER_WID-1:0] age;
    logic                 timeout;

    notify_msg_t check_if_msg;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf #() axil_if__clk ();

    sar_reassembly_state_check_reg_intf reg_if ();

    // -----------------------------
    // AXI-L control
    // -----------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    sar_reassembly_state_check_reg_blk i_sar_reassembly_state_check_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    // Block-level reset control
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    // Report status
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset_mon = __srst;
    assign reg_if.status_nxt.enable_mon = 1'b1;
    assign reg_if.status_nxt.ready_mon = !__srst;

    // -----------------------------
    // Logic
    // -----------------------------
    initial fsm_state = RESET;
    always @(posedge clk) begin
        if (__srst) fsm_state <= RESET;
        else        fsm_state <= nxt_fsm_state;
    end

    always_comb begin
        check_if.ack = 1'b0;
        check_if.active = 1'b0;
        check_if.notify = 1'b0;
        check_if_msg._type = REASSEMBLY_NOTIFY_EXPIRED;
        nxt_fsm_state = fsm_state;
        case (fsm_state)
            RESET : begin
                nxt_fsm_state = IDLE;
            end
            IDLE : begin
                if (check_if.req) nxt_fsm_state = PROCESS;
            end
            PROCESS : begin
                nxt_fsm_state = CHECK;
            end
            CHECK : begin
                check_if.ack = 1'b1;
                if (__state.valid) begin
                    check_if.active = 1'b1;
                    if (buffer_done) begin
                        check_if.notify = 1'b1;
                        check_if_msg._type = REASSEMBLY_NOTIFY_DONE;
                    end else if (timeout) begin
                        check_if.notify = 1'b1;
                        check_if_msg._type = REASSEMBLY_NOTIFY_EXPIRED;
                    end
                end
                nxt_fsm_state = IDLE;
            end
        endcase
    end

    assign check_if_msg.ctxt.buf_id = __state.buf_id;
    assign check_if_msg.ctxt.offset_start = __state.offset_start;
    assign check_if_msg.ctxt.offset_end = __state.offset_end;
    assign check_if.msg = check_if_msg;

    // Latch state
    always_ff @(posedge clk) if (check_if.req) __state <= check_if.state;

    always_ff @(posedge clk) begin
        age <= timer - __state.timer;
    end
    
    assign buffer_done = __state.offset_start == 0 && __state.last;
    assign timeout = reg_if.cfg_timeout.enable ? (age >= reg_if.cfg_timeout.value[TIMER_WID-1:0]) : 1'b0;

    // -----------------------------
    // Debug reporting
    // -----------------------------
    // (Local) signals
    logic [7:0] fsm_state_mon_in;
    logic dbg_cnt_reset;

    // State
    assign fsm_state_mon_in = {'0, fsm_state};
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state = sar_reassembly_state_check_reg_pkg::fld_dbg_status_state_t'(fsm_state_mon_in);

    // Counters
    // -- function-level reset
    initial dbg_cnt_reset = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset || reg_if.dbg_control.clear_counts) dbg_cnt_reset <= 1'b1;
        else                                                                 dbg_cnt_reset <= 1'b0;
    end
    // -- counter update logic
    always_comb begin
        // Default is no update
        reg_if.dbg_cnt_buffer_done_nxt_v = 1'b0;
        reg_if.dbg_cnt_fragment_expired_nxt_v = 1'b0;
        // Next counter values (default to previous values)
        reg_if.dbg_cnt_buffer_done_nxt = reg_if.dbg_cnt_buffer_done;
        reg_if.dbg_cnt_fragment_expired_nxt = reg_if.dbg_cnt_fragment_expired;
        if (dbg_cnt_reset) begin
            // Update on reset/clear
            reg_if.dbg_cnt_buffer_done_nxt_v = 1'b1;
            reg_if.dbg_cnt_fragment_expired_nxt_v = 1'b1;
            // Clear counts
            reg_if.dbg_cnt_buffer_done_nxt = 0;
            reg_if.dbg_cnt_fragment_expired_nxt = 0;
        end else begin
            // Selective update
            if (check_if.notify) begin
                case (check_if_msg._type)
                    REASSEMBLY_NOTIFY_DONE : reg_if.dbg_cnt_buffer_done_nxt_v = 1'b1;
                    default                : reg_if.dbg_cnt_fragment_expired_nxt_v = 1'b1;
                endcase
            end
            // Increment-by-one counters
            reg_if.dbg_cnt_buffer_done_nxt = reg_if.dbg_cnt_buffer_done + 1;
            reg_if.dbg_cnt_fragment_expired_nxt = reg_if.dbg_cnt_fragment_expired + 1;
        end
    end

endmodule : sar_reassembly_state_check
