module htable_multi_stash_core 
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 2,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  STASH_SIZE = 8,
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
    input  logic              clk,
    input  logic              srst,

    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Hashing interface
    output KEY_T              lookup_key,
    input  hash_t             lookup_hash [NUM_TABLES],

    output KEY_T              update_key,
    input  hash_t             update_hash [NUM_TABLES],

    // Lookup/update interfaces (from application)
    db_intf.responder         lookup_if,
    db_intf.responder         update_if,

    // Stash control/status
    db_ctrl_intf.peripheral   stash_ctrl_if,
    db_status_intf.peripheral stash_status_if,

    // Control interface (from table controller)
    db_ctrl_intf.peripheral   tbl_ctrl_if [NUM_TABLES], // This control interface provides direct access
                                                       // to the underlying hash table for table management
                                                       // (e.g. insertion/deletion/optimization)
                                                       // and therefore the interface configuration is:
                                                       // KEY_T' := HASH_T, VALUE_T' := {KEY_T, VALUE_T}

    // Read/write interfaces (to tables)
    output logic              tbl_init      [NUM_TABLES],
    input  logic              tbl_init_done [NUM_TABLES],
    db_intf.requester         tbl_wr_if     [NUM_TABLES],
    db_intf.requester         tbl_rd_if     [NUM_TABLES]

);
    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        logic error;
        logic valid;
        VALUE_T value;
    } stash_lookup_resp_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    // Tables
    logic __tbl_init_done;
    logic tbl_lookup_req;
    logic tbl_update_req;

    // Stash
    logic               stash_init_done;
    stash_lookup_resp_t stash_lookup_resp_in;
    stash_lookup_resp_t stash_lookup_resp;
    logic               stash_lookup_resp_fifo_empty;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf tbl_info_if ();
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) tbl_lookup_if (.clk(clk));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) stash_update_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) stash_lookup_if (.clk(clk));
    db_info_intf stash_info_if ();

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_HTABLE;
    assign info_if.subtype = HTABLE_TYPE_MULTI_STASH;
    assign info_if.size = tbl_info_if.size + STASH_SIZE;

    // ----------------------------------
    // Init done
    // ----------------------------------
    assign init_done = __tbl_init_done && stash_init_done;

    // ----------------------------------
    // Multi-hash hashtable core
    // ----------------------------------
    htable_multi_core       #(
        .KEY_T               ( KEY_T ),
        .VALUE_T             ( VALUE_T ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( TABLE_SIZE ),
        .HASH_LATENCY        ( HASH_LATENCY ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .APP_CACHE_EN        ( APP_CACHE_EN ),
        .INSERT_MODE         ( INSERT_MODE )
    ) i_htable_multi_core (
        .clk           ( clk ),
        .srst          ( srst ),
        .init_done     ( __tbl_init_done ),
        .info_if       ( tbl_info_if ),
        .lookup_key    ( lookup_key ),
        .lookup_hash   ( lookup_hash ),
        .update_key    ( update_key ),
        .update_hash   ( update_hash ),
        .lookup_if     ( tbl_lookup_if ),
        .update_if     ( update_if ),
        .tbl_ctrl_if   ( tbl_ctrl_if ),
        .tbl_init      ( tbl_init ),
        .tbl_init_done ( tbl_init_done ),
        .tbl_wr_if     ( tbl_wr_if ),
        .tbl_rd_if     ( tbl_rd_if )
    );

    // ----------------------------------
    // Stash
    // ----------------------------------
    db_stash    #(
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T ),
        .SIZE    ( STASH_SIZE ),
        .REG_REQ ( 1 )
    ) i_db_stash (
        .clk       ( clk ),
        .srst      ( srst ),
        .init_done ( stash_init_done ),
        .info_if   ( stash_info_if ),
        .ctrl_if   ( stash_ctrl_if ),
        .status_if ( stash_status_if ),
        .app_wr_if ( stash_update_if ),
        .app_rd_if ( stash_lookup_if )
    );

    // No stash updates from application interfaces
    // (entries can be added/removed from the stash using control interface only)
    assign stash_update_if.req = 1'b0;
    assign stash_update_if.key = '0;
    assign stash_update_if.valid = 1'b0;
    assign stash_update_if.value = '0;

    // Store stash lookup responses to align with table lookup results
    assign stash_lookup_resp_in.error = stash_lookup_if.error;
    assign stash_lookup_resp_in.valid = stash_lookup_if.valid;
    assign stash_lookup_resp_in.value = stash_lookup_if.value;

    fifo_small  #(
        .DATA_T  ( stash_lookup_resp_t ),
        .DEPTH   ( NUM_RD_TRANSACTIONS )
    ) i_fifo_small__lookup_resp (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr      ( stash_lookup_if.ack ),
        .wr_data ( stash_lookup_resp_in ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( tbl_lookup_if.ack ),
        .rd_data ( stash_lookup_resp ),
        .empty   ( stash_lookup_resp_fifo_empty ),
        .uflow   ( )
    );

    // ----------------------------------
    // Drive lookup interface
    // ----------------------------------
    // Lookup interface is ready when both tables and stash are ready
    assign lookup_if.rdy = tbl_lookup_if.rdy && stash_lookup_if.rdy;

    assign tbl_lookup_if.req   = lookup_if.req && stash_lookup_if.rdy;
    assign tbl_lookup_if.key   = lookup_if.key;
    assign tbl_lookup_if.next = 1'b0; // Unsupported in lookup context

    assign stash_lookup_if.req = lookup_if.req && tbl_lookup_if.rdy;
    assign stash_lookup_if.key = lookup_if.key;
    assign stash_lookup_if.next = 1'b0; // Unsupported in lookup context
            
    // Lookup response
    assign lookup_if.ack = tbl_lookup_if.ack;
    assign lookup_if.error = stash_lookup_resp.error || tbl_lookup_if.error || stash_lookup_resp_fifo_empty;

    always_comb begin
        lookup_if.valid = 1'b0;
        lookup_if.value = '0;
        if (stash_lookup_resp.valid) begin
            lookup_if.valid = 1'b1;
            lookup_if.value = stash_lookup_resp.value;
        end else if (tbl_lookup_if.valid) begin
            lookup_if.valid = 1'b1;
            lookup_if.value = tbl_lookup_if.value;
        end
    end

endmodule : htable_multi_stash_core
