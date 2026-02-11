module db_core #(
    parameter int  NUM_WR_TRANSACTIONS = 4, // Maximum number of database write transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
                                            // When NUM_TRANSACTIONS > 1, write caching is implemented
                                            // with the number of cache entries equal to NUM_WR_TRANSACTIONS
    parameter int  NUM_RD_TRANSACTIONS = 8, // Maximum number of database read transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter bit  DB_CACHE_EN = 1'b0,      // Enable caching of db wr/rd interface transactions
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
    // Parameters
    // ----------------------------------
    localparam int KEY_WID = ctrl_if.KEY_WID;
    localparam int VALUE_WID = ctrl_if.VALUE_WID;

    // Check
    initial begin
        std_pkg::param_check(app_wr_if.KEY_WID,   KEY_WID,   "app_wr_if.KEY_WID");
        std_pkg::param_check(app_wr_if.VALUE_WID, VALUE_WID, "app_wr_if.VALUE_WID");
        std_pkg::param_check(app_rd_if.KEY_WID,   KEY_WID,   "app_rd_if.KEY_WID");
        std_pkg::param_check(app_rd_if.VALUE_WID, VALUE_WID, "app_rd_if.VALUE_WID");
        std_pkg::param_check(db_wr_if.KEY_WID,    KEY_WID,   "db_wr_if.KEY_WID");
        std_pkg::param_check(db_wr_if.VALUE_WID,  VALUE_WID, "db_wr_if.VALUE_WID");
        std_pkg::param_check(db_rd_if.KEY_WID,    KEY_WID,   "db_rd_if.KEY_WID");
        std_pkg::param_check(db_rd_if.VALUE_WID,  VALUE_WID, "db_rd_if.VALUE_WID");
    end

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic ctrl_init;
    logic __srst;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_wr_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_rd_if (.clk);

    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __app_rd_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __db_rd_if (.clk);

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
        .NUM_TRANSACTIONS ( NUM_WR_TRANSACTIONS )
    ) i_db_intf_prio_wr_mux (
        .clk  ( clk ),
        .srst ( __srst ),
        .from_requester_hi_prio ( app_wr_if ),
        .from_requester_lo_prio ( ctrl_wr_if ),
        .to_responder           ( db_wr_if )
    );

    db_intf_prio_rd_mux  #(
        .NUM_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_db_intf_prio_rd_mux (
        .clk  ( clk ),
        .srst ( __srst ),
        .from_requester_hi_prio ( __app_rd_if ),
        .from_requester_lo_prio ( ctrl_rd_if ),
        .to_responder           ( __db_rd_if )
    );

    // ------------------------------------------------
    // Database cache
    // - accounts for in-flight write transactions to
    //   the database at the time of a read request
    // - ensures consistent database view from perspective
    //   of db wr/rd interfaces
    // ------------------------------------------------
    generate
        if (DB_CACHE_EN && (NUM_WR_TRANSACTIONS > 1)) begin : g__db_cache
            // (Local) typedefs
            typedef struct packed {
                logic                 ins_del_n;
                logic [VALUE_WID-1:0] value;
            } cache_entry_t;

            typedef struct packed {
                logic                 hit;
                logic                 valid;
                logic [VALUE_WID-1:0] value;
            } cache_ctxt_t;

            typedef struct packed {
                logic                 error;
                logic [KEY_WID-1:0]   next_key;
                logic                 valid;
                logic [VALUE_WID-1:0] value;
            } rd_ctxt_t;

            // (Local) signals
            cache_entry_t cache_wr_if_value;
            cache_entry_t cache_rd_if_value;

            cache_ctxt_t  cache_ctxt_in;
            cache_ctxt_t  cache_ctxt_out;
            logic         cache_ctxt_out_vld;
            logic         cache_ctxt_q_oflow;
            logic         cache_ctxt_q_uflow;

            // (Local) interfaces
            db_intf #(.KEY_WID(KEY_WID), .VALUE_WID($bits(cache_entry_t))) cache_wr_if (.clk);
            db_intf #(.KEY_WID(KEY_WID), .VALUE_WID($bits(cache_entry_t))) cache_rd_if (.clk);

            // Drive read request
            assign __db_rd_if.rdy = db_rd_if.rdy;
            assign db_rd_if.req  = __db_rd_if.req;
            assign db_rd_if.key  = __db_rd_if.key;
            assign db_rd_if.next = __db_rd_if.next;

            // Least-recently-used cache
            db_store_lru #(
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
            assign cache_wr_if_value.ins_del_n = db_wr_if.valid;
            assign cache_wr_if_value.value = db_wr_if.value;
            assign cache_wr_if.value = cache_wr_if_value;
            assign cache_wr_if.next = 1'b0; // Unused

            assign cache_rd_if.req = db_rd_if.req && db_rd_if.rdy;
            assign cache_rd_if.key = db_rd_if.key;
            assign cache_rd_if.next = db_rd_if.next;

            // Cache result context (wait for read to complete)
            assign cache_ctxt_in.hit   = cache_rd_if.ack && cache_rd_if.valid;
            assign cache_rd_if_value   = cache_rd_if.value;
            assign cache_ctxt_in.valid = cache_rd_if_value.ins_del_n;
            assign cache_ctxt_in.value = cache_rd_if_value.value;

            fifo_small_ctxt #(
                .DATA_WID ( $bits(cache_ctxt_t) ),
                .DEPTH    ( NUM_RD_TRANSACTIONS )
            ) i_fifo_small_ctxt__cache (
                .clk     ( clk ),
                .srst    ( __srst ),
                .wr_rdy  ( ),
                .wr      ( cache_rd_if.ack ),
                .wr_data ( cache_ctxt_in ),
                .rd      ( db_rd_if.ack ),
                .rd_vld  ( cache_ctxt_out_vld ),
                .rd_data ( cache_ctxt_out ),
                .oflow   ( cache_ctxt_q_oflow ),
                .uflow   ( cache_ctxt_q_uflow )
            );

            // Incorporate cache result and drive read response
            initial __db_rd_if.ack = 1'b0;
            always @(posedge clk) begin
                if (__srst) __db_rd_if.ack <= 1'b0;
                else        __db_rd_if.ack <= db_rd_if.ack;
            end

            always_ff @(posedge clk) begin
                if (cache_ctxt_out.hit) begin
                    __db_rd_if.error    <= 1'b0;
                    __db_rd_if.valid    <= cache_ctxt_out.valid;
                    __db_rd_if.value    <= cache_ctxt_out.value;
                    __db_rd_if.next_key <= '0;
                end else begin
                    __db_rd_if.error    <= db_rd_if.error;
                    __db_rd_if.valid    <= db_rd_if.valid;
                    __db_rd_if.next_key <= db_rd_if.next_key;
                    __db_rd_if.value    <= db_rd_if.value;
                end
            end

        end : g__db_cache
        else begin : g__no_db_cache
            // No cache; pass read interface through directly
            db_intf_rd_connector i_db_intf_rd_connector (
                .from_requester ( __db_rd_if ),
                .to_responder   ( db_rd_if )
            );

        end : g__no_db_cache
    endgenerate

    // -----------------------------
    // App cache
    // -----------------------------
    // - accounts for in-flight write transactions to
    //   the database at the time of receiving the read
    //   acknowledgement
    // - ensures consistent 'instantaneous' view of the
    //   database contents for RMW consistency
    generate
        if (APP_CACHE_EN && (NUM_RD_TRANSACTIONS > 1)) begin : g__app_cache
            // (Local) typedefs
            typedef struct packed {
                logic                 ins_del_n;
                logic [VALUE_WID-1:0] value;
            } cache_entry_t;

            typedef struct packed {
                logic [KEY_WID-1:0] key;
                logic               next;
            } rd_req_ctxt_t;

            // (Local) signals
            cache_entry_t cache_wr_if_value;
            cache_entry_t cache_rd_if_value;

            rd_req_ctxt_t  rd_req_ctxt_in;
            rd_req_ctxt_t  rd_req_ctxt_out;
            logic          rd_req_ctxt_out_vld;

            logic                 app_rd_if__ack   [2];
            logic                 app_rd_if__valid [2];
            logic [VALUE_WID-1:0] app_rd_if__value [2];
            logic                 app_rd_if__error [2];
            logic [KEY_WID-1:0]   app_rd_if__next_key [2];

            // (Local) interfaces
            db_intf #(.KEY_WID(KEY_WID), .VALUE_WID($bits(cache_entry_t))) cache_wr_if (.clk);
            db_intf #(.KEY_WID(KEY_WID), .VALUE_WID($bits(cache_entry_t))) cache_rd_if (.clk);

            // Least-recently-used cache
            db_store_lru #(
                .SIZE     ( NUM_RD_TRANSACTIONS ),
                .WRITE_FLOW_THROUGH ( 1 )
            ) i_db_store_lru  (
                .clk          ( clk ),
                .srst         ( __srst ),
                .db_init      ( 1'b0 ),
                .db_init_done ( ),
                .db_wr_if     ( cache_wr_if ),
                .db_rd_if     ( cache_rd_if )
            );

            assign cache_wr_if.req = app_wr_if.req && app_wr_if.rdy;
            assign cache_wr_if.key = app_wr_if.key;
            assign cache_wr_if.valid = 1'b1;
            assign cache_wr_if_value.ins_del_n = app_wr_if.valid;
            assign cache_wr_if_value.value = app_wr_if.value;
            assign cache_wr_if.value = cache_wr_if_value;
            assign cache_wr_if.next = 1'b0; // Unused

            // Read request context (wait for read to complete)
            fifo_ctxt #(
                .DATA_WID ( $bits(rd_req_ctxt_t) ),
                .DEPTH    ( NUM_RD_TRANSACTIONS )
            ) i_fifo_ctxt__rd_req (
                .clk     ( clk ),
                .srst    ( __srst ),
                .wr_rdy  ( ),
                .wr      ( app_rd_if.req && app_rd_if.rdy ),
                .wr_data ( rd_req_ctxt_in ),
                .rd      ( __app_rd_if.ack ),
                .rd_vld  ( ),
                .rd_data ( rd_req_ctxt_out ),
                .oflow   ( ),
                .uflow   ( )
            );

            assign rd_req_ctxt_in.key = app_rd_if.key;
            assign rd_req_ctxt_in.next = app_rd_if.next;

            assign cache_rd_if.req = __app_rd_if.ack;
            assign cache_rd_if.key = rd_req_ctxt_out.key;
            assign cache_rd_if.next = rd_req_ctxt_out.next;
            assign cache_rd_if_value = cache_rd_if.value;

            // Assign read interface
            assign __app_rd_if.req = app_rd_if.req;
            assign __app_rd_if.key = app_rd_if.key;
            assign __app_rd_if.next = app_rd_if.next;

            assign app_rd_if.rdy = __app_rd_if.rdy;

            // Account for cache read
            initial app_rd_if__ack = '{default: 1'b0};
            always @(posedge clk) begin
                if (__srst) app_rd_if__ack <= '{default: 1'b0};
                else begin
                    app_rd_if__ack[0] <= __app_rd_if.ack;
                    app_rd_if__ack[1] <= app_rd_if__ack[0];
                end
            end
            assign app_rd_if.ack = app_rd_if__ack[1];

            always_ff @(posedge clk) begin
                app_rd_if__valid   [0] <= __app_rd_if.valid;
                app_rd_if__value   [0] <= __app_rd_if.value;
                app_rd_if__error   [0] <= __app_rd_if.error;
                app_rd_if__next_key[0] <= __app_rd_if.next_key;
                app_rd_if__valid   [1] <= app_rd_if__valid[0];
                app_rd_if__value   [1] <= app_rd_if__value[0];
                app_rd_if__error   [1] <= app_rd_if__error[0];
                app_rd_if__next_key[1] <= app_rd_if__next_key[0];
            end

            // Response (incorporate cache result)
            always_comb begin
                app_rd_if.valid = app_rd_if__valid[1];
                app_rd_if.value = app_rd_if__value[1];
                app_rd_if.error = app_rd_if__error[1];
                app_rd_if.next_key = app_rd_if__next_key[1];
                if (cache_rd_if.ack && cache_rd_if.valid) begin
                    app_rd_if.valid = cache_rd_if_value.ins_del_n;
                    app_rd_if.value = cache_rd_if_value.value;
                    app_rd_if.error = cache_rd_if.error;
                    app_rd_if.next_key = cache_rd_if.next_key;
                end
            end
        end : g__app_cache
        else begin : g__no_app_cache
            // No cache; pass read interface through directly
            db_intf_rd_connector i_db_intf_rd_connector (
                .from_requester ( app_rd_if ),
                .to_responder   ( __app_rd_if )
            );
        end : g__no_app_cache
    endgenerate

endmodule : db_core
