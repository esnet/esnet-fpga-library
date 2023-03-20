module db_stash #(
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
    // Parameters
    // ----------------------------------
    localparam int  IDX_WID = SIZE > 1 ? $clog2(SIZE) : 1;
    localparam int  FILL_WID = $clog2(SIZE+1);
    localparam type ENTRY_T = struct packed {KEY_T key; VALUE_T value;};

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef logic [IDX_WID-1:0] idx_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    ENTRY_T stash [SIZE];
    logic [SIZE-1:0] stash_vld;

    logic [FILL_WID-1:0] fill;

    logic db_init;
    logic db_init_done;

    logic wr;
    logic wr_match;
    idx_t wr_match_idx;
    idx_t insert_idx;
    idx_t wr_idx;

    logic rd_match;
    idx_t rd_idx;

    idx_t next_rd_idx;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_rd_if (.clk(clk));

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_STASH;
    assign info_if.subtype = 0;
    assign info_if.size = SIZE;

    // ----------------------------------
    // Export status
    // ----------------------------------
    assign status_if.fill = fill;
    assign status_if.evt_activate = wr && !wr_match && db_wr_if.valid;
    assign status_if.evt_deactivate = wr && wr_match && !db_wr_if.valid;

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
    // Init done
    // ----------------------------------
    initial db_init_done = 1'b0;
    always @(posedge clk) begin
        if (srst || db_init) db_init_done <= 1'b0;
        else                 db_init_done <= 1'b1;
    end

    // ----------------------------------
    // Stash write logic
    // ----------------------------------
    assign db_wr_if.rdy = db_init_done;

    // Search for match to write key
    always_comb begin
        wr_match = 1'b0;
        wr_match_idx = '0;
        for (int i = 0; i < SIZE; i++) begin
            if (stash[i].key == db_wr_if.key) begin
                wr_match = 1'b1;
                wr_match_idx = i;
            end
        end
    end

    // Determine next available slot
    always_comb begin
        insert_idx = '0;
        for (int i = 0; i < SIZE; i++) begin
            if (!stash_vld[i]) insert_idx = i;
        end
    end

    // Stash write control
    always_comb begin
        wr = 1'b0;
        wr_idx = insert_idx;
        if (db_wr_if.req && db_wr_if.rdy) begin
            if (wr_match) begin
                wr = 1'b1;
                wr_idx = wr_match_idx;
            end else if (fill < SIZE) begin
                wr = 1'b1;
            end
        end
    end

    // Stash write
    initial stash_vld = '0;
    always @(posedge clk) begin
        if (srst || db_init) stash_vld <= '0;
        else if (wr)         stash_vld[wr_idx] <= db_wr_if.valid;
    end

    always_ff @(posedge clk) begin
        if (wr) begin
            stash[wr_idx].key <= db_wr_if.key;
            stash[wr_idx].value <= db_wr_if.value;
        end
    end

    // Write response
    initial begin
        db_wr_if.ack = 1'b0;
        db_wr_if.error = 1'b0;
    end
    always @(posedge clk) begin
        if (db_wr_if.req && db_wr_if.rdy) begin
            db_wr_if.ack <= 1'b1;
            db_wr_if.error <= db_wr_if.valid && !wr; 
        end else begin
            db_wr_if.ack <= 1'b0;
            db_wr_if.error <= 1'b0;
        end
    end
    assign db_wr_if.next_key = '0; // Unused in write direction

    // ----------------------------------
    // Stash fill tracking
    // ----------------------------------
    always_comb begin
        fill = 0;
        for (int i = 0; i < SIZE; i++) begin
            if (stash_vld[i]) fill++;
        end
    end

    // ----------------------------------
    // Next iterator
    // ----------------------------------
    initial next_rd_idx = 0;
    always @(posedge clk) begin
        if (srst) next_rd_idx <= 0;
        else if (db_rd_if.req && db_rd_if.rdy && db_rd_if.next) begin
            if (next_rd_idx == SIZE-1) next_rd_idx <= 0;
            else                       next_rd_idx <= next_rd_idx + 1;
        end
    end

    // ----------------------------------
    // Stash read logic
    // ----------------------------------
    assign db_rd_if.rdy = db_init_done;

    // Search for match to read key
    always_comb begin
        rd_idx = '0;
        rd_match = 1'b0;
        if (db_rd_if.next) begin
            rd_match = 1'b1;
            rd_idx = next_rd_idx;
        end else begin
            for (int i = 0; i < SIZE; i++) begin
                if (stash[i].key == db_rd_if.key) begin
                    rd_match = 1'b1;
                    rd_idx = i;
                end
            end
        end
    end
    
    // Read response
    always_ff @(posedge clk) begin
        db_rd_if.ack <= db_rd_if.req && db_rd_if.rdy;
        db_rd_if.valid <= rd_match ? stash_vld[rd_idx] : 1'b0;
        db_rd_if.value <= rd_match ? stash[rd_idx].value : '0;
        db_rd_if.next_key <= db_rd_if.next ? stash[rd_idx].key : '0;
    end
    assign db_rd_if.error = 1'b0;

endmodule : db_stash
