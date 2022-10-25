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
module db_core #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_WR_TRANSACTIONS = 4, // Maximum number of database write transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
                                            // When NUM_TRANSACTIONS > 1, write caching is implemented
                                            // with the number of cache entries equal to NUM_WR_TRANSACTIONS
    parameter int  NUM_RD_TRANSACTIONS = 8, // Maximum number of database read transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter bit  DB_CACHE_EN = 1'b1,      // Enable caching of db wr/rd interface transactions
    parameter bit  APP_CACHE_EN = 1'b0      // Enable caching of app_wr/rd interface transactions to ensure consistency
                                            // of underlying state data for cases where multiple transactions
                                            // (closely spaced in time) target the same state ID; can be disabled to
                                            // achieve a less complex implementation for applications insensitive to
                                            // this type of inconsistency
)(
    // Clock/reset
    input  logic             clk,
    input  logic             srst,

    output logic             init_done,

    // Control interface
    db_ctrl_intf.peripheral  ctrl_if,

    // Read/write interfaces (from application)
    db_intf.responder        app_wr_if,
    db_intf.responder        app_rd_if,

    // Read/write interfaces (to database)
    output logic             db_init,
    input  logic             db_init_done,
    db_intf.requester        db_wr_if,
    db_intf.requester        db_rd_if
);
    // ----------------------------------
    // Signals
    // ----------------------------------
    logic ctrl_init;
    logic __srst;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_rd_if (.clk(clk));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __app_rd_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __db_rd_if (.clk(clk));

    // -----------------------------
    // Control transaction handling
    // (use 'standard' database peripheral component)
    // -----------------------------
    db_peripheral i_db_peripheral (
        .clk       ( clk ),
        .srst      ( srst ),
        .ctrl_if   ( ctrl_if ),
        .init      ( ctrl_init ),
        .init_done ( db_init_done ),
        .wr_if     ( ctrl_wr_if ),
        .rd_if     ( ctrl_rd_if )
    );

    // -----------------------------
    // Database initialization logic
    // -----------------------------
    initial db_init = 1'b1;
    always @(posedge clk) begin
        if (srst || ctrl_init) db_init <= 1'b1;
        else                   db_init <= 1'b0;
    end
    assign __srst = db_init;

    assign init_done = db_init_done;

    // -----------------------------
    // Mux between control-plane and data-plane transactions
    // (strict priority to data plane)
    // -----------------------------
    db_intf_prio_wr_mux  #(
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_WR_TRANSACTIONS )
    ) i_db_intf_prio_wr_mux (
        .clk  ( clk ),
        .srst ( __srst ),
        .db_if_from_requester_hi_prio ( app_wr_if ),
        .db_if_from_requester_lo_prio ( ctrl_wr_if ),
        .db_if_to_responder           ( db_wr_if )
    );

    db_intf_prio_rd_mux  #(
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_db_intf_prio_rd_mux (
        .clk  ( clk ),
        .srst ( __srst ),
        .db_if_from_requester_hi_prio ( __app_rd_if ),
        .db_if_from_requester_lo_prio ( ctrl_rd_if ),
        .db_if_to_responder           ( __db_rd_if )
    );

    // ------------------------------------------------
    // Database cache
    // - accounts for in-flight write transactions to
    //   the database at the time of a read request
    // - ensures consistent database view from perspective
    //   of db wr/rd interfaces
    // ------------------------------------------------
    generate
        if (DB_CACHE_EN) begin : g__db_cache
            // (Local) typedefs
            typedef struct packed {
                logic   ins_del_n;
                VALUE_T value;
            } cache_entry_t;

            typedef struct packed {
                logic   hit;
                logic   valid;
                VALUE_T value;
            } cache_ctxt_t;

            typedef struct packed {
                logic   error;
                KEY_T   next_key;
                logic   valid;
                VALUE_T value;
            } rd_ctxt_t;

            // (Local) signals
            cache_ctxt_t  cache_ctxt_in;
            cache_ctxt_t  cache_ctxt_out;

            logic         cache_ctxt_q_empty;
            logic         cache_ctxt_q_oflow;
            logic         cache_ctxt_q_uflow;

            rd_ctxt_t     rd_ctxt_in;
            rd_ctxt_t     rd_ctxt_out;

            logic         rd_ctxt_q_empty;
            logic         rd_ctxt_q_oflow;
            logic         rd_ctxt_q_uflow;

            logic         ctxt_fifo_rd;

            // (Local) interfaces
            db_intf #(.KEY_T(KEY_T), .VALUE_T(cache_entry_t)) cache_wr_if (.clk(clk));
            db_intf #(.KEY_T(KEY_T), .VALUE_T(cache_entry_t)) cache_rd_if (.clk(clk));

            // Drive read request
            assign __db_rd_if.rdy = db_rd_if.rdy;
            assign db_rd_if.req  = __db_rd_if.req;
            assign db_rd_if.key  = __db_rd_if.key;
            assign db_rd_if.next = __db_rd_if.next;

            // Least-recently-used cache
            db_store_lru #(
                .KEY_T    ( KEY_T ),
                .VALUE_T  ( cache_entry_t ),
                .SIZE     ( NUM_WR_TRANSACTIONS )
            ) i_db_store_lru  (
                .clk          ( clk ),
                .srst         ( __srst ),
                .db_init      ( 1'b0 ),
                .db_init_done ( ),
                .db_wr_if     ( cache_wr_if ),
                .db_rd_if     ( cache_rd_if )
            );

            assign cache_wr_if.req = db_wr_if.req && db_wr_if.rdy;
            assign cache_wr_if.key = db_wr_if.key;
            assign cache_wr_if.valid = 1'b1;
            assign cache_wr_if.value.ins_del_n = db_wr_if.valid;
            assign cache_wr_if.value.value = db_wr_if.value;
            assign cache_wr_if.next = 1'b0; // Unused

            assign cache_rd_if.req = db_rd_if.req && db_rd_if.rdy;
            assign cache_rd_if.key = db_rd_if.key;
            assign cache_rd_if.next = db_rd_if.next;

            // Cache result context (wait for read to complete)
            assign cache_ctxt_in.hit   = cache_rd_if.ack && cache_rd_if.valid;
            assign cache_ctxt_in.valid = cache_rd_if.value.ins_del_n;
            assign cache_ctxt_in.value = cache_rd_if.value.value;

            fifo_small #(
                .DATA_T ( cache_ctxt_t ),
                .DEPTH  ( NUM_RD_TRANSACTIONS )
            ) i_fifo_small__cache_ctxt (
                .clk     ( clk ),
                .srst    ( __srst ),
                .wr      ( cache_rd_if.ack ),
                .wr_data ( cache_ctxt_in ),
                .full    ( ),
                .oflow   ( cache_ctxt_q_oflow ),
                .rd      ( ctxt_fifo_rd ),
                .rd_data ( cache_ctxt_out ),
                .empty   ( cache_ctxt_q_empty ),
                .uflow   ( cache_ctxt_q_uflow )
            );

            // Collect read responses
            assign rd_ctxt_in.error    = db_rd_if.error;
            assign rd_ctxt_in.next_key = db_rd_if.next_key;
            assign rd_ctxt_in.valid    = db_rd_if.valid;
            assign rd_ctxt_in.value    = db_rd_if.value;

            fifo_small  #(
                .DATA_T  ( rd_ctxt_t ),
                .DEPTH   ( 2 )
            ) i_fifo_small__rd_ctxt (
                .clk     ( clk ),
                .srst    ( __srst ),
                .wr      ( db_rd_if.ack ),
                .wr_data ( rd_ctxt_in ),
                .full    ( ),
                .oflow   ( rd_ctxt_q_oflow ),
                .rd      ( ctxt_fifo_rd ),
                .rd_data ( rd_ctxt_out ),
                .empty   ( rd_ctxt_q_empty ),
                .uflow   ( rd_ctxt_q_uflow )
            );

            assign ctxt_fifo_rd = !rd_ctxt_q_empty && !cache_ctxt_q_empty;

            // Incorporate cache result and drive read response
            initial __db_rd_if.ack = 1'b0;
            always @(posedge clk) begin
                if (__srst) __db_rd_if.ack <= 1'b0;
                else        __db_rd_if.ack <= ctxt_fifo_rd;
            end

            always_ff @(posedge clk) begin
                if (cache_ctxt_out.hit) begin
                    __db_rd_if.error    <= 1'b0;
                    __db_rd_if.valid    <= cache_ctxt_out.valid;
                    __db_rd_if.value    <= cache_ctxt_out.value;
                    __db_rd_if.next_key <= '0;
                end else begin
                    __db_rd_if.error    <= rd_ctxt_out.error;
                    __db_rd_if.valid    <= rd_ctxt_out.valid;
                    __db_rd_if.next_key <= rd_ctxt_out.next_key;
                    __db_rd_if.value    <= rd_ctxt_out.value;
                end
            end

        end : g__db_cache
        else begin : g__no_db_cache
            // No cache; pass read interface through directly
            db_intf_rd_connector i_db_intf_rd_connector (
                .db_if_from_requester ( __db_rd_if ),
                .db_if_to_responder   ( db_rd_if )
            );

        end : g__no_db_cache
    endgenerate

    // -----------------------------
    // App cache
    // -----------------------------
    generate
        if (APP_CACHE_EN) begin : g__app_cache
            // (Local) typedefs
            typedef struct packed {
                logic   ins_del_n;
                VALUE_T value;
            } cache_entry_t;

            typedef struct packed {
                KEY_T key;
                logic next;
            } rd_req_ctxt_t;

            // (Local) signals
            rd_req_ctxt_t  rd_req_ctxt_in;
            rd_req_ctxt_t  rd_req_ctxt_out;
            logic          rd_req_ctxt_q_empty;

            // (Local) interfaces
            db_intf #(.KEY_T(KEY_T), .VALUE_T(cache_entry_t)) cache_wr_if (.clk(clk));
            db_intf #(.KEY_T(KEY_T), .VALUE_T(cache_entry_t)) cache_rd_if (.clk(clk));

            // Least-recently-used cache
            db_store_lru #(
                .KEY_T    ( KEY_T ),
                .VALUE_T  ( cache_entry_t ),
                .SIZE     ( NUM_RD_TRANSACTIONS )
            ) i_db_store_lru  (
                .clk          ( clk ),
                .srst         ( __srst ),
                .db_init      ( 1'b0 ),
                .db_init_done ( ),
                .db_wr_if     ( cache_wr_if ),
                .db_rd_if     ( cache_rd_if )
            );

            assign cache_wr_if.req = db_wr_if.req && db_wr_if.rdy;
            assign cache_wr_if.key = db_wr_if.key;
            assign cache_wr_if.valid = 1'b1;
            assign cache_wr_if.value.ins_del_n = db_wr_if.valid;
            assign cache_wr_if.value.value = db_wr_if.value;
            assign cache_wr_if.next = 1'b0; // Unused

            // Read request context (wait for read to complete)
            fifo_small #(
                .DATA_T ( rd_req_ctxt_t ),
                .DEPTH  ( NUM_RD_TRANSACTIONS )
            ) i_fifo_small__rd_req (
                .clk     ( clk ),
                .srst    ( __srst ),
                .wr      ( app_rd_if.req && app_rd_if.rdy ),
                .wr_data ( rd_req_ctxt_in ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( __app_rd_if.ack ),
                .rd_data ( rd_req_ctxt_out ),
                .empty   ( rd_req_ctxt_q_empty ),
                .uflow   ( )
            );

            assign rd_req_ctxt_in.key = app_rd_if.key;
            assign rd_req_ctxt_in.next = app_rd_if.next;

            assign cache_rd_if.req = !rd_req_ctxt_q_empty;
            assign cache_rd_if.key = rd_req_ctxt_out.key;
            assign cache_rd_if.next = rd_req_ctxt_out.next;

            // Assign read interface
            assign __app_rd_if.req = app_rd_if.req;
            assign __app_rd_if.key = app_rd_if.key;
            assign __app_rd_if.next = app_rd_if.next;

            assign app_rd_if.rdy = __app_rd_if.rdy;
            assign app_rd_if.ack = __app_rd_if.ack;
            assign app_rd_if.error = __app_rd_if.error;
            assign app_rd_if.next_key = __app_rd_if.next_key;

            always_comb begin
                app_rd_if.valid = __app_rd_if.valid;
                app_rd_if.value = __app_rd_if.value;
                if (cache_rd_if.ack && cache_rd_if.valid) begin
                    app_rd_if.valid = cache_rd_if.value.ins_del_n;
                    app_rd_if.value = cache_rd_if.value.value;
                end
            end
        end : g__app_cache
        else begin : g__no_app_cache
            // No cache; pass read interface through directly
            db_intf_rd_connector i_db_intf_rd_connector (
                .db_if_from_requester ( app_rd_if ),
                .db_if_to_responder   ( __app_rd_if )
            );
        end : g__no_app_cache
    endgenerate

endmodule : db_core
