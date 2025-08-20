module htable_core
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  SIZE = 4096,          // Sets table depth/hash width (expect power of 2)
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 4,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter bit  APP_CACHE_EN = 1'b0      // Enable caching of update/lookup interface transactions to ensure consistency
                                            // of underlying table data for cases where multiple transactions
                                            // (closely spaced in time) target the same table entry; can be disabled to
                                            // achieve a less complex implementation for applications insensitive to
                                            // this type of inconsistency

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
    output KEY_T             update_key,
    input  hash_t            update_hash,

    output KEY_T             lookup_key,
    input  hash_t            lookup_hash,

    // Control interface (from table controller)
    db_ctrl_intf.peripheral  tbl_ctrl_if, // This control interface provides direct access
                                          // to the underlying hash table for table management
                                          // (e.g. insertion/deletion/optimization)
                                          // and therefore the interface configuration is:
                                          // KEY_T' := hash_t, VALUE_T' := {KEY_T, VALUE_T}

    // Read/write interfaces (to tables)
    output logic             tbl_init,
    input  logic             tbl_init_done,
    db_intf.requester        tbl_wr_if,
    db_intf.requester        tbl_rd_if

);
    // ----------------------------------
    // Imports
    // ----------------------------------
    import htable_pkg::*;

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        KEY_T   key;
        VALUE_T value;
    } entry_t;

    typedef struct packed {
        logic   valid;
        entry_t entry;
    } wr_ctxt_t;

    typedef struct packed {
        KEY_T   key;
    } rd_ctxt_t;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int HASH_WID = $clog2(SIZE);
    localparam int SIZE_POW2 = 2**HASH_WID;
    localparam type __HASH_T = logic[HASH_WID-1:0];

    // ----------------------------------
    // Signals
    // ----------------------------------
    __HASH_T  __update_hash;
    __HASH_T  __lookup_hash;

    logic     wr_req;
    wr_ctxt_t wr_ctxt;

    logic     rd_req;
    rd_ctxt_t rd_ctxt_in;
    rd_ctxt_t rd_ctxt_out;
    logic     rd_ctxt_uflow;
    entry_t   rd_entry;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(__HASH_T), .VALUE_T(entry_t)) __update_if (.clk(clk));
    db_intf #(.KEY_T(__HASH_T), .VALUE_T(entry_t)) __lookup_if (.clk(clk));
    db_intf #(.KEY_T(__HASH_T), .VALUE_T(entry_t)) __tbl_wr_if (.clk(clk));
    db_intf #(.KEY_T(__HASH_T), .VALUE_T(entry_t)) __tbl_rd_if (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_HTABLE;
    assign info_if.subtype = HTABLE_TYPE_SINGLE;
    assign info_if.size = SIZE_POW2;

    // ----------------------------------
    // Database core
    // - interfaces are configured for
    //   'direct' access to the underlying
    //   hash table, i.e.:
    //   KEY_T' := hash_t, VALUE_T' := {KEY_T, VALUE_T}
    // ----------------------------------
    db_core                 #(
        .KEY_T               ( __HASH_T ),
        .VALUE_T             ( entry_t ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .DB_CACHE_EN         ( 1'b0 ),
        .APP_CACHE_EN        ( APP_CACHE_EN )
    ) i_db_core       (
        .clk          ( clk ),
        .srst         ( srst ),
        .init_done    ( init_done ),
        .ctrl_if      ( tbl_ctrl_if ),
        .app_wr_if    ( __update_if ),
        .app_rd_if    ( __lookup_if ),
        .db_init      ( tbl_init ),
        .db_init_done ( tbl_init_done ),
        .db_wr_if     ( __tbl_wr_if ),
        .db_rd_if     ( __tbl_rd_if )
    );

    // ----------------------------------
    // Drive table interfaces
    //
    // - adapt 'right-sized' hashes to
    //   generic hash width used externally
    // ----------------------------------
    assign tbl_wr_if.req = __tbl_wr_if.req;
    assign tbl_wr_if.key = __tbl_wr_if.key;
    assign tbl_wr_if.valid = __tbl_wr_if.valid;
    assign tbl_wr_if.value = __tbl_wr_if.value;
    assign __tbl_wr_if.rdy = tbl_wr_if.rdy;
    assign __tbl_wr_if.ack = tbl_wr_if.ack;
    assign __tbl_wr_if.error = tbl_wr_if.error;

    assign tbl_rd_if.req = __tbl_rd_if.req;
    assign tbl_rd_if.key = __tbl_rd_if.key;
    assign __tbl_rd_if.rdy = tbl_rd_if.rdy;
    assign __tbl_rd_if.ack = tbl_rd_if.ack;
    assign __tbl_rd_if.error = tbl_rd_if.error;
    assign __tbl_rd_if.valid = tbl_rd_if.valid;
    assign __tbl_rd_if.value = tbl_rd_if.value;

    // Not yet supported
    assign tbl_wr_if.next = 1'b0;
    assign __tbl_wr_if.next_key = '0;

    assign tbl_rd_if.next = 1'b0;
    assign __tbl_rd_if.next_key = '0;

    // ----------------------------------
    // Drive hash interface
    // ----------------------------------
    assign update_key = update_if.key;
    assign lookup_key = lookup_if.key;

    assign __update_hash = update_hash[HASH_WID-1:0];
    assign __lookup_hash = lookup_hash[HASH_WID-1:0];

    // ----------------------------------
    // Account for hash latency
    // ----------------------------------
    generate
        if (HASH_LATENCY > 0) begin : g__hash_latency
            // (Local) signals
            wr_ctxt_t wr_ctxt_in;
            rd_ctxt_t rd_ctxt_hash;

            // Delay write request
            util_delay   #(
                .DATA_WID ( 1 ),
                .DELAY    ( HASH_LATENCY )
            ) i_util_delay__wr_req (
                .clk      ( clk ),
                .srst     ( srst ),
                .data_in  ( update_if.req ),
                .data_out ( wr_req )
            );

            // Delay write data
            assign wr_ctxt_in.valid = update_if.valid;
            assign wr_ctxt_in.entry.key = update_if.key;
            assign wr_ctxt_in.entry.value = update_if.value;
            util_delay   #(
                .DATA_WID ( $bits(wr_ctxt_t) ),
                .DELAY    ( HASH_LATENCY )
            ) i_util_delay__wr_ctxt (
                .clk      ( clk ),
                .srst     ( 1'b0 ),
                .data_in  ( wr_ctxt_in ),
                .data_out ( wr_ctxt )
            );

            // Delay read request
            util_delay   #(
                .DATA_WID ( 1 ),
                .DELAY    ( HASH_LATENCY )
            ) i_util_delay__rd_req (
                .clk      ( clk ),
                .srst     ( srst ),
                .data_in  ( lookup_if.req ),
                .data_out ( rd_req )
            );

            // Delay read context
            assign rd_ctxt_hash.key = lookup_if.key;
            util_delay   #(
                .DATA_WID ( $bits(rd_ctxt_t) ),
                .DELAY    ( HASH_LATENCY )
            ) i_util_delay__rd_ctxt (
                .clk      ( clk ),
                .srst     ( srst ),
                .data_in  ( rd_ctxt_hash ),
                .data_out ( rd_ctxt_in )
            );
        end : g__hash_latency
        else begin : g__hash_no_latency
            // Assign memory write interface directly
            // from database write interface
            assign wr_req = update_if.req;
            assign wr_ctxt.valid = update_if.valid;
            assign wr_ctxt.entry.key = update_if.key;
            assign wr_ctxt.entry.value = update_if.value;
            // Assign memory read interface directly
            // from database read interface
            assign rd_req = lookup_if.req;
            assign rd_ctxt_in.key = lookup_if.key;
        end : g__hash_no_latency
    endgenerate

    // ----------------------------------
    // Remap application write/read requests
    // ----------------------------------
    assign update_if.rdy = init_done;
    assign __update_if.req = wr_req;
    assign __update_if.key = __update_hash;
    assign __update_if.next = 1'b0;
    assign __update_if.valid = wr_ctxt.valid;
    assign __update_if.value = wr_ctxt.entry;
    assign update_if.ack = __update_if.ack;
    assign update_if.error = __update_if.error;
    assign update_if.next_key = '0;

    assign lookup_if.rdy = init_done;
    assign __lookup_if.req = rd_req;
    assign __lookup_if.key = __lookup_hash;
    assign __lookup_if.next = lookup_if.next;

    // ----------------------------------
    // Store read context
    // ----------------------------------
    fifo_small_ctxt #(
        .DATA_WID ( $bits(rd_ctxt_t) ),
        .DEPTH    ( NUM_RD_TRANSACTIONS )
    ) i_fifo_small__rd_ctxt (
        .clk     ( clk ),
        .srst    ( srst || tbl_init ),
        .wr_rdy  ( ),
        .wr      ( rd_req ),
        .wr_data ( rd_ctxt_in ),
        .rd      ( __lookup_if.ack ),
        .rd_vld  ( ),
        .rd_data ( rd_ctxt_out ),
        .oflow   ( ),
        .uflow   ( rd_ctxt_uflow )
    );

    // ----------------------------------
    // Process read result(s) and synthesize read response
    // ----------------------------------
    assign rd_entry = __lookup_if.value;

    initial lookup_if.ack = 1'b0;
    always @(posedge clk) begin
        if (srst || tbl_init)     lookup_if.ack <= 1'b0;
        else if (__lookup_if.ack) lookup_if.ack <= 1'b1;
        else                      lookup_if.ack <= 1'b0;
    end

    always_ff @(posedge clk) lookup_if.error <= rd_ctxt_uflow;

    always_ff @(posedge clk) begin
        if (__lookup_if.valid && (rd_entry.key == rd_ctxt_out.key)) begin
            lookup_if.valid <= 1'b1;
            lookup_if.value <= rd_entry.value;
        end else begin
            lookup_if.valid <= 1'b0;
            lookup_if.value <= '0;
        end
    end

    assign lookup_if.next_key = '0; // Unsupported

endmodule : htable_core

