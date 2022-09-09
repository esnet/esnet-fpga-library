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
module state_valid #(
    parameter type ID_T = logic[7:0]
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
    db_intf #(.KEY_T(ID_T), .VALUE_T(logic)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(logic)) db_rd_if (.clk(clk));

    // ----------------------------------
    // State valid logic
    // ----------------------------------
    state_valid_core        #(
        .ID_T                ( ID_T ),
        .NUM_WR_TRANSACTIONS ( 4 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) i_state_valid_core ( .* );
  
    // ----------------------------------
    // State data store
    // ----------------------------------
    db_store_array    #(
        .KEY_T         ( ID_T ),
        .TRACK_VALID   ( 1 ),
        .DUMMY_VALUE   ( 1 )
    ) i_db_store_array (
        .init      ( db_init ),
        .init_done ( db_init_done ),
        .*
    );

endmodule : state_valid
