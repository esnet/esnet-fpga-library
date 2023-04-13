module state_seq_core #(
    parameter type ID_T = logic[7:0],
    parameter type SEQ_T = logic[15:0],
    parameter type INC_T = logic[7:0],
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
    input  logic              clk,
    input  logic              srst,

    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Update interface (from application)
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
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        INC_T inc;
        SEQ_T seq;
    } update_data_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic         update_init;
    update_data_t update_data;
    SEQ_T         prev_seq;
    SEQ_T         new_seq;

    // ----------------------------------
    // Base state component
    // ----------------------------------
    state_core              #(
        .TYPE                ( STATE_TYPE_SEQ ),
        .ID_T                ( ID_T ),
        .STATE_T             ( SEQ_T ),
        .UPDATE_T            ( update_data_t ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .CACHE_EN            ( 1 )
    ) i_state_core           (
        .clk                 ( clk ),
        .srst                ( srst ),
        .init_done           ( init_done ),
        .info_if             ( info_if ),
        .ctrl_if             ( ctrl_if ),
        .update_if           ( update_if ),
        .prev_state          ( prev_seq),
        .update_init         ( update_init ),
        .update_data         ( update_data ),
        .new_state           ( new_seq ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // ----------------------------------
    // State update logic
    // ----------------------------------
    always_comb begin
        if      (update_init)                 new_seq = update_data.seq + update_data.inc;
        else if (update_data.seq >= prev_seq) new_seq = update_data.seq + update_data.inc;
        else                                  new_seq = prev_seq;
    end

endmodule : state_seq_core
