// Stash implementation of database
// - lookup returns first entry with matching key
// - updates (writes) either overwrite existing entry with matching key (if it exists)
//   or insert into the next available slot
//   or fail if the stash is full
module db_stash #(
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
    localparam int  KEY_WID = ctrl_if.KEY_WID;
    localparam int  VALUE_WID = ctrl_if.VALUE_WID;

    localparam int  IDX_WID = SIZE > 1 ? $clog2(SIZE) : 1;
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
    typedef struct packed {logic [KEY_WID-1:0] key; logic [VALUE_WID-1:0] value;} entry_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    entry_t stash [SIZE];
    logic [SIZE-1:0] stash_vld;

    logic [FILL_WID-1:0]  fill;

    logic                 db_init;
    logic                 db_init_done;

    logic                 wr_req;
    logic [KEY_WID-1:0]   wr_key;
    logic                 wr_valid;
    logic [VALUE_WID-1:0] wr_value;
    logic                 wr;
    logic                 wr_match;
    logic [IDX_WID-1:0]   wr_match_idx;
    logic [IDX_WID-1:0]   insert_idx;
    logic [IDX_WID-1:0]   wr_idx;

    logic                 rd_req;
    logic [KEY_WID-1:0]   rd_key;
    logic                 rd_next;
    logic                 rd_match;
    logic [IDX_WID-1:0]   rd_match_idx;

    logic [IDX_WID-1:0]   next_rd_idx;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) db_wr_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) db_rd_if (.clk);

    // ----------------------------------
    // Export info
    // ----------------------------------
    assign info_if._type = db_pkg::DB_TYPE_STASH;
    assign info_if.subtype = db_pkg::DB_STASH_TYPE_STANDARD;
    assign info_if.size = SIZE;

    // ----------------------------------
    // Export status
    // ----------------------------------
    assign status_if.fill = fill;
    assign status_if.empty = (fill == 0);
    assign status_if.full = (fill == SIZE);
    assign status_if.evt_activate = wr && !wr_match && db_wr_if.valid;
    assign status_if.evt_deactivate = wr && wr_match && !db_wr_if.valid;

    // ----------------------------------
    // 'Standard' database core
    // ----------------------------------
    db_core #(
        .NUM_WR_TRANSACTIONS ( 2 ),
        .NUM_RD_TRANSACTIONS ( 2 ),
        .DB_CACHE_EN ( 0 ), // Caching not required; read result takes into account any preceding writes
        .APP_CACHE_EN ( 0 )
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

    initial wr_req = 1'b0;
    always @(posedge clk) begin
        if (srst) wr_req <= 1'b0;
        else      wr_req <= db_wr_if.req && db_wr_if.rdy;
    end

    always_ff @(posedge clk) begin
        wr_valid <= db_wr_if.valid;
        wr_key   <= db_wr_if.key;
        wr_value <= db_wr_if.value;
    end

    // Search for match to write key
    always_ff @(posedge clk) begin
        if (wr_match && db_wr_if.key == wr_key) begin
            wr_match <= 1'b1;
            wr_match_idx <= wr_match_idx;
        end else begin
            wr_match <= 1'b0;
            for (int i = 0; i < SIZE; i++) begin
                if (stash[i].key == db_wr_if.key) begin
                    wr_match <= 1'b1;
                    wr_match_idx <= i;
                end
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
        if (wr_req) begin
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
        else if (wr)         stash_vld[wr_idx] <= wr_valid;
    end

    always_ff @(posedge clk) begin
        if (wr) begin
            stash[wr_idx].key <= wr_key;
            stash[wr_idx].value <= wr_value;
        end
    end

    // Write response
    initial begin
        db_wr_if.ack = 1'b0;
        db_wr_if.error = 1'b0;
    end
    always @(posedge clk) begin
        if (wr_req) begin
            db_wr_if.ack <= 1'b1;
            db_wr_if.error <= wr_valid && !wr;
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
    // Stash read logic
    // ----------------------------------
    assign db_rd_if.rdy = db_init_done;

    initial rd_req = 1'b0;
    always @(posedge clk) begin
        if (srst) rd_req <= 1'b0;
        else      rd_req <= db_rd_if.req && db_rd_if.rdy;
    end

    always_ff @(posedge clk) begin
        rd_key  <= db_rd_if.key;
        rd_next <= db_rd_if.next;
    end

    // Search for match to read key
    always_ff @(posedge clk) begin
        rd_match <= 1'b0;
        rd_match_idx <= '0;
        if (wr_match && db_rd_if.key == wr_key) begin
            rd_match <= 1'b1;
            rd_match_idx <= wr_match_idx;
        end else begin
            rd_match <= 1'b0;
            for (int i = 0; i < SIZE; i++) begin
                if (stash[i].key == db_rd_if.key) begin
                    rd_match <= 1'b1;
                    rd_match_idx <= i;
                end
            end
        end
    end
    
    // Next iterator
    initial next_rd_idx = 0;
    always @(posedge clk) begin
        if (srst || db_init) next_rd_idx <= 0;
        else if (rd_req && rd_next) begin
            if (next_rd_idx == SIZE-1) next_rd_idx <= 0;
            else                       next_rd_idx <= next_rd_idx + 1;
        end
    end

    // Read response
    always_ff @(posedge clk) begin
        db_rd_if.ack     <= rd_req;
        db_rd_if.valid   <= rd_next ? stash_vld[next_rd_idx]   : rd_match ? stash_vld[rd_match_idx]   : 1'b0;
        db_rd_if.value   <= rd_next ? stash[next_rd_idx].value : rd_match ? stash[rd_match_idx].value : '0;
        db_rd_if.next_key <= rd_next ? stash[next_rd_idx].key : '0;
    end
    assign db_rd_if.error = 1'b0;

endmodule : db_stash
