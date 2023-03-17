module state_histogram #(
    parameter type ID_T = logic[7:0],
    parameter type UPDATE_T = logic[31:0],
    parameter type COUNT_T = logic[31:0],
    parameter int  BINS = 8
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    output logic               init_done,

    // Control interface
    db_ctrl_intf.peripheral    ctrl_if,

    // Status interface
    db_info_intf.peripheral    info_if,

    // Update interface
    state_update_intf.target   update_if,

    // Configuration
    // -- Low/High bin thresholds; updates will be made to all bins where
    //    bin_thresh_low <= data <= bin_thresh_high
    input  UPDATE_T            bin_thresh_low  [BINS],
    input  UPDATE_T            bin_thresh_high [BINS]

);
 
    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef COUNT_T [0:BINS-1] STATE_T;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic db_init;
    logic db_init_done;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_rd_if (.clk(clk));

    // ----------------------------------
    // State histogram logic
    // ----------------------------------
    state_histogram_core    #(
        .ID_T                ( ID_T ),
        .UPDATE_T            ( UPDATE_T ),
        .COUNT_T             ( COUNT_T ),
        .BINS                ( BINS ),
        .NUM_WR_TRANSACTIONS ( 4 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) i_state_histogram_core ( .* );
    
    // ----------------------------------
    // State data store
    // ----------------------------------
    db_store_array  #(
        .KEY_T       ( ID_T ),
        .VALUE_T     ( STATE_T )
    ) i_db_store_array (
        .init      ( db_init ),
        .init_done ( db_init_done ),
        .*
    );

endmodule : state_histogram
