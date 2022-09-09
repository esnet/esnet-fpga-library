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
module state_read #(
    parameter type ID_T = logic[7:0],
    parameter type STATE_T = logic[31:0],
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

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Status interface
    db_status_intf.peripheral status_if,

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
    import db_pkg::*;
    import state_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    // ----------------------------------
    // Signals
    // ----------------------------------
    STATE_T new_state;

    // ----------------------------------
    // Export status
    // ----------------------------------
    assign status_if._type = DB_TYPE_STATE;
    assign status_if.subtype = STATE_TYPE_READ;
    assign status_if.size = State#(ID_T)::numIDs();
    assign status_if.fill = State#(ID_T)::numIDs();

    // ----------------------------------
    // Base state component
    // ----------------------------------
    state_core              #(
        .ID_T                ( ID_T ),
        .STATE_T             ( logic ),
        .UPDATE_T            ( logic ), // Unused
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .APP_CACHE_EN        ( 0 ) // No writes from update interface
    ) i_state_core           (
        .clk                 ( clk ),
        .srst                ( srst ),
        .init_done           ( init_done ),
        .ctrl_if             ( ctrl_if ),
        .update_if           ( update_if ),
        .prev_state          ( prev_state ),
        .update_init         ( ),
        .update_data         ( ),
        .new_state           ( new_state ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // ----------------------------------
    // State update logic
    // ----------------------------------
    always_comb begin
        new_state = prev_state;
    end

endmodule : state_read
