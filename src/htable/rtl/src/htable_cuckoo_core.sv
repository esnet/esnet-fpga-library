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
module htable_cuckoo_core
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 2,
    parameter int  NUM_RD_TRANSACTIONS = 8
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

    // Lookup interface (from application)
    db_intf.responder         lookup_if,

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
    // Parameters
    // ----------------------------------
    localparam type TBL_ENTRY_T = struct packed {KEY_T key; VALUE_T value;};

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) update_if__unused (.clk(clk));
    
    db_status_intf stash_status_if__unused (.clk(clk), .srst(srst));
    db_ctrl_intf  #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) stash_ctrl_if (.clk(clk));

    db_info_intf tbl_info_if ();
    db_ctrl_intf #(.KEY_T(hash_t), .VALUE_T(TBL_ENTRY_T)) tbl_ctrl_if [NUM_TABLES] (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_HTABLE;
    assign info_if.subtype = HTABLE_TYPE_CUCKOO;
    assign info_if.size = tbl_info_if.size - 1; // Don't include single-entry 'bubble' stash

    // ----------------------------------
    // Cuckoo controller
    // ----------------------------------
    htable_cuckoo_controller #(
        .KEY_T        ( KEY_T ),
        .VALUE_T      ( VALUE_T ),
        .NUM_TABLES   ( NUM_TABLES ),
        .TABLE_SIZE   ( TABLE_SIZE ),
        .HASH_LATENCY ( HASH_LATENCY )
    ) i_htable_cuckoo_controller (
        .clk           ( clk ),
        .srst          ( srst ),
        .en            ( en ),
        .init_done     ( init_done ),
        .key           ( ctrl_key ),
        .hash          ( ctrl_hash ),
        .ctrl_if       ( ctrl_if ),
        .stash_ctrl_if ( stash_ctrl_if ),
        .tbl_ctrl_if   ( tbl_ctrl_if )
    );

    // ----------------------------------
    // Multi-hash + stash core
    // ----------------------------------
    htable_multi_stash_core #(
        .KEY_T               ( KEY_T ),
        .VALUE_T             ( VALUE_T ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( TABLE_SIZE ),
        .HASH_LATENCY        ( HASH_LATENCY ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .STASH_SIZE          ( 1 ), // Bubble stash (single-entry)
        .INSERT_MODE         ( HTABLE_MULTI_INSERT_MODE_NONE )
    ) i_htable_multi_stash_core (
        .clk              ( clk ),
        .srst             ( srst ),
        .init_done        ( init_done ),
        .info_if          ( tbl_info_if ),
        .lookup_key       ( lookup_key ),
        .lookup_hash      ( lookup_hash ),
        .update_key       ( ),
        .update_hash      ( '{NUM_TABLES{32'h0}} ),
        .lookup_if        ( lookup_if ),
        .update_if        ( update_if__unused ),
        .stash_ctrl_if    ( stash_ctrl_if ),
        .stash_status_if  ( stash_status_if__unused ),
        .tbl_ctrl_if      ( tbl_ctrl_if ),
        .tbl_init         ( tbl_init ),
        .tbl_init_done    ( tbl_init_done ),
        .tbl_wr_if        ( tbl_wr_if ),
        .tbl_rd_if        ( tbl_rd_if )
    );

    // Tie off unused update interface (all updates processed through control path)
    assign update_if__unused.req = 1'b0;
    assign update_if__unused.key = '0;
    assign update_if__unused.next = 1'b0;
    assign update_if__unused.valid = '0;
    assign update_if__unused.value = '0;

endmodule : htable_cuckoo_core

