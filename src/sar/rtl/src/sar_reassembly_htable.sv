module sar_reassembly_htable
    import sar_pkg::*;
#(
    parameter int  KEY_WID = 1,
    parameter int  VALUE_WID = 1,
    parameter int  NUM_ITEMS = 1024,
    parameter int  BURST_SIZE = 8,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              en,

    output logic              init_done,

    // Lookup interface
    db_intf.responder         lookup_if,

    // Update interface
    db_intf.responder         update_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral     axil_if
);
    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int KEY_BITS = KEY_WID;
    localparam int KEY_BYTES = KEY_BITS % 8 == 0 ? KEY_BITS / 8 : KEY_BITS / 8 + 1;

    localparam crc_pkg::crc_config_t CRC_CONFIG[4] = '{
        0 : crc_pkg::CRC32_ISO_HDLC_CFG, // CRC-32
        1 : crc_pkg::CRC32_ISCSI_CFG,    // CRC-32C
        2 : crc_pkg::CRC32_BASE91_D_CFG, // CRC-32D
        3 : crc_pkg::CRC32_AUTOSAR_CFG   //
    };

    // Implement 3-way hash table with capacity equal to 150% of target
    localparam int NUM_TABLES = 3;
    localparam int TABLE_SIZE = NUM_ITEMS/2;

    localparam int HASH_WID = $clog2(TABLE_SIZE);
    localparam type HASH_T = logic[HASH_WID-1:0];

    localparam int NUM_WR_TRANSACTIONS = 8;
    localparam int NUM_RD_TRANSACTIONS = 16;
    
    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef logic [0:KEY_BYTES-1][7:0] __key_t;
   
    typedef struct packed {
        logic [KEY_WID-1:0]   key;
        logic [VALUE_WID-1:0] value;
    } segment_table_entry_t;
    localparam int SEGMENT_TABLE_ENTRY_WID = $bits(segment_table_entry_t);

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    db_info_intf info_if ();
    db_status_intf status_if (.clk, .srst);
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if__axil (.clk);
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __ctrl_if (.clk);

    db_intf #(.KEY_WID($bits(htable_pkg::hash_t)), .VALUE_WID(SEGMENT_TABLE_ENTRY_WID)) tbl_wr_if [NUM_TABLES] (.clk);
    db_intf #(.KEY_WID($bits(htable_pkg::hash_t)), .VALUE_WID(SEGMENT_TABLE_ENTRY_WID)) tbl_rd_if [NUM_TABLES] (.clk);

    axi4l_intf #() axil_if__db ();
    axi4l_intf #() axil_if__htable ();

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic __srst;
    logic __en;

    logic ctrl_reset;
    logic ctrl_en;

    logic tbl_init_done [NUM_TABLES];
    logic tbl_init      [NUM_TABLES];

    // Hashing interface
    logic [KEY_WID-1:0] lookup_key;
    htable_pkg::hash_t  lookup_hash [NUM_TABLES];
    logic [KEY_WID-1:0] ctrl_key    [NUM_TABLES];
    htable_pkg::hash_t  ctrl_hash   [NUM_TABLES];

    __key_t __lookup_key;

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Block-level decoder
    sar_reassembly_htable_decoder i_sar_reassembly_htable_decoder (
        .axil_if        ( axil_if ),
        .htable_axil_if ( axil_if__htable ),
        .db_axil_if     ( axil_if__db )
    );

    // AXI-L control (for debug control/monitoring)
    db_axil_ctrl i_db_axil_ctrl__htable (
        .clk         ( clk ),
        .srst        ( srst ),
        .init_done   ( init_done ),
        .axil_if     ( axil_if__db ),
        .ctrl_reset  ( ctrl_reset ),
        .ctrl_en     ( ctrl_en ),
        .reset_mon   ( __srst ),
        .en_mon      ( __en ),
        .ready_mon   ( init_done ),
        .info_if     ( info_if ),
        .ctrl_if     ( ctrl_if__axil ),
        .status_if   ( status_if )
    );

    // Block reset
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || ctrl_reset) __srst <= 1'b1;
        else                    __srst <= 1'b0;
    end

    // Block enable
    initial __en = 1'b0;
    always @(posedge clk) begin
        if (en && ctrl_en) __en <= 1'b1;
        else               __en <= 1'b0;
    end

    // -------------------------------------------------
    // Mutliplex control access
    // -------------------------------------------------
    db_ctrl_intf_prio_mux  i_db_ctrl_intf_prio_mux (
        .clk                     ( clk ),
        .srst                    ( __srst ),
        .from_controller_hi_prio ( ctrl_if ),
        .from_controller_lo_prio ( ctrl_if__axil ),
        .to_peripheral           ( __ctrl_if )
    );

    // -------------------------------------------------
    // Fragment database
    // -------------------------------------------------
    htable_cuckoo_fast_update_core #(
        .KEY_WID             ( KEY_WID ),
        .VALUE_WID           ( VALUE_WID ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( '{default: TABLE_SIZE} ),
        .HASH_LATENCY        ( 1 ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .UPDATE_BURST_SIZE   ( BURST_SIZE )
    ) i_htable_cuckoo_fast_update_core (
        .clk           ( clk ),
        .srst          ( __srst ),
        .en            ( __en ),
        .init_done     ( init_done ),
        .info_if       ( info_if ),
        .status_if     ( status_if ),
        .ctrl_if       ( __ctrl_if ),
        .axil_if       ( axil_if__htable ),
        .lookup_if     ( lookup_if ),
        .update_if     ( update_if ),
        .lookup_key    ( lookup_key ),
        .lookup_hash   ( lookup_hash ),
        .ctrl_key      ( ctrl_key ),
        .ctrl_hash     ( ctrl_hash ),
        .tbl_init      ( tbl_init ),
        .tbl_init_done ( tbl_init_done ),
        .tbl_wr_if     ( tbl_wr_if ),
        .tbl_rd_if     ( tbl_rd_if )
    );

    // -----------------------------
    // Hash table storage instantiation
    // -----------------------------
    generate
        for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl
            // Hash table memory instance
            db_store_array     #(
                .KEY_WID        ( HASH_WID ),
                .VALUE_WID      ( SEGMENT_TABLE_ENTRY_WID ),
                .SIM__FAST_INIT ( SIM__FAST_INIT )
            ) i_db_store_array  (
                .clk            ( clk ),
                .srst           ( __srst ),
                .init           ( tbl_init     [g_tbl] ),
                .init_done      ( tbl_init_done[g_tbl] ),
                .db_wr_if       ( tbl_wr_if    [g_tbl] ),
                .db_rd_if       ( tbl_rd_if    [g_tbl] )
            );
        end : g__tbl
    endgenerate

    // -----------------------------
    // Calculate hash for lookup key
    // -----------------------------
    // Pad key to bytes
    assign __lookup_key = lookup_key;

    // Calculate independent CRC hash per table
    generate
        for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl_lookup
            crc #(
                .CONFIG     ( CRC_CONFIG[g_tbl] ),
                .DATA_BYTES ( KEY_BYTES )
            ) i_crc   (
                .clk  ( clk ),
                .srst ( 1'b0 ),
                .en   ( 1'b1 ),
                .data ( __lookup_key ),
                .crc  ( lookup_hash[g_tbl] )
            );
        end : g__tbl_lookup
    endgenerate

    // -----------------------------
    // Calculate hash for ctrl key
    // -----------------------------
    generate
        for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl_ctrl
            __key_t __ctrl_key;

            // Pad key to bytes
            assign __ctrl_key = ctrl_key[g_tbl];

            // Calculate independent CRC hash per table
            crc #(
                .CONFIG     ( CRC_CONFIG[g_tbl] ),
                .DATA_BYTES ( KEY_BYTES )
            ) i_crc (
                .clk  ( clk ),
                .srst ( 1'b0 ),
                .en   ( 1'b1 ),
                .data ( __ctrl_key ),
                .crc  ( ctrl_hash[g_tbl] )
            );
        end : g__tbl_ctrl
    endgenerate

endmodule : sar_reassembly_htable
