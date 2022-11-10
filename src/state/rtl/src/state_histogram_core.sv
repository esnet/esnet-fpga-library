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
module state_histogram_core #(
    parameter type ID_T = logic[7:0],
    parameter type UPDATE_T = logic[31:0],
    parameter type COUNT_T = logic[31:0],
    parameter int  BINS = 8,
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
    input  logic               clk,
    input  logic               srst,

    output logic               init_done,

    // Control interface
    db_ctrl_intf.peripheral    ctrl_if,

    // Status interface
    db_info_intf.peripheral    info_if,

    // Update interface
    state_update_intf.target   update_if,

    // Read/write interfaces (to database/storage)
    output logic               db_init,
    input  logic               db_init_done,
    db_intf.requester          db_wr_if,
    db_intf.requester          db_rd_if,

    // Configuration
    // -- Low/High bin thresholds; updates will be made to all bins where
    //    bin_thresh_low <= data <= bin_thresh_high
    input  UPDATE_T            bin_thresh_low  [BINS],
    input  UPDATE_T            bin_thresh_high [BINS]

);
    // ----------------------------------
    // Imports
    // ----------------------------------
    import state_pkg::*;

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef COUNT_T [0:BINS-1] STATE_T;

    // ----------------------------------
    // Signals
    // ----------------------------------
    STATE_T   prev_bins;
    logic     update_init;
    UPDATE_T  update_data;
    STATE_T   new_bins;

    // ----------------------------------
    // Base state component
    // ----------------------------------
    state_core              #(
        .TYPE                ( STATE_TYPE_HISTOGRAM ),
        .ID_T                ( ID_T ),
        .STATE_T             ( STATE_T ),
        .UPDATE_T            ( UPDATE_T ),
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
        .prev_state          ( prev_bins ),
        .update_init         ( update_init ),
        .update_data         ( update_data ),
        .new_state           ( new_bins ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // ----------------------------------
    // State update logic
    // ----------------------------------
    generate
        for (genvar g_bin = 0; g_bin < BINS; g_bin++) begin : g__bin
            // (Local) signals
            logic in_range;
            // Determine if data value is in range for current bin
            assign in_range = (update_data >= bin_thresh_low[g_bin]) && (update_data <= bin_thresh_high[g_bin]);
            // Update bin count
            always_comb begin
                new_bins[g_bin] = prev_bins[g_bin];
                if (update_init)   new_bins[g_bin] = in_range ? 1 : 0;
                else if (in_range) new_bins[g_bin] += 1;
            end
        end : g__bin
    endgenerate

endmodule : state_histogram_core
