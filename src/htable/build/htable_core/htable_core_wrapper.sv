module htable_core_wrapper
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[95:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 16384},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 4,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  STASH_SIZE = 16
)(
    input  logic            clk,
    input  logic            srst,
    output logic            init_done,
    db_info_intf.peripheral info_if,
    db_ctrl_intf.peripheral ctrl_if,
    db_intf.responder       lookup_if,
    db_intf.responder       update_if,
    db_ctrl_intf.peripheral stash_ctrl_if,
    db_status_intf.peripheral stash_status_if,
    db_ctrl_intf.peripheral tbl_ctrl_if [NUM_TABLES]
);
    // ----------------------------------
    // Signals
    // ----------------------------------
    logic  init_done;

    KEY_T  lookup_key;
    hash_t lookup_hash [NUM_TABLES];
    KEY_T  update_key;
    hash_t update_hash [NUM_TABLES];

    logic tbl_init      [NUM_TABLES];
    logic tbl_init_done [NUM_TABLES];

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) tbl_wr_if [NUM_TABLES] (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) tbl_rd_if [NUM_TABLES] (.clk(clk));

    // ----------------------------------
    // Base instantiation
    // ----------------------------------
    htable_multi_stash_core #(
        .KEY_T               ( KEY_T ),
        .VALUE_T             ( VALUE_T ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( TABLE_SIZE ),
        .STASH_SIZE          ( STASH_SIZE ),
        .HASH_LATENCY        ( HASH_LATENCY ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) i_htable_core (
        .*
    );
    
    // ----------------------------------
    // Storage (on-chip) instantiation
    // ----------------------------------
    generate
        for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl
            // Local (parameters)
            localparam int HASH_WID = $clog2(TABLE_SIZE[g_tbl]);
            localparam type HASH_T = logic[HASH_WID-1:0];

            db_store_array  #(
                .KEY_T       ( HASH_T ),
                .VALUE_T     ( VALUE_T ),
                .TRACK_VALID ( 1 )
            ) i_db_store_array (
                .clk       ( clk ),
                .srst      ( srst ),
                .init      ( tbl_init     [g_tbl] ),
                .init_done ( tbl_init_done[g_tbl] ),
                .db_wr_if  ( tbl_wr_if    [g_tbl] ),
                .db_rd_if  ( tbl_rd_if    [g_tbl] )
            );
        end : g__tbl
    endgenerate

    // ----------------------------------
    // Hash implementation
    // ----------------------------------
    assign update_hash[0] = update_key[95:64];
    assign update_hash[1] = update_key[63:32];
    assign update_hash[2] = update_key[31:0];

    assign lookup_hash[0] = lookup_key[95:64];
    assign lookup_hash[1] = lookup_key[63:32];
    assign lookup_hash[2] = lookup_key[31:0];

endmodule : htable_core_wrapper
