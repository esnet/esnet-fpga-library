module htable_multi_core
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 2,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter bit  APP_CACHE_EN = 1'b0,     // Enable caching of update/lookup interface transactions to ensure consistency
                                            // of underlying table data for cases where multiple transactions
                                            // (closely spaced in time) target the same table entry; can be disabled to
                                            // achieve a less complex implementation for applications insensitive to
                                            // this type of inconsistency
    parameter htable_multi_insert_mode_t INSERT_MODE = HTABLE_MULTI_INSERT_MODE_NONE // Insert mode
                                            // Typical implementation will be reads (lookups) from the
                                            // application interface and writes (insertions) from the control
                                            // interface. Additionally (or instead) writes can be supported
                                            // from the application interface but due to ambiguity inherent
                                            // in writing to a target with multiple tables, the write mode
                                            // must be specified
                                            // HTABLE_MULTI_INSERT_MODE_NONE: application interface writes are
                                            //     disabled; all insertions are performed via control interface
                                            // HTABLE_MULTI_INSERT_MODE_ROUND_ROBIN: application interface writes are
                                            //     supported; sequential writes are distributed across the
                                            //     hash tables in round-robin fashion.
                                            // HTABLE_MULTI_INSERT_MODE_BROADCAST: application interface writes are
                                            //     supported; insertions are distributed to ALL hash tables.
)(
    // Clock/reset
    input  logic             clk,
    input  logic             srst,

    output logic             init_done,

    // Info interface
    db_info_intf.peripheral  info_if,

    // Lookup/insertion interfaces (from application)
    db_intf.responder        lookup_if,
    db_intf.responder        update_if,

    // Hashing interface
    output KEY_T             lookup_key,
    input  hash_t            lookup_hash [NUM_TABLES],

    output KEY_T             update_key,
    input  hash_t            update_hash [NUM_TABLES],

    // Control interface (from table controller)
    db_ctrl_intf.peripheral  tbl_ctrl_if [NUM_TABLES], // This control interface provides direct access
                                                       // to the underlying hash table for table management
                                                       // (e.g. insertion/deletion/optimization)
                                                       // and therefore the interface configuration is:
                                                       // KEY_T' := HASH_T, VALUE_T' := {KEY_T, VALUE_T}

    // Read/write interfaces (to tables)
    output logic             tbl_init      [NUM_TABLES],
    input  logic             tbl_init_done [NUM_TABLES],
    db_intf.requester        tbl_wr_if     [NUM_TABLES],
    db_intf.requester        tbl_rd_if     [NUM_TABLES]

);

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        logic   error;
        logic   valid;
        VALUE_T value;
    } lookup_resp_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic [NUM_TABLES-1:0] init_done__tbl;

    int                    info_if_size__tbl [NUM_TABLES];

    KEY_T                  __lookup_key [NUM_TABLES];
    KEY_T                  __update_key [NUM_TABLES];

    logic                  lookup_done;

    logic [NUM_TABLES-1:0] lookup_done__tbl;
    logic [NUM_TABLES-1:0] lookup_error__tbl;
    logic [NUM_TABLES-1:0] lookup_valid__tbl;
    VALUE_T                lookup_value__tbl[NUM_TABLES];
    logic [NUM_TABLES-1:0] lookup_if_rdy__tbl;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf info_if__tbl ();
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) update_if__tbl [NUM_TABLES] (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_HTABLE;
    assign info_if.subtype = HTABLE_TYPE_MULTI;
    always_comb begin
        info_if.size = 0;
        for (int tbl = 0; tbl < NUM_TABLES; tbl++) begin
            info_if.size += info_if_size__tbl[tbl];
        end
    end

    // ----------------------------------
    // Instantiate array of single-table cores
    // - each component includes standard control
    //   and muxing for a single hash table
    // ----------------------------------
    generate
        for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl
            // (Local) signals
            lookup_resp_t lookup_resp_in;
            lookup_resp_t lookup_resp_out;
            logic         lookup_resp_q_empty;

            // (Local) interfaces
            db_info_intf __info_if ();
            db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __lookup_if (.clk(clk));

            // Single-table hashtable instance
            htable_core #(
                .KEY_T               ( KEY_T ),
                .VALUE_T             ( VALUE_T ),
                .SIZE                ( TABLE_SIZE[g_tbl] ),
                .HASH_LATENCY        ( HASH_LATENCY ),
                .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
                .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
                .APP_CACHE_EN        ( APP_CACHE_EN )
            ) i_htable_core   (
                .clk           ( clk ),
                .srst          ( srst ),
                .init_done     ( init_done__tbl[g_tbl] ),
                .info_if       ( __info_if ),
                .lookup_key    ( __lookup_key  [g_tbl] ),
                .lookup_hash   ( lookup_hash   [g_tbl] ),
                .update_key    ( __update_key  [g_tbl] ),
                .update_hash   ( update_hash   [g_tbl] ),
                .update_if     ( update_if__tbl[g_tbl] ),
                .lookup_if     ( __lookup_if           ),
                .tbl_ctrl_if   ( tbl_ctrl_if   [g_tbl] ),
                .tbl_init      ( tbl_init      [g_tbl] ),
                .tbl_init_done ( tbl_init_done [g_tbl] ),
                .tbl_wr_if     ( tbl_wr_if     [g_tbl] ),
                .tbl_rd_if     ( tbl_rd_if     [g_tbl] )
            );

            // Retrieve size info
            assign info_if_size__tbl[g_tbl] = __info_if.size;

            // Drive local lookup interface
            assign __lookup_if.req = lookup_if.req;
            assign __lookup_if.key = lookup_if.key;
            assign __lookup_if.next = 1'b0;

            assign lookup_if_rdy__tbl[g_tbl] = __lookup_if.rdy;

            // Capture lookup result
            assign lookup_resp_in.error = __lookup_if.error;
            assign lookup_resp_in.valid = __lookup_if.valid;
            assign lookup_resp_in.value = __lookup_if.value;

            fifo_small #(
                .DATA_T ( lookup_resp_t ),
                .DEPTH  ( NUM_RD_TRANSACTIONS )
            ) i_fifo_small__lookup_resp (
                .clk  ( clk ),
                .srst ( srst || tbl_init [g_tbl] ),
                .wr   ( __lookup_if.ack ),
                .wr_data ( lookup_resp_in ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( lookup_done ),
                .rd_data ( lookup_resp_out ),
                .empty   ( lookup_resp_q_empty ),
                .uflow   ( )
            );

            assign lookup_done__tbl[g_tbl] = !lookup_resp_q_empty;
            assign lookup_error__tbl[g_tbl] = lookup_resp_out.error;
            assign lookup_valid__tbl[g_tbl] = lookup_resp_out.valid;
            assign lookup_value__tbl[g_tbl] = lookup_resp_out.value;
        end : g__tbl
    endgenerate

    assign init_done = &init_done__tbl;

    // Table insert/update interfaces have common control, so keys are the same
    assign lookup_key = __lookup_key[0];
    assign update_key = __update_key[0];

    // Combine read responses
    assign lookup_if.rdy = &lookup_if_rdy__tbl;

    assign lookup_done = &lookup_done__tbl;

    initial lookup_if.ack = 1'b0;
    always @(posedge clk) begin
        if (srst)             lookup_if.ack <= 1'b0;
        else if (lookup_done) lookup_if.ack <= 1'b1;
        else                  lookup_if.ack <= 1'b0;
    end

    always_ff @(posedge clk) begin
        lookup_if.error <= |lookup_error__tbl;
        lookup_if.valid <= |lookup_valid__tbl;
        lookup_if.value <= '0;
        for (int i = 0; i < NUM_TABLES; i++) begin
            if (lookup_valid__tbl[i]) lookup_if.value <= lookup_value__tbl[i];
        end
    end
    assign lookup_if.next_key = '0;

    generate
        if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin : g__htable_multi_ins_mode_none
            // Disable writes from application interface
            for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl
                assign update_if__tbl[g_tbl].req = 1'b0;
                assign update_if__tbl[g_tbl].key = '0;
                assign update_if__tbl[g_tbl].next = 1'b0;
                assign update_if__tbl[g_tbl].valid = 1'b0;
                assign update_if__tbl[g_tbl].value = '0;
                assign update_if.rdy = 1'b0;
                assign update_if.error = 1'b0;
                assign update_if.next_key = '0;
            end : g__tbl
        end : g__htable_multi_ins_mode_none
        else if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_ROUND_ROBIN) begin : g__htable_multi_ins_mode_round_robin
            // Service write requests from application by distributing to the tables in round-robin order
            // NOTE: this method allows for very fast insertion but will result in collisions/overwriting;
            //       If this is unacceptable the hash table should be managed (insertions/deletions) via the control
            //       interface, with read-only access from the application
            db_intf_rr_wr_demux #(
                .NUM_IFS ( NUM_TABLES ),
                .KEY_T   ( KEY_T ),
                .VALUE_T ( VALUE_T ),
                .NUM_TRANSACTIONS ( NUM_WR_TRANSACTIONS )
            ) i_db_intf_rr_wr_demux (
                .clk ( clk ),
                .srst ( srst ),
                .db_if_from_requester ( update_if ),
                .db_if_to_responder   ( update_if__tbl )
            );
        end : g__htable_multi_ins_mode_round_robin
        else if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_BROADCAST) begin : g__htable_multi_ins_mode_broadcast
            //  (Local) signals
            logic update_if__tbl_rdy [NUM_TABLES];
            logic update_if__tbl_ack [NUM_TABLES];
            logic update_if__tbl_error [NUM_TABLES];

            // Broadcast write requests to all tables
            for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl
                assign update_if__tbl[g_tbl].req = update_if.req;
                assign update_if__tbl[g_tbl].key = update_if.key;
                assign update_if__tbl[g_tbl].next = 1'b0;
                assign update_if__tbl[g_tbl].valid = update_if.valid;
                assign update_if__tbl[g_tbl].value = update_if.value;

                assign update_if__tbl_rdy[g_tbl] = update_if__tbl[g_tbl].rdy;
                assign update_if__tbl_ack[g_tbl] = update_if__tbl[g_tbl].ack;
                assign update_if__tbl_error[g_tbl] = update_if__tbl[g_tbl].error;
            end : g__tbl
            assign update_if.rdy = update_if__tbl_rdy[0];
            assign update_if.ack = update_if__tbl_ack[0];
            assign update_if.error = update_if__tbl_error[0];
            assign update_if.next_key = '0;
        end : g__htable_multi_ins_mode_broadcast
    endgenerate

endmodule : htable_multi_core

