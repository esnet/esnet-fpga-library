module db_stash_lru #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  SIZE = 8
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,

    // Status interface
    db_status_intf.peripheral status_if,

    // Read/write interfaces (from application)
    db_intf.responder         app_wr_if,
    db_intf.responder         app_rd_if
);

    // ----------------------------------
    // Imports
    // ----------------------------------
    import db_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int  CNT_WID = $clog2(SIZE+1);

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic __srst;

    logic db_init;
    logic db_init_done;

    logic [CNT_WID-1:0] count;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_rd_if (.clk(clk));

    // ----------------------------------
    // Export status
    // ----------------------------------
    assign status_if.evt_activate = db_wr_if.req && db_wr_if.rdy;
    assign status_if.evt_deactivate = db_wr_if.req && db_wr_if.rdy && (count == SIZE);
    assign status_if.fill = count;
    assign status_if.empty = (count == 0);
    assign status_if.full = (count == SIZE);

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = DB_TYPE_STASH;
    assign info_if.subtype = DB_STASH_TYPE_LRU;
    assign info_if.size = SIZE;

    // ----------------------------------
    // 'Standard' database core
    // ----------------------------------
    db_core #(
        .KEY_T ( KEY_T ),
        .VALUE_T ( VALUE_T ),
        .NUM_WR_TRANSACTIONS ( 2 ),
        .NUM_RD_TRANSACTIONS ( 2 ),
        .DB_CACHE_EN ( 0 ),
        .APP_CACHE_EN ( 0 ) // No caching; writes/reads are executed in one cycle
    ) i_db_core (
        .*
    );

    // ----------------------------------
    // LRU cache implementation
    // ----------------------------------
    db_store_lru #(
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T ),
        .SIZE    ( SIZE )
    ) i_db_cache_lru (
        .srst ( __srst ),
        .*
    );

    // ----------------------------------
    // Maintain count
    // ----------------------------------
    initial count = '0;
    always @(posedge clk) begin
        if (srst || db_init) count <= '0;
        else if (db_wr_if.req && db_wr_if.rdy && (count < SIZE)) count <= count + 1;
    end

endmodule : db_stash_lru
