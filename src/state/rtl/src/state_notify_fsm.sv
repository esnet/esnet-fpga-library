module state_notify_fsm #(
    parameter int ID_WID = 1,
    parameter int STATE_WID = 1,
    parameter int MSG_WID = 1
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    input  logic               en,
    input  logic               init_done,

    // AXI-L control
    axi4l_intf.peripheral      axil_if,

    // State database control interface
    db_ctrl_intf.controller    db_ctrl_if,

    // State check interface
    state_check_intf.source    check_if,

    // Notification feed
    state_event_intf.publisher notify_if
);
    // -----------------------------
    // Imports
    // -----------------------------
    import state_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int NUM_IDS = 2**ID_WID;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [3:0] {
        RESET         = 0,
        SCAN_START    = 1,
        STATE_RD_REQ  = 2,
        STATE_RD_WAIT = 3,
        CHECK_REQ     = 4,
        CHECK_WAIT    = 5,
        NOTIFY        = 6,
        ERROR         = 7,
        SCAN_NEXT     = 8,
        SCAN_DONE     = 9
    } fsm_state_t; 

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(check_if.STATE_WID  , STATE_WID, "check_if.STATE_WID");
        std_pkg::param_check(check_if.MSG_WID    , MSG_WID  , "check_if.MSG_WID");
        std_pkg::param_check(notify_if.ID_WID    , ID_WID   , "notify_if.ID_WID");
        std_pkg::param_check(notify_if.MSG_WID   , MSG_WID  , "notify_if.MSG_WID");
        std_pkg::param_check(db_ctrl_if.KEY_WID  , ID_WID   , "db_ctrl_if.KEY_WID");
        std_pkg::param_check(db_ctrl_if.VALUE_WID, STATE_WID, "db_ctrl_if.STATE_WID");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    logic __srst;
    logic __en;

    fsm_state_t fsm_state;
    fsm_state_t nxt_fsm_state;

    logic [7:0] fsm_state_mon_in;

    logic error;
    logic notify_evt;

    logic [ID_WID-1:0]  id;
    logic               reset_id;
    logic               inc_id;

    logic scan_reset;
    logic scan_start;
    logic scan_done;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf #() axil_if__clk ();

    state_notify_reg_intf reg_if ();

    // -----------------------------
    // Register block
    // -----------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    state_notify_reg_blk i_state_notify_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_size_nxt_v = 1'b1;
    assign reg_if.info_size_nxt = NUM_IDS;

    // Block-level reset control
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    // Block-level enable
    initial __en = 1'b1;
    always @(posedge clk) begin
        if (en && reg_if.control.enable) __en <= 1'b1;
        else                             __en <= 1'b0;
    end

    // Report status
    assign reg_if.status_nxt_v = 1'b1;
    always_ff @(posedge clk) begin
        reg_if.status_nxt.reset_mon <= __srst;
        reg_if.status_nxt.ready_mon <= init_done;
        reg_if.status_nxt.enable_mon <= __en;
    end

    // -----------------------------
    // Expiry state machine
    // -----------------------------
    initial fsm_state = RESET;
    always @(posedge clk) begin
        if (__srst || !init_done) fsm_state <= RESET;
        else                      fsm_state <= nxt_fsm_state;
    end

    always_comb begin
        nxt_fsm_state = fsm_state;
        db_ctrl_if.req = 1'b0;
        check_if.req = 1'b0;
        notify_evt = 1'b0;
        error = 1'b0;
        inc_id = 1'b0;
        reset_id = 1'b0;
        scan_done = 1'b0;
        case (fsm_state)
            RESET : begin
                nxt_fsm_state = SCAN_START;
            end
            SCAN_START : begin
                scan_start = 1'b1;
                reset_id = 1'b1;
                if (__en) nxt_fsm_state = STATE_RD_REQ;
            end
            STATE_RD_REQ : begin
                db_ctrl_if.req = 1'b1;
                if (db_ctrl_if.rdy) nxt_fsm_state = STATE_RD_WAIT;
            end
            STATE_RD_WAIT : begin
                if (db_ctrl_if.ack) begin
                    if (db_ctrl_if.status != db_pkg::STATUS_OK) nxt_fsm_state = ERROR;
                    else                                        nxt_fsm_state = CHECK_REQ;
                end
            end
            CHECK_REQ : begin
                check_if.req = 1'b1;
                nxt_fsm_state = CHECK_WAIT;
            end
            CHECK_WAIT : begin
                if (check_if.ack) begin
                    if (check_if.notify) nxt_fsm_state = NOTIFY;
                    else                 nxt_fsm_state = SCAN_NEXT;
                end
            end
            NOTIFY : begin
                notify_evt = 1'b1;
                nxt_fsm_state = SCAN_NEXT;
            end
            ERROR : begin
                error = 1'b1;
                nxt_fsm_state = SCAN_NEXT;
            end
            SCAN_NEXT : begin
                inc_id = 1'b1;
                if (id == '1)                                                                 nxt_fsm_state = SCAN_DONE;
                else if (reg_if.scan_control.limit_en && id >= reg_if.scan_control.limit_max) nxt_fsm_state = SCAN_DONE;
                else                                                                          nxt_fsm_state = STATE_RD_REQ;                                    
            end
            SCAN_DONE : begin
                scan_done = 1'b1;
                nxt_fsm_state = SCAN_START;
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
    // Scan control
    // ----------------------------------
    initial scan_reset = 1'b0;
    always @(posedge clk) begin
        if (reg_if.scan_control_wr_evt && reg_if.scan_control.reset) scan_reset <= 1'b1;
        else if (fsm_state == SCAN_START)                            scan_reset <= 1'b0;
    end

    // ----------------------------------
    // Drive state database read interface
    // ----------------------------------
    assign db_ctrl_if.key = id;
    assign db_ctrl_if.command = db_pkg::COMMAND_GET;
    assign db_ctrl_if.set_value = '0;
    
    // ----------------------------------
    // Drive state check interface
    // ----------------------------------
    always_ff @(posedge clk) if (db_ctrl_if.ack) check_if.state <= db_ctrl_if.get_value;

    // ----------------------------------
    // Drive notification interface
    // ----------------------------------
    initial notify_if.evt = 1'b0;
    always @(posedge clk) begin
        if (__srst) notify_if.evt <= 1'b0;
        else        notify_if.evt <= notify_evt;
    end

    // Latch notification details
    always_ff @(posedge clk) begin
        if (check_if.notify) begin
            notify_if.msg <= check_if.msg;
            notify_if.id <= id;
        end
    end
 
    // ----------------------------------
    // Debug logic
    // ----------------------------------
    // Signals
    logic [ID_WID-1:0] dbg_cnt_active_last_scan;

    // State
    assign fsm_state_mon_in = {'0, fsm_state};
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state = state_notify_reg_pkg::fld_dbg_status_state_t'(fsm_state_mon_in);

    // Audit valid entries
    always_ff @(posedge clk) begin
        if (scan_done)                            dbg_cnt_active_last_scan <= 0;
        else if (check_if.ack && check_if.active) dbg_cnt_active_last_scan <= dbg_cnt_active_last_scan + 1;
    end

    // Debug function reset
    logic dbg_cnt_reset;
    initial dbg_cnt_reset = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset || reg_if.dbg_control.clear_counts) dbg_cnt_reset <= 1'b1;
        else                                                                 dbg_cnt_reset <= 1'b0;
    end

    // Counter logic (no reset)
    always_comb begin
        // Default is no update
        reg_if.dbg_cnt_active_last_scan_nxt_v = 1'b0;
        // Selective update
        if (scan_done) reg_if.dbg_cnt_active_last_scan_nxt_v = 1'b1;
        // Next counter values
        reg_if.dbg_cnt_active_last_scan_nxt = dbg_cnt_active_last_scan;
    end

    // Counter logic (with reset)
    always_comb begin
        // Default is no update
        reg_if.dbg_cnt_scan_done_nxt_v = 1'b0;
        reg_if.dbg_cnt_notify_nxt_v = 1'b0;
        // Next counter values (default to previous value)
        reg_if.dbg_cnt_scan_done_nxt = reg_if.dbg_cnt_scan_done;
        reg_if.dbg_cnt_notify_nxt = reg_if.dbg_cnt_notify;
        if (dbg_cnt_reset) begin
            // Update on reset/clear
            reg_if.dbg_cnt_scan_done_nxt_v = 1'b1;
            reg_if.dbg_cnt_notify_nxt_v = 1'b1;
            // Clear counts
            reg_if.dbg_cnt_scan_done_nxt = 0;
            reg_if.dbg_cnt_notify_nxt = 0;
        end else begin
            // Selective update
            if (scan_done)  reg_if.dbg_cnt_scan_done_nxt_v = 1'b1;
            if (notify_evt) reg_if.dbg_cnt_notify_nxt_v = 1'b1;
            // Increment-by-one counters
            reg_if.dbg_cnt_scan_done_nxt = reg_if.dbg_cnt_scan_done + 1;
            reg_if.dbg_cnt_notify_nxt = reg_if.dbg_cnt_notify + 1;
        end
    end
        
endmodule : state_notify_fsm
