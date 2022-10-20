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
    parameter bit  CACHE_EN = 1'b1          // Enable caching to ensure consistency of underlying state
                                            // data for cases where multiple transactions (closely spaced
                                            // in time) target the same state ID; in general, caching should
                                            // be enabled, but it can be disabled to achieve a less complex
                                            // implementation for applications insensitive to this type of inconsistency
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

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_rd_if (.clk(clk));
    
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
        if (srst)           db_init <= 1'b1;
        else if (ctrl_init) db_init <= 1'b1;
        else                db_init <= 1'b0;
    end

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
        .srst ( srst ),
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
        .srst ( srst ),
        .db_if_from_requester_hi_prio ( app_rd_if ),
        .db_if_from_requester_lo_prio ( ctrl_rd_if ),
        .db_if_to_responder           ( __db_rd_if )
    );
    
    // -----------------------------
    // Write cache
    // -----------------------------
    generate
        if (CACHE_EN) begin : g__cache
            // (Local) parameters
            localparam int PTR_WID = $clog2(NUM_WR_TRANSACTIONS);
            localparam int CACHE_DEPTH = 2**PTR_WID;
            localparam int CACHE_LOOKUP_STAGES = 1;

            // (Local) typedefs
            typedef struct packed {
                KEY_T   key;
                logic   valid;
                VALUE_T value;
            } wr_ctxt_t;

            typedef struct packed {
                logic   hit;
                logic   valid;
                VALUE_T value;
            } cache_result_t;

            typedef logic [PTR_WID-1:0] ptr_t;

            // (Local) signals
            wr_ctxt_t  wr_ctxt_p [CACHE_DEPTH];

            ptr_t  wr_ptr;
            ptr_t  rd_ptr;

            logic          cache_lookup_done;
            cache_result_t cache_result;
            cache_result_t cache_result_p [CACHE_DEPTH];
            cache_result_t cache_result_out;

            logic  rd_ack;
            logic  rd_error;
            logic  rd_valid;
            VALUE_T rd_value;
            KEY_T   rd_next_key;

            // Store write context
            always_ff @(posedge clk) begin
                if (db_init) begin
                    for (int i = 0; i < CACHE_DEPTH; i++) begin
                        wr_ctxt_p[i] = '0;
                    end
                end else begin
                    if (db_wr_if.req && db_wr_if.rdy) begin
                        for (int i = 1; i < CACHE_DEPTH; i++) begin
                            wr_ctxt_p[i] <= wr_ctxt_p[i-1];
                        end
                        wr_ctxt_p[0].key <= db_wr_if.key;
                        wr_ctxt_p[0].valid <= db_wr_if.valid;
                        wr_ctxt_p[0].value <= db_wr_if.value;
                    end
                end
            end

            // Cache lookup
            always_ff @(posedge clk) begin
                if (db_init)                           cache_lookup_done <= 1'b0;
                else if (db_rd_if.req && db_rd_if.rdy) cache_lookup_done <= 1'b1;
                else                                   cache_lookup_done <= 1'b0;
            end

            always_ff @(posedge clk) begin
                cache_result.hit <= 1'b0;
                if (db_rd_if.req && db_rd_if.rdy && !db_rd_if.next) begin
                    for (int i = 0; i < CACHE_DEPTH; i++) begin
                        automatic int idx = CACHE_DEPTH-1-i;
                        if (wr_ctxt_p[idx].key == db_rd_if.key) begin
                            cache_result.hit <= 1'b1;
                            cache_result.valid <= wr_ctxt_p[idx].valid;
                            cache_result.value <= wr_ctxt_p[idx].value;
                        end
                    end
                end
            end

            // Manage read context (i.e. cache result)
            always_ff @(posedge clk) begin
                if (db_init)                wr_ptr <= 0;
                else if (cache_lookup_done) wr_ptr <= wr_ptr + 1;
            end

            always_ff @(posedge clk) begin
                if (db_init)     rd_ptr <= 0;
                else if (rd_ack) rd_ptr <= rd_ptr + 1;
            end

            always_ff @(posedge clk) if (cache_lookup_done) cache_result_p[wr_ptr] <= cache_result;

            always_ff @(posedge clk) cache_result_out <= cache_result_p[rd_ptr];

            always_comb begin
                __db_rd_if.valid = rd_valid;
                __db_rd_if.value = rd_value;
                __db_rd_if.error = rd_error;
                if (rd_ack) begin
                    if (cache_result_out.hit) begin
                        __db_rd_if.valid = cache_result_out.valid;
                        __db_rd_if.value = cache_result_out.value;
                        __db_rd_if.error = 1'b0;
                    end
                end
            end

            // Delay read response to ensure cache lookup can complete
            typedef struct packed {logic ack; logic error; logic valid; VALUE_T value; KEY_T next_key;} rd_resp_t;
            rd_resp_t rd_resp_in;
            rd_resp_t rd_resp_out;

            assign rd_resp_in.ack = db_rd_if.ack;
            assign rd_resp_in.error = db_rd_if.error;
            assign rd_resp_in.valid = db_rd_if.valid;
            assign rd_resp_in.value = db_rd_if.value;
            assign rd_resp_in.next_key = db_rd_if.next_key;

            util_delay   #(
                .DATA_T   ( rd_resp_t ),
                .DELAY    ( 2 )
            ) i_util_delay__db_rd_ack (
                .clk      ( clk ),
                .srst     ( db_init ),
                .data_in  ( rd_resp_in ),
                .data_out ( rd_resp_out )
            );

            assign rd_ack = rd_resp_out.ack;
            assign rd_error = rd_resp_out.error;
            assign rd_valid = rd_resp_out.valid;
            assign rd_value = rd_resp_out.value;
            assign rd_next_key = rd_resp_out.next_key;

            // Drive external read interface
            assign db_rd_if.req = __db_rd_if.req;
            assign db_rd_if.key = __db_rd_if.key;
            assign db_rd_if.next = __db_rd_if.next;
            assign __db_rd_if.rdy = db_rd_if.rdy;
            assign __db_rd_if.ack = rd_ack;
            assign __db_rd_if.next_key = rd_next_key;

        end : g__cache
        else begin : g__no_cache
            // No cache; pass read interface through directly
            db_intf_rd_connector i_db_intf_rd_connector (
                .db_if_from_requester ( __db_rd_if ),
                .db_if_to_responder   ( db_rd_if )
            );
        end : g__no_cache
    endgenerate

endmodule : db_core
