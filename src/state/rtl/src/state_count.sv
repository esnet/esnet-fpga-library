module state_count #(
    parameter type ID_T = logic[7:0],
    parameter type COUNT_T = logic[31:0],
    parameter type INC_T = logic [7:0]
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    output logic              init_done,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Status interface
    db_info_intf.peripheral   info_if,

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
    db_intf #(.KEY_T(ID_T), .VALUE_T(COUNT_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(COUNT_T)) db_rd_if (.clk(clk));

    // ----------------------------------
    // State count logic
    // ----------------------------------
    state_count_core        #(
        .ID_T                ( ID_T ),
        .COUNT_T             ( COUNT_T ),
        .INC_T               ( INC_T ),
        .NUM_WR_TRANSACTIONS ( 4 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) i_state_count_core  ( .* );
    
    // ----------------------------------
    // State data store
    // ----------------------------------
    db_store_array  #(
        .KEY_T       ( ID_T ),
        .VALUE_T     ( COUNT_T )
    ) i_db_store_array (
        .init      ( db_init ),
        .init_done ( db_init_done ),
        .*
    );

endmodule : state_count
