module state_aging #(
    parameter type ID_T = logic[15:0],
    parameter type TIMER_T = logic[7:0],
    parameter int  NUM_WR_TRANSACTIONS = 4, // Maximum number of database write transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
                                            // When NUM_TRANSACTIONS > 1, write caching is implemented
                                            // with the number of cache entries equal to NUM_WR_TRANSACTIONS
    parameter int  NUM_RD_TRANSACTIONS = 8  // Maximum number of database read transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.

)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    input  logic               en,

    output logic               init_done,

    // Timer clock
    input  logic               tick,

    // Config
    input  TIMER_T             cfg_timeout,

    // Info interface
    db_info_intf.peripheral    info_if,

    // Control interface
    db_ctrl_intf.peripheral    ctrl_if,

    // Status interface
    db_status_intf.peripheral  status_if,

    // Update interface
    state_update_intf.target   update_if,

    // Timeout event notification feed
    std_event_intf.publisher   notify_if,

    // Read/write interfaces (to database/storage)
    output logic               db_init,
    input  logic               db_init_done,
    db_intf.requester          db_wr_if,
    db_intf.requester          db_rd_if,

    // Debug interface
    output logic [3:0]         dbg_state,
    output logic               dbg_scan_done,
    output logic               dbg_check,
    output logic               dbg_notify,
    output logic               dbg_error
);

    // -----------------------------
    // Imports
    // -----------------------------
    import state_pkg::*;

    // ----------------------------------
    // Signals
    // ----------------------------------
    TIMER_T __state;
    logic   __expired;

    logic   state_valid_init_done;
    logic   state_timer_init_done;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf                                      state_valid_info_if__unused ();
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(logic))     state_valid_ctrl_if   (.clk(clk));
    db_status_intf                                    state_valid_status_if (.clk(clk), .srst(srst));
    state_update_intf #(.ID_T(ID_T), .STATE_T(logic)) state_valid_update_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(logic))          state_valid_db_wr_if  (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(logic))          state_valid_db_rd_if  (.clk(clk));

    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))   state_timer_ctrl_if   (.clk(clk));
    db_info_intf                                      state_timer_info_if__unused ();
    state_update_intf #(.ID_T(ID_T), .STATE_T(logic)) state_timer_update_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))        state_timer_db_wr_if  (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))        state_timer_db_rd_if  (.clk(clk));

    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))   __expiry_ctrl_if (.clk(clk));
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))   __ctrl_if        (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_STATE;
    assign info_if.subtype = STATE_TYPE_AGING;
    assign info_if.size = State#(ID_T)::numIDs();

    // ----------------------------------
    // Valid tracking
    // ----------------------------------
    state_valid_core #(
        .ID_T ( ID_T )
    ) i_state_valid_core (
        .clk          ( clk ),
        .srst         ( srst ),
        .init_done    ( state_valid_init_done ),
        .info_if      ( state_valid_info_if__unused ),
        .ctrl_if      ( state_valid_ctrl_if ),
        .status_if    ( status_if ),
        .update_if    ( state_valid_update_if ),
        .db_init      ( db_init ),
        .db_init_done ( db_init_done ),
        .db_wr_if     ( state_valid_db_wr_if ),
        .db_rd_if     ( state_valid_db_rd_if )
    );

    // ----------------------------------
    // Timers
    // ----------------------------------
    state_timer_core #(
        .ID_T ( ID_T ),
        .TIMER_T ( TIMER_T ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_state_timer_core (
        .clk          ( clk ),
        .srst         ( srst ),
        .init_done    ( state_timer_init_done ),
        .info_if      ( state_timer_info_if__unused ),
        .ctrl_if      ( state_timer_ctrl_if ),
        .update_if    ( state_timer_update_if ),
        .db_init      ( ),
        .db_init_done ( db_init_done ),
        .db_wr_if     ( state_timer_db_wr_if ),
        .db_rd_if     ( state_timer_db_rd_if )
    );

    // ----------------------------------
    // Expiry FSM
    // ----------------------------------
    state_expiry_fsm #(
        .ID_T          ( ID_T ),
        .STATE_T       ( TIMER_T )
    ) i_state_expiry_fsm (
        .clk           ( clk ),
        .srst          ( srst ),
        .en            ( en ),
        .init_done     ( init_done ),
        .ctrl_if       ( __expiry_ctrl_if ),
        .state         ( __state ),
        .expired       ( __expired ),
        .notify_if     ( notify_if ),
        .dbg_state     ( dbg_state ),
        .dbg_scan_done ( dbg_scan_done ),
        .dbg_check     ( dbg_check ),
        .dbg_notify    ( dbg_notify ),
        .dbg_error     ( dbg_error )
    );

    // Timeout logic
    always_comb begin
        if (__state >= cfg_timeout) __expired = 1'b1;
        else                        __expired = 1'b0;
    end

    // ----------------------------------
    // Synthesize init_done
    // ----------------------------------
    assign init_done = state_valid_init_done && state_timer_init_done;

    // ----------------------------------
    // Mux between external and internal
    // (i.e. expiry FSM) control interfaces
    // ----------------------------------
    db_ctrl_intf_prio_mux i_db_ctrl_intf_prio_mux (
        .clk                             ( clk ),
        .srst                            ( srst ),
        .ctrl_if_from_controller_hi_prio ( ctrl_if ),
        .ctrl_if_from_controller_lo_prio ( __expiry_ctrl_if ),
        .ctrl_if_to_peripheral           ( __ctrl_if )
    );

    // ----------------------------------
    // Demux control interface to valid
    // and timer state components
    // ----------------------------------
    assign state_timer_ctrl_if.req = __ctrl_if.req;
    assign state_timer_ctrl_if.command = __ctrl_if.command;
    assign state_timer_ctrl_if.key = __ctrl_if.key;
    assign state_timer_ctrl_if.set_value = __ctrl_if.set_value;
    assign __ctrl_if.rdy = state_valid_ctrl_if.rdy && state_timer_ctrl_if.rdy;
    assign __ctrl_if.ack = state_valid_ctrl_if.ack;
    assign __ctrl_if.status = state_valid_ctrl_if.status;
    assign __ctrl_if.get_valid = state_valid_ctrl_if.get_valid;
    assign __ctrl_if.get_value = state_timer_ctrl_if.get_value;

    // ----------------------------------
    // Database interface
    // ----------------------------------
    // Mux db write interface
    assign db_wr_if.req = state_valid_db_wr_if.req;
    assign db_wr_if.key = state_valid_db_wr_if.key;
    assign db_wr_if.valid = state_valid_db_wr_if.valid;
    assign db_wr_if.value = state_timer_db_wr_if.value;
    
    assign state_valid_db_wr_if.rdy = db_wr_if.rdy;
    assign state_valid_db_wr_if.ack = db_wr_if.ack;
    assign state_valid_db_wr_if.error = db_wr_if.error;

    assign state_timer_db_wr_if.rdy = db_wr_if.rdy;
    assign state_timer_db_wr_if.ack = db_wr_if.ack;
    assign state_timer_db_wr_if.error = db_wr_if.error;
    
    // Mux/demux db read interface
    assign db_rd_if.req = state_valid_db_rd_if.req;
    assign db_rd_if.key = state_valid_db_rd_if.key;

    assign state_valid_db_rd_if.rdy = db_rd_if.rdy;
    assign state_valid_db_rd_if.ack = db_rd_if.ack;
    assign state_valid_db_rd_if.error = db_rd_if.error;
    assign state_valid_db_rd_if.valid = db_rd_if.valid;
    assign state_valid_db_rd_if.value = '0; // Unused

    assign state_timer_db_rd_if.rdy = db_rd_if.rdy;
    assign state_timer_db_rd_if.ack = db_rd_if.ack;
    assign state_timer_db_rd_if.error = db_rd_if.error;
    assign state_valid_db_rd_if.valid = 1'b0; // Unused
    assign state_valid_db_rd_if.value = db_rd_if.value;
 
endmodule : state_aging
