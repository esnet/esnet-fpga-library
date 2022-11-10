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
module state_timer_core #(
    parameter type ID_T = logic[7:0],
    parameter type TIMER_T = logic[15:0],
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

    // Timer tick
    input  logic              tick,

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
    // Imports
    // ----------------------------------
    import state_pkg::*;

    // ----------------------------------
    // Signals
    // ----------------------------------
    TIMER_T timer;
    TIMER_T new_timer;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T)) __ctrl_if (.clk(clk));

    // ----------------------------------
    // Base state component
    // ----------------------------------
    state_core              #(
        .TYPE                ( STATE_TYPE_TIMER ),
        .ID_T                ( ID_T ),
        .STATE_T             ( TIMER_T ),
        .UPDATE_T            ( logic ), // unused
        .RETURN_MODE         ( RETURN_MODE_DELTA ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .CACHE_EN            ( 1 )
    ) i_state_core           (
        .clk                 ( clk ),
        .srst                ( srst ),
        .init_done           ( init_done ),
        .info_if             ( info_if ),
        .ctrl_if             ( __ctrl_if ),
        .update_if           ( update_if ),
        .prev_state          ( ),
        .update_init         ( ),
        .update_data         ( ),
        .new_state           ( timer ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // ----------------------------------
    // Timer
    // ----------------------------------
    initial timer = 0;
    always @(posedge clk) begin
        if (srst)      timer <= 0;
        else if (tick) timer <= timer + 1;
    end

    // ----------------------------------
    // State update logic
    // ----------------------------------
    always_comb begin
        new_timer = timer;
    end
 
    // ----------------------------------
    // Control interface state remapping
    // ----------------------------------
    // Replace state data from control
    // plane with current value of timer.
    // (set_value from control plane is
    // ignored).
    assign __ctrl_if.set_value = timer;

    // Connect remaining signals from control plane
    assign __ctrl_if.req = ctrl_if.req;
    assign __ctrl_if.command = ctrl_if.command;
    assign __ctrl_if.key = ctrl_if.key;

    // Replace state data toward control
    // plane with difference between current
    // timer value and stored timer value;
    // pipeline to account for subtraction

    always_ff @(posedge clk) ctrl_if.get_value <= timer - __ctrl_if.get_value;

    // Connect remaining signals toward control plane
    // (pipeline to maintain synchronization with data)
    initial ctrl_if.ack = 1'b0;
    always @(posedge clk) begin
        ctrl_if.ack <= __ctrl_if.ack;
        ctrl_if.status <= __ctrl_if.status;
        ctrl_if.get_valid <= __ctrl_if.get_valid;
    end

    // Assign ready directly (no need to pipeline)
    assign ctrl_if.rdy = __ctrl_if.rdy;

endmodule : state_timer_core
