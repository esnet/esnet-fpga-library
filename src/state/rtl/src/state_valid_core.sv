module state_valid_core #(
    parameter type ID_T = logic[7:0],
    parameter int NUM_WR_TRANSACTIONS = 4,
    parameter int NUM_RD_TRANSACTIONS = 8
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Status interface
    db_status_intf.peripheral status_if,

    // Update interface
    state_update_intf.target  update_if,

    // Read/write interfaces (to database/storage)
    output logic              db_init,
    input  logic              db_init_done,
    db_intf.requester         db_wr_if,
    db_intf.requester         db_rd_if
);
    // ----------------------------------
    // Imports
    // ----------------------------------
    import state_pkg::*;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf   #(.KEY_T(ID_T), .VALUE_T(logic)) app_wr_if__unused (.clk(clk));
    db_intf   #(.KEY_T(ID_T), .VALUE_T(logic)) app_rd_if (.clk(clk));

    // ----------------------------------
    // Drive info interface
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_STATE;
    assign info_if.subtype = STATE_TYPE_VALID;
    assign info_if.size = State#(ID_T)::numIDs();

    // ----------------------------------
    // Base component
    // ----------------------------------
    db_core                 #(
        .KEY_T               ( ID_T ),
        .VALUE_T             ( logic ), // Unused
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .DB_CACHE_EN         ( 0 ) // Read-only access from update interface
                                   // Single-threaded from control interface
    ) i_db_core       (
        .clk          ( clk ),
        .srst         ( srst ),
        .init_done    ( init_done ),
        .ctrl_if      ( ctrl_if ),
        .app_wr_if    ( app_wr_if__unused ),
        .app_rd_if    ( app_rd_if ),
        .db_init      ( db_init ),
        .db_init_done ( db_init_done ),
        .db_wr_if     ( db_wr_if ),
        .db_rd_if     ( db_rd_if )
    );
  
    // ----------------------------------
    // Tie off application write interface
    // ----------------------------------
    assign app_wr_if__unused.req = 1'b0;
    assign app_wr_if__unused.key = '0;
    assign app_wr_if__unused.next = 1'b0;
    assign app_wr_if__unused.value = '0;
    assign app_wr_if__unused.valid = 1'b0;

    // ----------------------------------
    // Drive update interface
    // ----------------------------------
    assign update_if.rdy = app_rd_if.rdy;
    assign app_rd_if.req = update_if.req;
    assign app_rd_if.key = update_if.id;
    assign app_rd_if.next = 1'b0;
    assign update_if.ack = app_rd_if.ack;
    assign update_if.state = app_rd_if.valid;

    // ----------------------------------
    // Drive status interface
    // ----------------------------------
    always_ff @(posedge clk) begin
        status_if.evt_activate <= (ctrl_if.req && ctrl_if.rdy && ctrl_if.command == db_pkg::COMMAND_SET);
        status_if.evt_deactivate <= (ctrl_if.req && ctrl_if.rdy && ctrl_if.command == db_pkg::COMMAND_UNSET);
    end

endmodule : state_valid_core
