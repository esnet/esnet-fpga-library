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
module htable_cuckoo_fast_update_core
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 2,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  UPDATE_BURST_SIZE = 8
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              en,

    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Status interface
    db_status_intf.peripheral status_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral     axil_if,

    // Lookup interface (from application)
    db_intf.responder         lookup_if,

    // Update interface (from application)
    db_intf.responder         update_if,

    // Hashing interface
    output KEY_T              lookup_key,
    input  hash_t             lookup_hash [NUM_TABLES],

    output KEY_T              ctrl_key    [NUM_TABLES],
    input  hash_t             ctrl_hash   [NUM_TABLES],

    // Read/write interfaces (to database)
    output logic              tbl_init      [NUM_TABLES],
    input  logic              tbl_init_done [NUM_TABLES],
    db_intf.requester         tbl_wr_if     [NUM_TABLES],
    db_intf.requester         tbl_rd_if     [NUM_TABLES]

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
    db_ctrl_intf  #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) cuckoo_ctrl_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) cuckoo_lookup_if (.clk(clk));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __lookup_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __update_if (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_HTABLE;
    assign info_if.subtype = HTABLE_TYPE_CUCKOO_FAST_UPDATE;
    assign info_if.size = cuckoo_info_if.size;

    // ----------------------------------
    // Database core
    // ----------------------------------
    db_core          #(
        .KEY_T        ( KEY_T ),
        .VALUE_T      ( VALUE_T ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .APP_CACHE_EN ( 1 )
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
        .KEY_T               ( KEY_T ),
        .VALUE_T             ( VALUE_T ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .UPDATE_BURST_SIZE   ( UPDATE_BURST_SIZE )
    ) i_htable_fast_update_core (
        .clk           ( clk ),
        .srst          ( __srst ),
        .en            ( en ),
        .init_done     ( fast_update_init_done ),
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
        .KEY_T               ( KEY_T ),
        .VALUE_T             ( VALUE_T ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( TABLE_SIZE ),
        .HASH_LATENCY        ( HASH_LATENCY ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_htable_cuckoo_core   (
        .clk                 ( clk ),
        .srst                ( __srst ),
        .en                  ( en ),
        .init_done           ( cuckoo_init_done ),
        .axil_if             ( axil_if ),
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

