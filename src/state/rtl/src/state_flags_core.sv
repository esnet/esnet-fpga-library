// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================
module state_flags_core
    import state_pkg::*;
#(
    parameter type ID_T = logic[7:0],
    parameter type FLAGS_T = logic[7:0],
    parameter return_mode_t RETURN_MODE = RETURN_MODE_PREV_STATE,
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

    // Update interface
    state_update_intf.target  update_if,

    // Read/write interfaces (to database/storage)
    output logic              db_init,
    input  logic              db_init_done,
    db_intf.requester         db_wr_if,
    db_intf.requester         db_rd_if
);
    // ----------------------------------
    // Signals
    // ----------------------------------
    FLAGS_T prev_flags;
    logic   update_init;
    FLAGS_T update_flags;
    FLAGS_T new_flags;

    // ----------------------------------
    // Base state component
    // ----------------------------------
    state_core              #(
        .TYPE                ( STATE_TYPE_FLAGS ),
        .ID_T                ( ID_T ),
        .STATE_T             ( FLAGS_T ),
        .UPDATE_T            ( FLAGS_T ),
        .RETURN_MODE         ( RETURN_MODE ),
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
        .prev_state          ( prev_flags ),
        .update_init         ( update_init ),
        .update_data         ( update_flags ),
        .new_state           ( new_flags ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // ----------------------------------
    // State update logic
    // ----------------------------------
    always_comb begin
        new_flags = prev_flags;
        if (update_init) new_flags  = update_flags;
        else             new_flags |= update_flags;
    end

endmodule : state_flags_core
