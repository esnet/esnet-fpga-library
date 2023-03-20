module db_stash_fifo #(
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
    localparam int  IDX_WID = SIZE > 1 ? $clog2(SIZE) : 1;
    localparam int  CNT_WID = $clog2(SIZE+1);
    localparam int  FILL_WID = $clog2(SIZE+1);
    localparam type ENTRY_T = struct packed {KEY_T key; logic valid; VALUE_T value;};

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef logic [IDX_WID-1:0] idx_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic __srst;

    ENTRY_T stash [SIZE];
    logic [SIZE-1:0] stash_vld;

    logic db_init;
    logic db_init_done;

    logic rd_match;
    idx_t rd_idx;

    logic wr_safe;
    logic full;
    logic [CNT_WID-1:0] count; 

    logic rd_safe;
    idx_t rd_ptr;
    logic empty;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    axi4l_intf #() fifo_ctrl_fsm_axil_if__unused ();

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_rd_if (.clk(clk));

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
        .axil_if  ( fifo_ctrl_fsm_axil_if__unused )
    );

    // Terminate unused AXI-L interface
    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if (fifo_ctrl_fsm_axil_if__unused));

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
        if (db_wr_if.req && db_wr_if.rdy) db_wr_if.ack <= 1'b1;
        else                              db_wr_if.ack <= 1'b0;
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

    // Search for match to read key
    always_comb begin
        rd_idx = '0;
        rd_match = 1'b0;
        for (int i = SIZE-1; i >= 0; i--) begin
            if (stash_vld[i] && (stash[i].key == db_rd_if.key)) begin
                rd_match = 1'b1;
                rd_idx = i;
            end
        end
    end

    // Read response
    initial db_rd_if.ack = 1'b0;
    always @(posedge clk) begin
        if (__srst)                            db_rd_if.ack <= 1'b0;
        else if (db_rd_if.req && db_rd_if.rdy) db_rd_if.ack <= 1'b1;
        else                                   db_rd_if.ack <= 1'b0;
    end

    assign rd_ptr = count - 1;

    always_ff @(posedge clk) begin
        if (db_rd_if.next) begin
            db_rd_if.valid    <= stash[rd_ptr].valid;
            db_rd_if.value    <= stash[rd_ptr].value;
            db_rd_if.next_key <= stash[rd_ptr].key;
            db_rd_if.error    <= empty;
        end else begin
            db_rd_if.valid    <= rd_match ? stash[rd_idx].valid : 1'b0;
            db_rd_if.value    <= rd_match ? stash[rd_idx].value : '0;
            db_rd_if.error    <= 1'b0;
            db_rd_if.next_key <= '0;
        end
    end

endmodule : db_stash_fifo
