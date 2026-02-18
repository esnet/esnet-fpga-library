module state_vector_core
    import state_pkg::*;
#(
    parameter int ID_WID = 1,
    parameter vector_t SPEC = DEFAULT_STATE_VECTOR,
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
    input  logic              clk,
    input  logic              srst,

    // Control/status
    input  logic              en,
    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Update interface (from datapath)
    state_intf.target         update_if,

    // Read/update interface (from control plane)
    state_intf.target         ctrl_if,

    // Read/write interfaces (to database/storage)
    db_ctrl_intf.peripheral   db_ctrl_if,
    output logic              db_init,
    input  logic              db_init_done,
    db_intf.requester         db_wr_if,
    db_intf.requester         db_rd_if
);
    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int STATE_WID = getStateVectorSize(SPEC);
    localparam int UPDATE_WID = getUpdateVectorSize(SPEC);

    // ----------------------------------
    // Parameter checking
    // ----------------------------------
    initial begin
        std_pkg::param_check(update_if.ID_WID    , ID_WID    , "update_if.ID_WID");
        std_pkg::param_check(update_if.STATE_WID , STATE_WID , "update_if.STATE_WID");
        std_pkg::param_check(update_if.UPDATE_WID, UPDATE_WID, "update_if.UPDATE_WID");
        std_pkg::param_check(ctrl_if.ID_WID      , ID_WID    , "ctrl_if.ID_WID");
        std_pkg::param_check(ctrl_if.STATE_WID   , STATE_WID , "ctrl_if.STATE_WID");
        std_pkg::param_check(ctrl_if.UPDATE_WID  , UPDATE_WID, "ctrl_if.UPDATE_WID");
        std_pkg::param_check(db_ctrl_if.KEY_WID  , ID_WID    , "db_ctrl_if.KEY_WID");
        std_pkg::param_check(db_ctrl_if.VALUE_WID, STATE_WID , "db_ctrl_if.VALUE_WID");
        std_pkg::param_check(db_wr_if.KEY_WID    , ID_WID    , "db_wr_if.KEY_WID");
        std_pkg::param_check(db_wr_if.VALUE_WID  , STATE_WID , "db_wr_if.VALUE_WID");
        std_pkg::param_check(db_rd_if.KEY_WID    , ID_WID    , "db_rd_if.KEY_WID");
        std_pkg::param_check(db_rd_if.VALUE_WID  , STATE_WID , "db_rd_if.VALUE_WID");
    end

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        logic [ID_WID-1:0]     id;
        update_ctxt_t          ctxt;
        logic [UPDATE_WID-1:0] update;
        logic                  init;
        logic                  back_to_back;
    } rmw_ctxt_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic [STATE_WID-1:0] prev_state;
    logic [STATE_WID-1:0] next_state;
    logic [STATE_WID-1:0] return_state;

    rmw_ctxt_t rmw_ctxt_in;
    rmw_ctxt_t rmw_ctxt_out;

    logic [ID_WID-1:0]    last_update_id;
    logic                 last_next_state_valid;
    logic [STATE_WID-1:0] last_next_state;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) __app_wr_if (.clk);
    db_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) __app_rd_if (.clk);

    state_intf #(.ID_WID(ID_WID), .STATE_WID(STATE_WID), .UPDATE_WID(UPDATE_WID)) __update_if (.clk);

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_STATE;
    assign info_if.subtype = BLOCK_TYPE_VECTOR;
    assign info_if.size = 2**ID_WID;

    // ----------------------------------
    // (Generic) database core
    // ----------------------------------
    db_core #(
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .DB_CACHE_EN         ( 0 ), // No need to cache the database accesses since under normal
                                    // operation all state modifications come from the app interface.
                                    // NOTE: it is possible to modify state results from the database
                                    //       control interface, but this is expected to be used for
                                    //       init or debug purposes only.
        .APP_CACHE_EN        ( CACHE_EN )
    ) i_db_core              (
        .clk                 ( clk ),
        .srst                ( srst ),
        .init_done           ( init_done ),
        .ctrl_if             ( db_ctrl_if ),
        .app_wr_if           ( __app_wr_if ),
        .app_rd_if           ( __app_rd_if ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // ----------------------------------
    // State interface control mux
    // - mux between update transactions
    //   from datapath and control plane
    // - strict priority goes to updates
    //   coming from the datapath
    // ----------------------------------
    state_intf_control_mux #(
        .NUM_TRANSACTIONS   ( NUM_RD_TRANSACTIONS )
    ) i_state_intf_control_mux  (
        .clk           ( clk ),
        .srst          ( srst ),
        .from_datapath ( update_if ),
        .from_control  ( ctrl_if ),
        .to_target     ( __update_if )
    );

    // ----------------------------------
    // State vector
    // ----------------------------------
    state_vector #(
        .SPEC             ( SPEC ),
        .NUM_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_state_vector  (
        .clk          ( clk ),
        .srst         ( srst ),
        .en           ( en ),
        .ctxt         ( rmw_ctxt_out.ctxt ),
        .prev_state   ( prev_state ),
        .update       ( rmw_ctxt_out.update ),
        .init         ( rmw_ctxt_out.init ),
        .next_state   ( next_state ),
        .return_state ( return_state )
    );

    // ----------------------------------
    // Database RMW
    // - read from database to get previous state,
    //   write to database to set next state
    // ----------------------------------
    // Maintain RMW context
    assign rmw_ctxt_in.id = __update_if.id;
    assign rmw_ctxt_in.ctxt = __update_if.ctxt;
    assign rmw_ctxt_in.update = __update_if.update;
    assign rmw_ctxt_in.init = __update_if.init;

    // Notice consecutive updates to the same ID
    always_ff @(posedge clk) if (__update_if.req && __update_if.rdy) last_update_id <= __update_if.id;
    assign rmw_ctxt_in.back_to_back = (__update_if.id == last_update_id);

    fifo_ctxt #(
        .DATA_WID ( $bits(rmw_ctxt_t) ),
        .DEPTH    ( NUM_RD_TRANSACTIONS )
    ) i_fifo_ctxt__rmw (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr_rdy  ( ),
        .wr      ( __update_if.req && __update_if.rdy ),
        .wr_data ( rmw_ctxt_in ),
        .rd      ( __app_rd_if.ack ),
        .rd_vld  ( ),
        .rd_data ( rmw_ctxt_out ),
        .oflow   ( ),
        .uflow   ( )
    );

    // ----------------------------------
    // Drive database read interface
    // ----------------------------------
    assign __update_if.rdy = __app_rd_if.rdy;
    assign __app_rd_if.req = __update_if.req;
    assign __app_rd_if.key = __update_if.id;
    assign __app_rd_if.next = 1'b0;

    // ----------------------------------
    // Calculate previous state, incorporating
    // possible fast-path update for
    // consecutive updates to the same ID
    // ----------------------------------
    // Latch new state calculated on previous clock cycle
    initial last_next_state_valid = 1'b0;
    always @(posedge clk) begin
        if (srst)                 last_next_state_valid <= 1'b0;
        else if (__app_rd_if.ack) last_next_state_valid <= 1'b1;
        else                      last_next_state_valid <= 1'b0;
    end
    always_ff @(posedge clk) if (__app_rd_if.ack) last_next_state <= next_state;

    always_comb begin
        prev_state = __app_rd_if.value;
        if (rmw_ctxt_out.back_to_back && last_next_state_valid) prev_state = last_next_state;
    end

    // ----------------------------------
    // Drive database write interface
    // ----------------------------------
    initial __app_wr_if.req = 1'b0;
    always @(posedge clk) begin
        if (srst)                 __app_wr_if.req <= 1'b0;
        else if (__app_rd_if.ack) __app_wr_if.req <= 1'b1;
        else                      __app_wr_if.req <= 1'b0;
    end
    always_ff @(posedge clk) begin
        __app_wr_if.key <= rmw_ctxt_out.id;
        __app_wr_if.value <= next_state;
    end
    assign __app_wr_if.valid = 1'b1; // Unused
    assign __app_wr_if.next = 1'b0;  // Unused

    // -----------------------------
    // Drive update response
    // -----------------------------
    initial __update_if.ack = 1'b0;
    always @(posedge clk) begin
        if (srst)                 __update_if.ack <= 1'b0;
        else if (__app_rd_if.ack) __update_if.ack <= 1'b1;
        else                      __update_if.ack <= 1'b0;
    end

    always_ff @(posedge clk) __update_if.state <= return_state;

endmodule : state_vector_core
