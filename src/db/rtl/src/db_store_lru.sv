module db_store_lru #(
    parameter int  SIZE = 8,
    parameter bit  WRITE_FLOW_THROUGH = 0 // When set, enable write-through mode
                   // In write-through mode, writes are immediately reflected
                   // on the read interface. When there is a simultaneous write and read to the
                   // same key, the read result will reflect the written value (write first).
                   //
                   // In the default (registered) mode, writes are reflected on the following
                   // cycle, such that on a simultaneous write and read to the same key, the
                   // read result will reflect the previous stored value (read first). This is
                   // expected to be the desired functionality for most applications.
                   //
                   // Write-through mode might be useful e.g. when implementing RMW operations
                   // where one of the read or write interfaces is registered in an upstream component.
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              db_init,
    output logic              db_init_done,

    // Database write/read interfaces
    db_intf.responder         db_wr_if,
    db_intf.responder         db_rd_if
);

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int KEY_WID = db_wr_if.KEY_WID;
    localparam int VALUE_WID = db_wr_if.VALUE_WID;

    localparam int IDX_WID = $clog2(SIZE+1);
    localparam int FILL_WID = $clog2(SIZE+1);

    // Check
    initial begin
        std_pkg::param_check(db_rd_if.KEY_WID,   KEY_WID,   "db_rd_if.KEY_WID");
        std_pkg::param_check(db_rd_if.VALUE_WID, VALUE_WID, "db_rd_if.VALUE_WID");
    end

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {logic [KEY_WID-1:0] key; logic valid; logic [VALUE_WID-1:0] value;} entry_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic __srst;

    logic stash_wr;
    logic stash_rd;
    entry_t stash [SIZE];
    logic [SIZE-1:0] stash_vld;

    logic                 rd_slot_match [SIZE+1];
    logic [VALUE_WID-1:0] rd_slot_value [SIZE+1];
    logic                 rd_slot_valid [SIZE+1];

    logic                 rd_match;
    logic [IDX_WID-1:0]   rd_idx;
    logic                 rd_req;
    logic [KEY_WID-1:0]   rd_key;
    logic                 rd_next;

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

    // ----------------------------------
    // Cache write logic
    // ----------------------------------
    assign db_wr_if.rdy = db_init_done;

    assign stash_wr = db_wr_if.req && db_wr_if.rdy;

    initial stash_vld = '0;
    always @(posedge clk) begin
        if (__srst) stash_vld <= '0;
        else if (stash_wr) begin
            for (int i = 1; i < SIZE; i++) begin
                stash_vld[i] <= stash_vld[i-1];
            end
            stash_vld[0] <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (stash_wr) begin
            for (int i = 1; i < SIZE; i++) begin
                stash[i] <= stash[i-1];
            end
            stash[0].key   <= db_wr_if.key;
            stash[0].valid <= db_wr_if.valid;
            stash[0].value <= db_wr_if.value;
        end
    end

    // Write response
    initial db_wr_if.ack = 1'b0;
    always @(posedge clk) begin
        if (__srst)        db_wr_if.ack <= 1'b0;
        else if (stash_wr) db_wr_if.ack <= 1'b1;
        else               db_wr_if.ack <= 1'b0;
    end
    assign db_wr_if.error = 1'b0;
    assign db_wr_if.next_key = '0; // Unused

    // ----------------------------------
    // Cache read logic
    // ----------------------------------
    assign db_rd_if.rdy = db_init_done;

    assign stash_rd = db_rd_if.req && db_rd_if.rdy;

    initial rd_req = 1'b0;
    always @(posedge clk) begin
        if (srst) rd_req <= 1'b0;
        else      rd_req <= stash_rd;
    end

    always_ff @(posedge clk) begin
        rd_key  <= db_rd_if.key;
        rd_next <= db_rd_if.next;
    end

    // Search for match to read key (two-cycle process)
    // - first cycle: check for match in each slot
    always @(posedge clk) begin
        rd_slot_match[0] <= WRITE_FLOW_THROUGH ? stash_wr && (db_rd_if.key == db_wr_if.key) && !db_rd_if.next : 0;
        for (int i = 1; i < SIZE+1; i++) begin
            rd_slot_match[i] <= stash_vld[i-1] && (stash[i-1].key == db_rd_if.key);
            rd_slot_valid[i] <= stash[i-1].valid;
            rd_slot_value[i] <= stash[i-1].value;
        end
    end
    assign rd_slot_valid[0] = stash[0].valid;
    assign rd_slot_value[0] = stash[0].value;

    // - second cycle: return (most-recently-inserted) match
    always_comb begin
        rd_idx = '0;
        rd_match = 1'b0;
        for (int i = SIZE; i >= 0; i--) begin
            if (rd_slot_match[i]) begin
                rd_match = 1'b1;
                rd_idx = i;
            end
        end
    end

    // Read response
    initial db_rd_if.ack = 1'b0;
    always @(posedge clk) begin
        if (__srst) db_rd_if.ack <= 1'b0;
        else        db_rd_if.ack <= rd_req;
    end

    // Read result
    always_ff @(posedge clk) begin
        db_rd_if.valid <= rd_match ? rd_slot_valid[rd_idx] : 1'b0;
        db_rd_if.value <= rd_match ? rd_slot_value[rd_idx] : '0;
        if (WRITE_FLOW_THROUGH) begin
            if (stash_wr && (db_wr_if.key == rd_key) && !rd_next) begin
                db_rd_if.valid <= db_wr_if.valid;
                db_rd_if.value <= db_wr_if.value;
            end
        end
    end
    assign db_rd_if.error = 1'b0;
    assign db_rd_if.next_key = '0; // Unused
 
endmodule : db_store_lru
