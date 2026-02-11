module htable_cuckoo_fast_update_core
    import htable_pkg::*;
#(
    parameter int  KEY_WID = 1,
    parameter int  VALUE_WID = 1,
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  UPDATE_BURST_SIZE = 8
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    input  logic               en,

    output logic               init_done,

    // Info interface
    db_info_intf.peripheral    info_if,

    // Status interface
    db_status_intf.peripheral  status_if,

    // Control interface
    db_ctrl_intf.peripheral    ctrl_if,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral      axil_if,

    // Lookup interface (from application)
    db_intf.responder          lookup_if,

    // Update interface (from application)
    db_intf.responder          update_if,

    // Hashing interface
    output logic [KEY_WID-1:0] lookup_key,
    input  hash_t              lookup_hash [NUM_TABLES],

    output logic [KEY_WID-1:0] ctrl_key    [NUM_TABLES],
    input  hash_t              ctrl_hash   [NUM_TABLES],

    // Read/write interfaces (to database)
    output logic               tbl_init      [NUM_TABLES],
    input  logic               tbl_init_done [NUM_TABLES],
    db_intf.requester          tbl_wr_if     [NUM_TABLES],
    db_intf.requester          tbl_rd_if     [NUM_TABLES]

);

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic init;
    logic __srst;
    logic fast_update_init_done;
    logic cuckoo_init_done;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf cuckoo_info_if ();
    db_ctrl_intf  #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) cuckoo_ctrl_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) cuckoo_lookup_if (.clk);

    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __lookup_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __update_if (.clk);

    axi4l_intf #() cuckoo_axil_if ();
    axi4l_intf #() fast_update_axil_if ();

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_HTABLE;
    assign info_if.subtype = HTABLE_TYPE_CUCKOO_FAST_UPDATE;
    assign info_if.size = cuckoo_info_if.size;

    // ----------------------------------
    // AXI-L control
    // ----------------------------------
    // Decoder
    htable_cuckoo_fast_update_decoder i_htable_cuckoo_fast_update_decoder (
        .axil_if             ( axil_if ),
        .cuckoo_axil_if      ( cuckoo_axil_if ),
        .fast_update_axil_if ( fast_update_axil_if )
    );

    // ----------------------------------
    // Database core
    // ----------------------------------
    db_core          #(
        .NUM_WR_TRANSACTIONS ( 1 ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .APP_CACHE_EN ( 0 ),
        .DB_CACHE_EN  ( 0 )
    ) i_db_core       (
        .clk          ( clk ),
        .srst         ( srst ),
        .init_done    ( init_done ),
        .ctrl_if      ( ctrl_if ),
        .app_wr_if    ( update_if ),
        .app_rd_if    ( lookup_if ),
        .db_init      ( init ),
        .db_init_done ( fast_update_init_done ),
        .db_wr_if     ( __update_if ),
        .db_rd_if     ( __lookup_if )
    );

    // ----------------------------------
    // Local reset/init
    // ----------------------------------
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || init) __srst <= 1'b1;
        else              __srst <= 1'b0;
    end

    // ----------------------------------
    // Fast update core
    // ----------------------------------
    htable_fast_update_core #(
        .KEY_WID             ( KEY_WID ),
        .VALUE_WID           ( VALUE_WID ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .UPDATE_BURST_SIZE   ( UPDATE_BURST_SIZE )
    ) i_htable_fast_update_core (
        .clk           ( clk ),
        .srst          ( __srst ),
        .en            ( en ),
        .init_done     ( fast_update_init_done ),
        .axil_if       ( fast_update_axil_if ),
        .lookup_if     ( __lookup_if ),
        .update_if     ( __update_if ),
        .tbl_init_done ( cuckoo_init_done ),
        .tbl_ctrl_if   ( cuckoo_ctrl_if ),
        .tbl_lookup_if ( cuckoo_lookup_if )
    );

    // ----------------------------------
    // Cuckoo hash core
    // ----------------------------------
    htable_cuckoo_core #(
        .KEY_WID             ( KEY_WID ),
        .VALUE_WID           ( VALUE_WID ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( TABLE_SIZE ),
        .HASH_LATENCY        ( HASH_LATENCY ),
        .NUM_WR_TRANSACTIONS ( 1 ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_htable_cuckoo_core   (
        .clk                 ( clk ),
        .srst                ( __srst ),
        .en                  ( en ),
        .init_done           ( cuckoo_init_done ),
        .axil_if             ( cuckoo_axil_if ),
        .info_if             ( cuckoo_info_if ),
        .status_if           ( status_if ),
        .ctrl_if             ( cuckoo_ctrl_if ),
        .lookup_if           ( cuckoo_lookup_if ),
        .lookup_key          ( lookup_key ),
        .lookup_hash         ( lookup_hash ),
        .ctrl_key            ( ctrl_key ),
        .ctrl_hash           ( ctrl_hash ),
        .tbl_init            ( tbl_init ),
        .tbl_init_done       ( tbl_init_done ),
        .tbl_wr_if           ( tbl_wr_if ),
        .tbl_rd_if           ( tbl_rd_if )
    );

endmodule : htable_cuckoo_fast_update_core

