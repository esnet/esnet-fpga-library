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

    // Info interface
    db_info_intf.peripheral   info_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Update interface (from application)
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
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_rd_if (.clk(clk));

    // ----------------------------------
    // State read logic
    // ----------------------------------
    state_read_core         #(
        .ID_T                ( ID_T ),
        .STATE_T             ( STATE_T ),
        .NUM_WR_TRANSACTIONS ( 1 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) i_state_read_core ( .* );
   
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

endmodule : state_read
