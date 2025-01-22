module fifo_ctrl_fsm
    import fifo_pkg::*;
#(
    parameter int DEPTH = 256,
    parameter bit ASYNC = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    parameter opt_mode_t WR_OPT_MODE = OPT_MODE_TIMING,
    parameter opt_mode_t RD_OPT_MODE = OPT_MODE_TIMING,
    // Derived parameters (don't override)
    parameter int PTR_WID = DEPTH > 1 ? $clog2(DEPTH) : 1,
    parameter int CNT_WID = $clog2(DEPTH+1)
) (
    // Write side
    input  logic               wr_clk,
    input  logic               wr_srst,
    output logic               wr_rdy,
    input  logic               wr,
    output logic               wr_safe,
    output logic [PTR_WID-1:0] wr_ptr,
    output logic [CNT_WID-1:0] wr_count,
    output logic               wr_full,
    output logic               wr_oflow,

    // Read side
    input  logic               rd_clk,
    input  logic               rd_srst,
    input  logic               rd,
    output logic               rd_safe,
    output logic [PTR_WID-1:0] rd_ptr,
    output logic [CNT_WID-1:0] rd_count,
    output logic               rd_empty,
    output logic               rd_uflow,

    // Memory ready
    input  logic               mem_rdy
);
    // -----------------------------
    // Signals
    // -----------------------------
    logic [CNT_WID-1:0] _wr_ptr;
    logic [CNT_WID-1:0] _rd_ptr;

    logic [CNT_WID-1:0] _wr_count;
    logic [CNT_WID-1:0] _rd_count;

    // -----------------------------
    // Write-side logic
    // -----------------------------
    assign wr_safe = OFLOW_PROT ? (wr && wr_rdy) : wr;

    initial _wr_ptr = 0;
    always @(posedge wr_clk) begin
        if (wr_srst)      _wr_ptr <= 0;
        else if (wr_safe) _wr_ptr <= _wr_ptr + 1;
    end

    assign wr_ptr = _wr_ptr % DEPTH;
    assign wr_oflow = wr && !wr_rdy;

    // -----------------------------
    // Read-side logic
    // -----------------------------
    assign rd_safe = UFLOW_PROT ? (rd && !rd_empty) : rd;

    initial _rd_ptr = 0;
    always @(posedge rd_clk) begin
        if (rd_srst)      _rd_ptr <= 0;
        else if (rd_safe) _rd_ptr <= _rd_ptr + 1;
    end

    assign rd_ptr = _rd_ptr % DEPTH;
    assign rd_uflow = rd && rd_empty;

    // -----------------------------
    // Count + empty/full logic
    // -----------------------------
    generate
        if (ASYNC) begin : g__async
            // (Local) signals
            logic [CNT_WID-1:0] _rd_ptr__wr_clk;
            logic [CNT_WID-1:0] _wr_ptr__rd_clk;

            // pointer synchronization
            sync_ctr #( .DATA_T(logic [CNT_WID-1:0]), .RST_VALUE(0), .DECODE_OUT(1) ) sync_wr_ptr
            (
               .clk_in       ( wr_clk ),
               .rst_in       ( wr_srst ),
               .cnt_in       ( _wr_ptr ),
               .clk_out      ( rd_clk ),
               .rst_out      ( rd_srst ),
               .cnt_out      ( _wr_ptr__rd_clk )
            );

            sync_ctr #( .DATA_T(logic [CNT_WID-1:0]), .RST_VALUE(0), .DECODE_OUT(1) ) sync_rd_ptr
            (
               .clk_in       ( rd_clk ),
               .rst_in       ( rd_srst ),
               .cnt_in       ( _rd_ptr ),
               .clk_out      ( wr_clk ),
               .rst_out      ( wr_srst ),
               .cnt_out      ( _rd_ptr__wr_clk )
            );

            assign _wr_count = _wr_ptr - _rd_ptr__wr_clk;
            assign _rd_count = _wr_ptr__rd_clk - _rd_ptr;
        end : g__async

        else begin : g__sync
            assign _wr_count = _wr_ptr - _rd_ptr;
            assign _rd_count = _wr_ptr - _rd_ptr;
        end : g__sync
    endgenerate
 
    generate
        if (WR_OPT_MODE == fifo_pkg::OPT_MODE_TIMING) begin : g__wr_opt_timing
            // wr_count/full update immediately on writes, one cycle delay on reads (write-safe)
            initial wr_count = 0;
            always @(posedge wr_clk) begin
                if (wr_srst)      wr_count <= 0;
                else if (wr_safe) wr_count <= _wr_count + 1;
                else              wr_count <= _wr_count;
            end
            initial wr_full = 0;
            always @(posedge wr_clk) begin
                if (wr_srst)      wr_full <= 1'b0;
                else if (wr_safe) wr_full <= (_wr_count >= DEPTH - 1);
                else              wr_full <= (_wr_count == DEPTH);
            end
            initial wr_rdy = 1'b0;
            always @(posedge wr_clk) begin
                if (wr_srst || !mem_rdy) wr_rdy <= 1'b0;
                else  if (wr_safe)       wr_rdy <= (_wr_count < DEPTH - 1);
                else                     wr_rdy <= (_wr_count < DEPTH);
            end
        end : g__wr_opt_timing
        else begin : g__wr_opt_latency
            // wr_count/full always updated immediately
            assign wr_count = _wr_count;
            assign wr_full = (wr_count == DEPTH);
            assign wr_rdy = mem_rdy && (wr_count < DEPTH);
        end : g__wr_opt_latency
        if (RD_OPT_MODE == fifo_pkg::OPT_MODE_TIMING) begin : g__rd_opt_timing
            // rd_count/empty updates immediately on reads, one cycle delay on writes (read-safe)
            initial rd_count = 0;
            always @(posedge rd_clk) begin
                if (rd_srst)      rd_count <= 0;
                else if (rd_safe) rd_count <= _rd_count - 1;
                else              rd_count <= _rd_count;
            end
            initial rd_empty = 1;
            always @(posedge rd_clk) begin
                if (rd_srst)      rd_empty <= 1'b1;
                else if (rd_safe) rd_empty <= (_rd_count <= 1);
                else              rd_empty <= (_rd_count == 0);
            end
        end : g__rd_opt_timing
        else begin : g__rd_opt_latency
            assign rd_count = _rd_count;
            assign rd_empty = (rd_count == 0);
        end : g__rd_opt_latency
    endgenerate
   
endmodule : fifo_ctrl_fsm
