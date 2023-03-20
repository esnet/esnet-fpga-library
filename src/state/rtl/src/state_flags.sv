module state_flags 
    import state_pkg::*;
#(
    parameter type ID_T = logic[7:0],
    parameter type FLAGS_T = logic[7:0],
    parameter return_mode_t RETURN_MODE = RETURN_MODE_PREV_STATE
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Update interface
    state_update_intf.target  update_if
);
    // ----------------------------------
    // Signals
    // ----------------------------------
    logic db_init;
    logic db_init_done;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(ID_T), .VALUE_T(FLAGS_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(FLAGS_T)) db_rd_if (.clk(clk));

    // ----------------------------------
    // State flags logic
    // ----------------------------------
    state_flags_core        #(
        .ID_T                ( ID_T ),
        .FLAGS_T             ( FLAGS_T ),
        .NUM_WR_TRANSACTIONS ( 4 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) i_state_flags_core  ( .* );
    
    // ----------------------------------
    // State data store
    // ----------------------------------
    db_store_array  #(
        .KEY_T       ( ID_T ),
        .VALUE_T     ( FLAGS_T )
    ) i_db_store_array (
        .init      ( db_init ),
        .init_done ( db_init_done ),
        .*
    );

endmodule : state_flags
