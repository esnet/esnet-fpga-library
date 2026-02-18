module htable_fast_update_core #(
    parameter int  KEY_WID = 1,
    parameter int  VALUE_WID = 1,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  UPDATE_BURST_SIZE = 8

)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              en,

    output logic              init_done,

    // AXI-L interface
    axi4l_intf.peripheral     axil_if,

    // Lookup/update interfaces (from application)
    db_intf.responder         lookup_if,
    db_intf.responder         update_if, // Supports both insertion/deletions
                                         // (indicated by setting valid to 1/0 respectively)

    // Table interface
    input   logic             tbl_init_done,
    db_ctrl_intf.controller   tbl_ctrl_if,

    db_intf.requester         tbl_lookup_if

);

    // ----------------------------------
    // Imports
    // ----------------------------------
    import db_pkg::*;
    import htable_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    typedef struct packed {logic ins_del_n; logic [VALUE_WID-1:0] value;} update_entry_t;
    localparam int UPDATE_ENTRY_WID = $bits(update_entry_t);

    localparam int TIMER_WID = $clog2(NUM_RD_TRANSACTIONS + 1);

    // Check
    initial begin
        std_pkg::param_check(lookup_if.KEY_WID,     KEY_WID,   "lookup_if.KEY_WID");
        std_pkg::param_check(lookup_if.VALUE_WID,   VALUE_WID, "lookup_if.VALUE_WID");
        std_pkg::param_check(update_if.KEY_WID,     KEY_WID,   "update_if.KEY_WID");
        std_pkg::param_check(update_if.VALUE_WID,   VALUE_WID, "update_if.VALUE_WID");
        std_pkg::param_check(tbl_ctrl_if.KEY_WID,   KEY_WID,   "tbl_ctrl_if.KEY_WID");
        std_pkg::param_check(tbl_ctrl_if.VALUE_WID, VALUE_WID, "tbl_ctrl_if.VALUE_WID");
    end

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef enum logic [3:0] {
        RESET              = 0,
        IDLE               = 1,
        GET_NEXT           = 2,
        GET_NEXT_PENDING   = 3,
        GET_NEXT_DONE      = 4,
        TBL_INSERT         = 5,
        TBL_DELETE         = 6,
        TBL_UPDATE_PENDING = 7,
        TBL_UPDATE_DONE    = 8,
        TBL_UPDATE_ERROR   = 9,
        STASH_POP_WAIT     = 10,
        STASH_POP          = 11,
        STASH_POP_PENDING  = 12,
        ERROR              = 13
    } state_t;

    typedef struct packed {
        logic [KEY_WID-1:0] key;
    } req_ctxt_t;

    typedef struct packed {
        logic                 valid;
        logic                 error;
        logic [VALUE_WID-1:0] value;
    } resp_ctxt_t;

    typedef enum logic {
        INSERT = 0,
        DELETE = 1
    } command_ctxt_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic __srst;
    logic __en;

    logic [7:0] state_mon;

    state_t state;
    state_t nxt_state;

    logic          stash_init_done;
    update_entry_t update_entry;

    req_ctxt_t  tbl_req_ctxt_in;
    req_ctxt_t  tbl_req_ctxt_out;
    resp_ctxt_t tbl_resp_ctxt_in;
    resp_ctxt_t tbl_resp_ctxt_out_d[2];
    resp_ctxt_t tbl_resp_ctxt_out;

    update_entry_t stash_lookup_resp;

    logic [KEY_WID-1:0]   ctrl_key;
    logic [VALUE_WID-1:0] ctrl_value;

    logic                 timer_reset;
    logic                 timer_inc;
    logic [TIMER_WID-1:0] timer;

    // Stash control
    logic     stash_req;
    command_t stash_command;

    update_entry_t stash_ctrl_if_get_entry;

    // Table control
    logic     tbl_req;
    command_t tbl_command;

    // Command context
    command_ctxt_t __command;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf stash_info_if__unused ();
    db_status_intf stash_status_if (.clk, .srst);
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(UPDATE_ENTRY_WID)) stash_ctrl_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(UPDATE_ENTRY_WID)) stash_lookup_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(UPDATE_ENTRY_WID)) stash_update_if (.clk);

    axi4l_intf #() axil_if__clk ();
    htable_fast_update_reg_intf reg_if ();

    // ----------------------------------
    // AXI-L control
    // ----------------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    htable_fast_update_reg_blk i_htable_fast_update_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_nxt.burst_size = UPDATE_BURST_SIZE[7:0];
    assign reg_if.info_nxt.key_width = KEY_WID;
    assign reg_if.info_nxt.value_width = VALUE_WID;
    assign reg_if.info_nxt_v = 1'b1;

    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset_mon = __srst;
    assign reg_if.status_nxt.enable_mon = __en;
    assign reg_if.status_nxt.ready_mon = init_done;

    assign state_mon = {4'b0, state};
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state = htable_fast_update_reg_pkg::fld_dbg_status_state_t'(state_mon);

    // Block reset
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    // Block enable
    initial __en = 1'b0;
    always @(posedge clk) begin
        if (en && reg_if.control.enable) __en <= 1'b1;
        else                             __en <= 1'b0;
    end

    // ----------------------------------
    // Init done
    // ----------------------------------
    assign init_done = tbl_init_done && stash_init_done;

    // ----------------------------------
    // Drive table lookup interface
    // ----------------------------------
    assign tbl_lookup_if.req = lookup_if.req;
    assign tbl_lookup_if.key = lookup_if.key;
    assign tbl_lookup_if.next = 1'b0;

    assign lookup_if.rdy = tbl_lookup_if.rdy;

    // Store lookup request context
    assign tbl_req_ctxt_in.key = tbl_lookup_if.key;

    fifo_ctxt    #(
        .DATA_WID ( $bits(req_ctxt_t) ),
        .DEPTH    ( NUM_RD_TRANSACTIONS ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__tbl_lookup_req_ctxt (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr      ( tbl_lookup_if.req && tbl_lookup_if.rdy ),
        .wr_rdy  ( ),
        .wr_data ( tbl_req_ctxt_in ),
        .rd      ( tbl_lookup_if.ack ),
        .rd_vld  ( ),
        .rd_data ( tbl_req_ctxt_out ),
        .oflow   ( ),
        .uflow   ( )
    );

    // Store lookup response context
    assign tbl_resp_ctxt_in.valid = tbl_lookup_if.valid;
    assign tbl_resp_ctxt_in.error = tbl_lookup_if.error;
    assign tbl_resp_ctxt_in.value = tbl_lookup_if.value;

    always_ff @(posedge clk) begin
        tbl_resp_ctxt_out_d[0] <= tbl_resp_ctxt_in;
        tbl_resp_ctxt_out_d[1] <= tbl_resp_ctxt_out_d[0];
    end
    assign tbl_resp_ctxt_out = tbl_resp_ctxt_out_d[1];

    // ----------------------------------
    // Update stash
    // ----------------------------------
    db_stash_fifo #(
        .SIZE      ( UPDATE_BURST_SIZE )
    ) i_db_stash_fifo (
        .clk       ( clk ),
        .srst      ( __srst ),
        .init_done ( stash_init_done ),
        .info_if   ( stash_info_if__unused ),
        .ctrl_if   ( stash_ctrl_if ),
        .status_if ( stash_status_if ),
        .app_wr_if ( stash_update_if ),
        .app_rd_if ( stash_lookup_if )
    );

    // Drive stash lookup (follows table lookup)
    assign stash_lookup_if.req = tbl_lookup_if.ack;
    assign stash_lookup_if.key = tbl_req_ctxt_out.key;
    assign stash_lookup_if.next = 1'b0;

    assign stash_lookup_resp = stash_lookup_if.value;

    assign stash_update_if.req = update_if.req && !stash_status_if.full;
    assign stash_update_if.key = update_if.key;
    assign stash_update_if.next = 1'b0;
    assign stash_update_if.valid = 1'b1;
    assign update_entry.ins_del_n = update_if.valid;
    assign update_entry.value = update_if.value;
    assign stash_update_if.value = update_entry;

    assign update_if.rdy = stash_update_if.rdy && !stash_status_if.full;
    assign update_if.ack = stash_update_if.ack;
    assign update_if.error = stash_update_if.error;
    assign update_if.next_key = '0;

    // ----------------------------------
    // Combine table/stash lookup results
    // ----------------------------------
    assign lookup_if.ack = stash_lookup_if.ack;

    always_comb begin
        lookup_if.valid = 1'b0;
        lookup_if.value = '0;
        lookup_if.error = stash_lookup_if.error;
        if (stash_lookup_if.valid) begin
            if (stash_lookup_resp.ins_del_n) begin
                lookup_if.valid = 1'b1;
                lookup_if.value = stash_lookup_resp.value;
            end else begin
                lookup_if.valid = 1'b0;
            end
        end else begin
            lookup_if.valid = tbl_resp_ctxt_out.valid;
            lookup_if.error = tbl_resp_ctxt_out.error;
            lookup_if.value = tbl_resp_ctxt_out.value;
        end
    end
    assign lookup_if.next_key = '0;

    // ----------------------------------
    // Update stash controller
    // ----------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (__srst) state <= RESET;
        else        state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        stash_req = 1'b0;
        stash_command = COMMAND_NOP;
        tbl_req = 1'b0;
        tbl_command = COMMAND_NOP;
        timer_reset = 1'b0;
        timer_inc = 1'b0;
        case (state)
            RESET : begin
                if (init_done) nxt_state = IDLE;
            end
            IDLE : begin
                if (__en) begin
                    if (stash_status_if.fill > 0) nxt_state = GET_NEXT;
                end
            end
            GET_NEXT : begin
                stash_req = 1'b1;
                stash_command = COMMAND_GET_NEXT;
                if (stash_ctrl_if.rdy) nxt_state = GET_NEXT_PENDING;
            end
            GET_NEXT_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK)     nxt_state = ERROR;
                    else if (stash_ctrl_if.get_valid) begin
                        if (stash_ctrl_if_get_entry.ins_del_n) nxt_state = TBL_INSERT;
                        else                                   nxt_state = TBL_DELETE;
                    end else                                   nxt_state = IDLE;
                end
            end
            TBL_INSERT : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_SET;
                if (tbl_ctrl_if.rdy) nxt_state = TBL_UPDATE_PENDING;
            end
            TBL_DELETE : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_UNSET;
                if (tbl_ctrl_if.rdy) nxt_state = TBL_UPDATE_PENDING;
            end
            TBL_UPDATE_PENDING : begin
                if (tbl_ctrl_if.ack) begin
                    if (tbl_ctrl_if.status != STATUS_OK) nxt_state = TBL_UPDATE_ERROR;
                    else                                 nxt_state = TBL_UPDATE_DONE;
                end
            end
            TBL_UPDATE_DONE : begin
                timer_reset = 1'b1;
                nxt_state = STASH_POP_WAIT;
            end
            TBL_UPDATE_ERROR : begin
                nxt_state = STASH_POP;
            end
            STASH_POP_WAIT : begin
                timer_inc = 1'b1;
                // Ensure make before break; leave entry in stash for
                // enough time to ensure that any lookup transactions in
                // flight are guaranteed to see the entry in either the
                // hash table or the stash
                if (timer == NUM_RD_TRANSACTIONS) nxt_state = STASH_POP;
            end
            STASH_POP : begin
                stash_req = 1'b1;
                stash_command = COMMAND_UNSET_NEXT;
                if (stash_ctrl_if.rdy) nxt_state = STASH_POP_PENDING;
            end
            STASH_POP_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else if (stash_ctrl_if.get_valid)      nxt_state = IDLE;
                    else                                   nxt_state = ERROR;
                end
            end
            ERROR : begin
                nxt_state = IDLE;
            end
            default : begin
                nxt_state = ERROR;
            end
        endcase
    end

    // Wait timer
    always_ff @(posedge clk) begin
        if (timer_reset)    timer <= '0;
        else if (timer_inc) timer <= timer + 1;
    end

    // Latch update data
    always_ff @(posedge clk) begin
        if (stash_ctrl_if.ack) begin
            ctrl_key   <= stash_ctrl_if.get_key;
            ctrl_value <= stash_ctrl_if_get_entry.value;
        end
    end

    // Latch current command context
    always_ff @(posedge clk) begin
        if (state == TBL_INSERT)      __command <= INSERT;
        else if (state == TBL_DELETE) __command <= DELETE;
    end

    // ----------------------------------
    // Drive stash control interface
    // ----------------------------------
    assign stash_ctrl_if.req = stash_req;
    assign stash_ctrl_if.command = stash_command;
    assign stash_ctrl_if.key = ctrl_key;
    assign stash_ctrl_if.set_value = '0;
    assign stash_ctrl_if_get_entry = stash_ctrl_if.get_value;

    // ----------------------------------
    // Drive table control interface
    // ----------------------------------
    assign tbl_ctrl_if.req = tbl_req;
    assign tbl_ctrl_if.command = tbl_command;
    assign tbl_ctrl_if.key = ctrl_key;
    assign tbl_ctrl_if.set_value = ctrl_value;

    // -----------------------------
    // Counters
    // -----------------------------
    logic __update;
    logic __insert_ok;
    logic __insert_fail;
    logic __delete_ok;
    logic __delete_fail;

    logic cnt_latch;
    logic cnt_clear;

    logic [63:0] cnt_update;
    logic [63:0] cnt_insert_ok;
    logic [63:0] cnt_insert_fail;
    logic [63:0] cnt_delete_ok;
    logic [63:0] cnt_delete_fail;

    // Synthesize (and buffer) counter update signals
    always_ff @(posedge clk) begin
        __update      <= 1'b0;
        __insert_ok   <= 1'b0;
        __insert_fail <= 1'b0;
        __delete_ok   <= 1'b0;
        __delete_fail <= 1'b0;
        if (update_if.req && update_if.rdy) __update <= 1'b1;
        if (state == TBL_UPDATE_DONE) begin
            if (__command == INSERT)      __insert_ok <= 1'b1;
            else if (__command == DELETE) __delete_ok <= 1'b1;
        end else if (state == TBL_UPDATE_ERROR) begin
            if (__command == INSERT)      __insert_fail <= 1'b1;
            else if (__command == DELETE) __delete_fail <= 1'b1;
        end
    end

    // Buffer latch/clear signals from regmap
    initial begin
        cnt_clear = 1'b0;
    end
    always @(posedge clk) begin
        if (__srst || (reg_if.cnt_control_wr_evt && reg_if.cnt_control._clear)) cnt_clear <= 1'b1;
        else cnt_clear <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if (reg_if.cnt_control_wr_evt) cnt_latch <= 1'b1;
        else                           cnt_latch <= 1'b0;
    end

    // Update
    always_ff @(posedge clk) begin
        if (cnt_clear)     cnt_update <= 0;
        else if (__update) cnt_update <= cnt_update + 1;
    end
    // Insert OK
    always_ff @(posedge clk) begin
        if (cnt_clear)        cnt_insert_ok <= 0;
        else if (__insert_ok) cnt_insert_ok <= cnt_insert_ok + 1;
    end
    // Insert FAIL
    always_ff @(posedge clk) begin
        if (cnt_clear)          cnt_insert_fail <= 0;
        else if (__insert_fail) cnt_insert_fail <= cnt_insert_fail + 1;
    end
    // Delete OK
    always_ff @(posedge clk) begin
        if (cnt_clear)        cnt_delete_ok <= 0;
        else if (__delete_ok) cnt_delete_ok <= cnt_delete_ok + 1;
    end
    // Delete FAIL
    always_ff @(posedge clk) begin
        if (cnt_clear)          cnt_delete_fail <= 0;
        else if (__delete_fail) cnt_delete_fail <= cnt_delete_fail + 1;
    end

    assign reg_if.cnt_update_upper_nxt_v      = cnt_latch;
    assign reg_if.cnt_update_lower_nxt_v      = cnt_latch;
    assign reg_if.cnt_insert_ok_upper_nxt_v   = cnt_latch;
    assign reg_if.cnt_insert_ok_lower_nxt_v   = cnt_latch;
    assign reg_if.cnt_insert_fail_upper_nxt_v = cnt_latch;
    assign reg_if.cnt_insert_fail_lower_nxt_v = cnt_latch;
    assign reg_if.cnt_delete_ok_upper_nxt_v   = cnt_latch;
    assign reg_if.cnt_delete_ok_lower_nxt_v   = cnt_latch;
    assign reg_if.cnt_delete_fail_upper_nxt_v = cnt_latch;
    assign reg_if.cnt_delete_fail_lower_nxt_v = cnt_latch;
    assign reg_if.cnt_active_nxt_v = cnt_latch;
    assign reg_if.dbg_cnt_active_nxt_v = 1'b1;

    assign {reg_if.cnt_update_upper_nxt,      reg_if.cnt_update_lower_nxt}      = cnt_update;
    assign {reg_if.cnt_insert_ok_upper_nxt,   reg_if.cnt_insert_ok_lower_nxt}   = cnt_insert_ok;
    assign {reg_if.cnt_insert_fail_upper_nxt, reg_if.cnt_insert_fail_lower_nxt} = cnt_insert_fail;
    assign {reg_if.cnt_delete_ok_upper_nxt,   reg_if.cnt_delete_ok_lower_nxt}   = cnt_delete_ok;
    assign {reg_if.cnt_delete_fail_upper_nxt, reg_if.cnt_delete_fail_lower_nxt} = cnt_delete_fail;
    assign reg_if.cnt_active_nxt = stash_status_if.fill;
    assign reg_if.dbg_cnt_active_nxt = stash_status_if.fill;

endmodule : htable_fast_update_core
