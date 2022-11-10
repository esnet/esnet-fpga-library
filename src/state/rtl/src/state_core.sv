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
module state_core
    import state_pkg::*;
#(
    parameter state_type_t TYPE = STATE_TYPE_UNSPECIFIED,
    parameter type ID_T = logic[7:0],
    parameter type STATE_T = logic[31:0],  // State vector
    parameter type UPDATE_T = logic,       // Update data
    parameter return_mode_t RETURN_MODE = RETURN_MODE_PREV_STATE,
    parameter int  NUM_WR_TRANSACTIONS = 4, // Maximum number of database write transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter int  NUM_RD_TRANSACTIONS = 8, // Maximum number of database read transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter bit  CACHE_EN = 1'b1          // Enable caching to ensure consistency of underlying state
                                            // data for cases where multiple transactions (closely spaced
                                            // in time) target the same state ID; in general, caching should
                                            // be enabled, but it can be disabled to achieve a less complex
                                            // implementation for applications insensitive to this type of inconsistency
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

    // RMW port (to be customized by application-specific state implementations)
    output STATE_T            prev_state,
    output logic              update_init,
    output UPDATE_T           update_data,
    input  STATE_T            new_state,

    // Read/write interfaces (to database/storage)
    output logic              db_init,
    input  logic              db_init_done,
    db_intf.requester         db_wr_if,
    db_intf.requester         db_rd_if
);
    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        ID_T     id;
        logic    init;
        UPDATE_T update;
        logic    back_to_back;
    } rmw_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic __srst;

    rmw_ctxt_t rmw_ctxt_in;
    rmw_ctxt_t rmw_ctxt_out;

    ID_T    last_update_id;
    logic   last_new_state_valid;
    STATE_T last_new_state;

    STATE_T update_state;

    // -----------------------------
    // Interfaces
    // -----------------------------
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) __app_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) __app_rd_if (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_STATE;
    assign info_if.subtype = TYPE;
    assign info_if.size = State#(ID_T)::numIDs();

    // -----------------------------
    // (Generic) database core
    // -----------------------------
    db_core #(
        .KEY_T               ( ID_T ),
        .VALUE_T             ( STATE_T ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .DB_CACHE_EN         ( 1 ),
        .APP_CACHE_EN        ( CACHE_EN )
    ) i_db_core              (
        .clk                 ( clk ),
        .srst                ( srst ),
        .init_done           ( init_done ),
        .ctrl_if             ( ctrl_if ),
        .app_wr_if           ( __app_wr_if ),
        .app_rd_if           ( __app_rd_if ),
        .db_init             ( db_init ),
        .db_init_done        ( db_init_done ),
        .db_wr_if            ( db_wr_if ),
        .db_rd_if            ( db_rd_if )
    );

    // -----------------------------
    // Local reset
    // -----------------------------
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || db_init) __srst <= 1'b1;
        else                 __srst <= 1'b0;
    end

    // -----------------------------
    // Drive read request
    // -----------------------------
    assign update_if.rdy = __app_rd_if.rdy;
    assign __app_rd_if.req = update_if.req;
    assign __app_rd_if.key = update_if.id;
    assign __app_rd_if.next = 1'b0; // Unused

    // -----------------------------
    // Handle back-to-back updates on the same ID
    // -----------------------------
    always_ff @(posedge clk) if (update_if.req && update_if.rdy) last_update_id <= update_if.id;

    // Signal that update is to same ID as previous update
    assign rmw_ctxt_in.back_to_back = (update_if.id == last_update_id);

    // Latch new state calculated on previous clock cycle
    initial last_new_state_valid = 1'b0;
    always @(posedge clk) begin
        if (__srst)               last_new_state_valid <= 1'b0;
        else if (__app_rd_if.ack) last_new_state_valid <= 1'b1;
        else                      last_new_state_valid <= 1'b0;
    end
    always_ff @(posedge clk) if (__app_rd_if.ack) last_new_state <= new_state;

    // -----------------------------
    // RMW context
    // -----------------------------
    fifo_small  #(
        .DATA_T  ( rmw_ctxt_t ),
        .DEPTH   ( NUM_RD_TRANSACTIONS )
    ) i_fifo_small__rmw_ctxt (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr      ( update_if.req && update_if.rdy ),
        .wr_data ( rmw_ctxt_in ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( __app_rd_if.ack ),
        .rd_data ( rmw_ctxt_out ),
        .empty   ( ),
        .uflow   ( )
    );

    assign rmw_ctxt_in.id = update_if.id;
    assign rmw_ctxt_in.init = update_if.init;
    assign rmw_ctxt_in.update = update_if.update;

    always_comb begin
        prev_state = __app_rd_if.value;
        if (rmw_ctxt_out.back_to_back && last_new_state_valid) prev_state = last_new_state;
    end
    assign update_init = rmw_ctxt_out.init;
    assign update_data = rmw_ctxt_out.update;

    // -----------------------------
    // Drive write interface
    // -----------------------------
    initial __app_wr_if.req = 1'b0;
    always @(posedge clk) begin
        if (__srst)               __app_wr_if.req <= 1'b0;
        else if (__app_rd_if.ack) __app_wr_if.req <= 1'b1;
        else                      __app_wr_if.req <= 1'b0;
    end

    always_ff @(posedge clk) begin
        __app_wr_if.key <= rmw_ctxt_out.id;
        __app_wr_if.value <= new_state;
    end

    assign __app_wr_if.valid = 1'b0; // Unused
    assign __app_wr_if.next = 1'b0; // Unused

    // -----------------------------
    // Drive update response
    // -----------------------------
    generate
        if (RETURN_MODE == RETURN_MODE_PREV_STATE) begin : g__return_mode_prev_state
            assign update_state = prev_state;
        end : g__return_mode_prev_state
        else if (RETURN_MODE == RETURN_MODE_NEW_STATE) begin : g__return_mode_new_state
            assign update_state = new_state;
        end : g__return_mode_new_state
        else if (RETURN_MODE == RETURN_MODE_DELTA) begin : g__return_mode_delta
            assign update_state = new_state - prev_state;
        end : g__return_mode_delta
    endgenerate

    initial update_if.ack = 1'b0;
    always @(posedge clk) begin
        if (__srst)               update_if.ack <= 1'b0;
        else if (__app_rd_if.ack) update_if.ack <= 1'b1;
        else                      update_if.ack <= 1'b0;
    end

    always_ff @(posedge clk) update_if.state <= update_state;

endmodule : state_core
