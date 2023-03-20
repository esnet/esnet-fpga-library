module db_store_lru #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  SIZE = 8
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
    localparam int  IDX_WID = SIZE > 1 ? $clog2(SIZE) : 1;
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

    logic rd_match;
    idx_t rd_idx;

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

    initial stash_vld = '0;
    always @(posedge clk) begin
        if (__srst) stash_vld <= '0;
        else if (db_wr_if.req && db_wr_if.rdy) begin
            for (int i = 1; i < SIZE; i++) begin
                stash_vld[i] <= stash_vld[i-1];
            end
            stash_vld[0] <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (db_wr_if.req && db_wr_if.rdy) begin
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
        if (db_wr_if.req && db_wr_if.rdy) db_wr_if.ack <= 1'b1;
        else                        db_wr_if.ack <= 1'b0;
    end
    assign db_wr_if.error = 1'b0;
    assign db_wr_if.next_key = '0; // Unused

    // ----------------------------------
    // Cache read logic
    // ----------------------------------
    assign db_rd_if.rdy = db_init_done;

    // Search for match to read key
    always_comb begin
        rd_idx = '0;
        rd_match = 1'b0;
        for (int i = SIZE-1; i >= 0; i--) begin
            if (stash_vld[i] && (stash[i].key == db_rd_if.key) && !db_rd_if.next) begin
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
    always_ff @(posedge clk) begin
        db_rd_if.valid <= rd_match ? stash[rd_idx].valid : 1'b0;
        db_rd_if.value <= rd_match ? stash[rd_idx].value : '0;
    end
    assign db_rd_if.error = 1'b0;
    assign db_rd_if.next_key = '0; // Unused

endmodule : db_store_lru
