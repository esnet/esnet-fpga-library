module db_stash_fifo #(
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
    localparam int  KEY_WID = ctrl_if.KEY_WID;
    localparam int  VALUE_WID = ctrl_if.VALUE_WID;

    localparam int  IDX_WID = SIZE > 1 ? $clog2(SIZE) : 1;
    localparam int  CNT_WID = $clog2(SIZE+1);
    localparam int  FILL_WID = $clog2(SIZE+1);

    // Check
    initial begin
        std_pkg::param_check(app_wr_if.KEY_WID,   KEY_WID,   "app_wr_if.KEY_WID");
        std_pkg::param_check(app_wr_if.VALUE_WID, VALUE_WID, "app_wr_if.VALUE_WID");
        std_pkg::param_check(app_rd_if.KEY_WID,   KEY_WID,   "app_rd_if.KEY_WID");
        std_pkg::param_check(app_rd_if.VALUE_WID, VALUE_WID, "app_rd_if.VALUE_WID");
    end

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {logic [KEY_WID-1:0] key; logic valid; logic [VALUE_WID-1:0] value;} entry_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic __srst;

    entry_t stash [SIZE];
    logic [SIZE-1:0] stash_vld;

    logic               db_init;
    logic               db_init_done;

    logic [SIZE-1:0]      rd_slot_match;
    logic                 rd_slot_valid [SIZE];
    logic [VALUE_WID-1:0] rd_slot_value [SIZE];
    logic                 rd_match;
    logic [IDX_WID-1:0]   rd_idx;

    logic                 rd_head_valid;
    logic [VALUE_WID-1:0] rd_head_value;
    logic [KEY_WID-1:0]   rd_head_key;
    logic                 rd_head_empty;

    logic               db_rd_d [2];
    logic               db_rd_next;

    logic               wr_safe;
    logic               full;
    logic [CNT_WID-1:0] count; 

    logic               rd_safe;
    logic [IDX_WID-1:0] rd_ptr;
    logic               empty;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) db_wr_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) db_rd_if (.clk);

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = DB_TYPE_STASH;
    assign info_if.subtype = DB_STASH_TYPE_FIFO;
    assign info_if.size = SIZE;

    // ----------------------------------
    // Export status
    // ----------------------------------
    assign status_if.evt_activate = wr_safe;
    assign status_if.evt_deactivate = rd_safe;
    assign status_if.fill = count;
    assign status_if.empty = empty;
    assign status_if.full = full;

    // ----------------------------------
    // 'Standard' database core
    // ----------------------------------
    db_core #(
        .NUM_WR_TRANSACTIONS ( 1 ),
        .NUM_RD_TRANSACTIONS ( 2 ),
        .DB_CACHE_EN ( 0 ), // Caching not required; read result takes into account any preceding writes
        .APP_CACHE_EN ( 0 )
    ) i_db_core (
        .*
    );

    // ----------------------------------
    // Local reset
    // ----------------------------------
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || db_init) __srst <= 1'b1;
        else                 __srst <= 1'b0;
    end

    // ----------------------------------
    // Init done
    // ----------------------------------
    initial db_init_done = 1'b0;
    always @(posedge clk) begin
        if (__srst) db_init_done <= 1'b0;
        else        db_init_done <= 1'b1;
    end

    // -----------------------------
    // FIFO controller
    // -----------------------------
    fifo_ctrl_fsm  #(
        .DEPTH      ( SIZE ),
        .ASYNC      ( 0 ),
        .OFLOW_PROT ( 1 ),
        .UFLOW_PROT ( 1 )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( clk ),
        .wr_srst  ( __srst ),
        .wr_rdy   ( ),
        .wr       ( db_wr_if.req && db_wr_if.rdy && !db_wr_if.next ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( ),
        .wr_count ( count ),
        .wr_full  ( full ),
        .wr_oflow ( ),
        .rd_clk   ( clk ),
        .rd_srst  ( __srst ),
        .rd       ( db_wr_if.req && db_wr_if.rdy && db_wr_if.next ),
        .rd_safe  ( rd_safe ),
        .rd_ptr   ( ),
        .rd_count ( ),
        .rd_empty ( empty ),
        .rd_uflow ( ),
        .mem_rdy  ( db_init_done )
    );

    // ----------------------------------
    // Cache write logic
    // - write next entry to tail of FIFO
    // ----------------------------------
    assign db_wr_if.rdy = db_init_done;

    initial stash_vld = '0;
    always @(posedge clk) begin
        if (__srst) stash_vld <= '0;
        else if (wr_safe) begin
            for (int i = 1; i < SIZE; i++) begin
                stash_vld[i] <= stash_vld[i-1];
            end
            stash_vld[0] <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rd_safe) begin
            stash[rd_ptr].valid <= db_wr_if.valid;
            stash[rd_ptr].key   <= db_wr_if.key;
            stash[rd_ptr].value <= db_wr_if.value;
        end else if (wr_safe) begin
            for (int i = 1; i < SIZE; i++) begin
                stash[i] <= stash[i-1];
            end
            stash[0].valid <= db_wr_if.valid;
            stash[0].key   <= db_wr_if.key;
            stash[0].value <= db_wr_if.value;
        end
    end

    // Write response
    initial db_wr_if.ack = 1'b0;
    always @(posedge clk) begin
        if (__srst)                            db_wr_if.ack <= 1'b0;
        else if (db_wr_if.req && db_wr_if.rdy) db_wr_if.ack <= 1'b1;
        else                                   db_wr_if.ack <= 1'b0;
    end
    always_ff @(posedge clk) begin
        if (db_wr_if.next) db_wr_if.error <= empty;
        else               db_wr_if.error <= full;
    end

    assign db_wr_if.next_key = '0; // Unused

    // ----------------------------------
    // Cache read logic
    // ----------------------------------
    assign db_rd_if.rdy = init_done;

    // Read response pipeline (read latency is 2 cycles)
    initial db_rd_d = '{default: 1'b0};
    always @(posedge clk) begin
        if (__srst) db_rd_d <= '{default: 1'b0};
        else begin
            db_rd_d[0] <= db_rd_if.req && db_rd_if.rdy;
            db_rd_d[1] <= db_rd_d[0];
        end
    end
    assign db_rd_if.ack = db_rd_d[1];

    // Read context
    always_ff @(posedge clk) db_rd_next <= db_rd_if.next;

    // Search for match to read key (two-cycle process)
    // - first cycle: check for match in each slot
    always @(posedge clk) begin
        for (int i = 0; i < SIZE; i++) begin
            rd_slot_match[i] <= stash_vld[i] && (stash[i].key == db_rd_if.key);
            rd_slot_valid[i] <= stash[i].valid;
            rd_slot_value[i] <= stash[i].value;
        end
    end
    // - second cycle: return (most-recently-inserted) match
    always_comb begin
        rd_idx = '0;
        rd_match = 1'b0;
        for (int i = SIZE-1; i >= 0; i--) begin
            if (rd_slot_match[i]) begin
                rd_match = 1'b1;
                rd_idx = i;
            end
        end
    end

    assign rd_ptr = count - 1;

    // Perform read of FIFO head element (implement as two-cycle process)
    always_ff @(posedge clk) begin
        rd_head_valid <= stash[rd_ptr].valid;
        rd_head_value <= stash[rd_ptr].value;
        rd_head_key   <= stash[rd_ptr].key;
        rd_head_empty <= empty;
    end

    always_ff @(posedge clk) begin
        if (db_rd_next) begin
            db_rd_if.valid    <= rd_head_valid;
            db_rd_if.value    <= rd_head_value;
            db_rd_if.next_key <= rd_head_key;
            db_rd_if.error    <= rd_head_empty;
        end else begin
            db_rd_if.valid    <= rd_match ? rd_slot_valid[rd_idx] : 1'b0;
            db_rd_if.value    <= rd_match ? rd_slot_value[rd_idx] : '0;
            db_rd_if.error    <= 1'b0;
            db_rd_if.next_key <= '0;
        end
    end

endmodule : db_stash_fifo
