module db_stash #(
    parameter int  SIZE = 8,
    parameter bit  REG_REQ = 1'b0 // When enabled, register both write and read requests to stash memory
                                  // Using a common parameter for both write and read sides maintains
                                  // the timing relationship between reads and writes, ensuring that e.g.
                                  // RMW operations return the previous value before the new value takes
                                  // effect.
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
    logic [IDX_WID-1:0]   rd_idx;

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

    // (Optionally) register write request
    generate
        if (REG_REQ) begin : g__wr_req_reg
            always_ff @(posedge clk) begin
                if (db_wr_if.req && db_wr_if.rdy) wr_req <= 1'b1;
                else                              wr_req <= 1'b0;
                wr_key <= db_wr_if.key;
                wr_valid <= db_wr_if.valid;
                wr_value <= db_wr_if.value;
            end
        end : g__wr_req_reg
        else begin : g__wr_req_no_reg
            assign wr_req = db_wr_if.req && db_wr_if.rdy;
            assign wr_key = db_wr_if.key;
            assign wr_valid = db_wr_if.valid;
            assign wr_value = db_wr_if.value;
        end : g__wr_req_no_reg
    endgenerate

    // Search for match to write key
    always_comb begin
        wr_match = 1'b0;
        wr_match_idx = '0;
        for (int i = 0; i < SIZE; i++) begin
            if (stash[i].key == wr_key) begin
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

    // (Optionally) pipeline read request
    generate
        if (REG_REQ) begin : g__rd_req_reg
            always_ff @(posedge clk) begin
                if (db_rd_if.req && db_rd_if.rdy) rd_req <= 1'b1;
                else                              rd_req <= 1'b0;
                rd_key <= db_rd_if.key;
                rd_next <= db_rd_if.next;
            end
        end : g__rd_req_reg
        else begin : g__rd_req_no_reg
            assign rd_req = db_rd_if.req && db_rd_if.rdy;
            assign rd_key = db_rd_if.key;
            assign rd_next = db_rd_if.next;
        end : g__rd_req_no_reg
    endgenerate

    // Search for match to read key
    always_comb begin
        rd_idx = '0;
        rd_match = 1'b0;
        if (rd_next) begin
            rd_match = 1'b1;
            rd_idx = next_rd_idx;
        end else begin
            for (int i = 0; i < SIZE; i++) begin
                if (stash[i].key == rd_key) begin
                    rd_match = 1'b1;
                    rd_idx = i;
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
        db_rd_if.ack <= rd_req;
        db_rd_if.valid <= rd_match ? stash_vld[rd_idx] : 1'b0;
        db_rd_if.value <= rd_match ? stash[rd_idx].value : '0;
        db_rd_if.next_key <= rd_next ? stash[rd_idx].key : '0;
    end
    assign db_rd_if.error = 1'b0;

endmodule : db_stash
