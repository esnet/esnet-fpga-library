module state_core
    import state_pkg::*;
#(
    parameter int ID_WID = 1,
    parameter vector_t SPEC = DEFAULT_STATE_VECTOR,
    parameter int NOTIFY_MSG_WID = EXPIRY_MSG_WID,
    parameter int  NUM_WR_TRANSACTIONS = 4, // Maximum number of database write transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter int  NUM_RD_TRANSACTIONS = 8, // Maximum number of database read transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter bit  CACHE_EN = 1'b1          // Enable caching to ensure consistency of underlying state
                                            // data for cases where multiple transactions (closely spaced
                                            // in time) target the same state ID; in general, caching should
                                            // be enabled, but it can be disabled to achieve a less complex
                                            // implementation for applications insensitive to this type of inconsistency
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    // Control/status
    input  logic               en,
    output logic               init_done,

    // AXI-L control interface
    axi4l_intf.peripheral      axil_if,

    // Update interface (from datapath)
    state_intf.target          update_if,

    // Read/update interface (from control plane)
    state_intf.target          ctrl_if,

    // Check interface
    state_check_intf.source    check_if,

    // Notification interface
    state_event_intf.publisher notify_if,

    // Read/write interfaces (to database/storage)
    output logic               db_init,
    input  logic               db_init_done,
    db_intf.requester          db_wr_if,
    db_intf.requester          db_rd_if
);
    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int STATE_WID = getStateVectorSize(SPEC);
    localparam int UPDATE_WID = getUpdateVectorSize(SPEC);

    localparam int NUM_IDS = 2**ID_WID;

    // -------------------------------------------------
    // Parameter checking
    // -------------------------------------------------
    initial begin
        std_pkg::param_check(update_if.ID_WID    , ID_WID        , "update_if.ID_WID");
        std_pkg::param_check(update_if.STATE_WID , STATE_WID     , "update_if.STATE_WID");
        std_pkg::param_check(update_if.UPDATE_WID, UPDATE_WID    , "update_if.UPDATE_WID");
        std_pkg::param_check(ctrl_if.ID_WID      , ID_WID        , "ctrl_if.ID_WID");
        std_pkg::param_check(ctrl_if.STATE_WID   , STATE_WID     , "ctrl_if.STATE_WID");
        std_pkg::param_check(ctrl_if.UPDATE_WID  , UPDATE_WID    , "ctrl_if.UPDATE_WID");
        std_pkg::param_check(check_if.STATE_WID  , STATE_WID     , "check_if.STATE_WID");
        std_pkg::param_check(check_if.MSG_WID    , NOTIFY_MSG_WID, "check_if.MSG_WID");
        std_pkg::param_check(notify_if.ID_WID    , ID_WID        , "notify_if.ID_WID");
        std_pkg::param_check(notify_if.MSG_WID   , NOTIFY_MSG_WID, "notify_if.MSG_WID");
        std_pkg::param_check(db_wr_if.KEY_WID    , ID_WID        , "db_wr_if.KEY_WID");
        std_pkg::param_check(db_wr_if.VALUE_WID  , STATE_WID     , "db_wr_if.VALUE_WID");
        std_pkg::param_check(db_rd_if.KEY_WID    , ID_WID        , "db_rd_if.KEY_WID");
        std_pkg::param_check(db_rd_if.VALUE_WID  , STATE_WID     , "db_rd_if.VALUE_WID");
    end

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic __srst;
    logic __en;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    axi4l_intf axil_if__regs      ();
    axi4l_intf axil_if__regs__clk ();
    axi4l_intf axil_if__db        ();
    axi4l_intf axil_if__notify    ();

    state_reg_intf reg_if ();

    db_info_intf info_if ();
    db_status_intf status_if (.clk(clk), .srst(srst));

    db_ctrl_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) db_ctrl_if__hw (.clk);
    db_ctrl_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) db_ctrl_if__sw (.clk);
    db_ctrl_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) db_ctrl_if     (.clk);

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    state_decoder i_state_decoder (
        .axil_if              ( axil_if ),
        .state_axil_if        ( axil_if__regs ),
        .state_db_axil_if     ( axil_if__db ),
        .state_notify_axil_if ( axil_if__notify )
    );

    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if__regs ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__regs__clk )
    );

    state_reg_blk i_state_reg_blk (
        .axil_if    ( axil_if__regs__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_size_nxt_v = 1'b1;
    assign reg_if.info_size_nxt = NUM_IDS;

    assign reg_if.info_num_elements_nxt_v = 1'b1;
    assign reg_if.info_num_elements_nxt = SPEC.NUM_ELEMENTS;

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

    // -------------------------------------------------
    // State database S/W access
    // - allows reading/(and writing) flow state via
    //   the regmap, primarily for debug purposes
    // -------------------------------------------------
    db_axil_ctrl i_db_axil_ctrl (
        .clk         ( clk ),
        .srst        ( __srst ),
        .init_done   ( init_done ),
        .axil_if     ( axil_if__db ),
        .ctrl_reset  ( ),
        .ctrl_en     ( ),
        .reset_mon   ( __srst ),
        .en_mon      ( __en ),
        .ready_mon   ( init_done ),
        .info_if     ( info_if ),
        .ctrl_if     ( db_ctrl_if__sw ),
        .status_if   ( status_if )
    );
    assign status_if.fill = NUM_IDS;
    assign status_if.empty = 1'b0;
    assign status_if.full = 1'b1;
    assign status_if.evt_activate = 1'b0;
    assign status_if.evt_deactivate = 1'b0;

    // -------------------------------------------------
    // State vector core
    // - per-element update logic,
    // - muxing between datapath and
    //   control updates
    // -------------------------------------------------
    state_vector_core #(
        .ID_WID ( ID_WID ),
        .SPEC ( SPEC ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .CACHE_EN ( CACHE_EN )
    ) i_state_vector  (
        .clk          ( clk ),
        .srst         ( __srst ),
        .en           ( __en ),
        .init_done    ( init_done ),
        .info_if      ( info_if ),
        .update_if    ( update_if ),
        .ctrl_if      ( ctrl_if ),
        .db_ctrl_if   ( db_ctrl_if ),
        .db_init      ( db_init ),
        .db_init_done ( db_init_done ),
        .db_wr_if     ( db_wr_if ),
        .db_rd_if     ( db_rd_if )
    );
    
    // -------------------------------------------------
    // Database control mux
    // -------------------------------------------------
    // Mux between s/w (regmap) and h/w (notify fsm) control interfaces
    db_ctrl_intf_prio_mux i_db_ctrl_prio_mux (
        .clk                     ( clk ),
        .srst                    ( __srst ),
        .from_controller_hi_prio ( db_ctrl_if__hw ),
        .from_controller_lo_prio ( db_ctrl_if__sw ),
        .to_peripheral           ( db_ctrl_if )
    );

    // -----------------------------
    // Notification FSM
    // -----------------------------
    state_notify_fsm #(
        .ID_WID    ( ID_WID ),
        .STATE_WID ( STATE_WID ),
        .MSG_WID   ( NOTIFY_MSG_WID )
    ) i_state_notify_fsm (
        .clk        ( clk ),
        .srst       ( __srst ),
        .en         ( __en ),
        .init_done  ( init_done ),
        .axil_if    ( axil_if__notify ),
        .db_ctrl_if ( db_ctrl_if__hw ),
        .check_if   ( check_if ),
        .notify_if  ( notify_if )
    );

endmodule : state_core
