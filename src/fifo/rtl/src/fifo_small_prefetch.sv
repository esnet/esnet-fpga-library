// Small, synchronous prefetch buffer implementation
// Low latency, low-fanout; targeted at registers or distributed RAM
//
// NOTE: this FIFO will attempt to prefetch entries (by
//       asserting wr_rdy) as long as there is a headroom
//       of >= PIPELINE_DEPTH entries.
//
//       Can be used to implement memory read prefetch
//       buffers, interface pipelining stages, etc.
//
// NOTE: this FIFO is only suitable where downstream
//       fanout is low, since rd_data is driven directly
//       from LUTRAMs (not registered). If this is not
//       the case (or unknown) consider using fifo_prefetch
//       instead.
//
module fifo_small_prefetch #(
    parameter int DATA_WID = 1,
    parameter int PIPELINE_DEPTH = 1 // Specify the depth of the prefetch pipeline;
                                      // This represents the (minimum) number of writes
                                      // supported without overflow *after* deassertion of wr_rdy.
                                      // This implementation is intended for 'small' buffers,
                                      // typically <= 32
) (
    // Clock/reset
    input  logic                clk,
    input  logic                srst,

    // Write interface
    input  logic                wr,
    output logic                wr_rdy, // Ready to receive data; accounts for available slots in FIFO,
                                        // plus in-flight transactions
    input  logic [DATA_WID-1:0] wr_data,

    // Read interface
    input  logic                rd,
    output logic                rd_vld,
    output logic [DATA_WID-1:0] rd_data,

    output logic                oflow  // NOTE: this does not assert when wr && !wr_rdy; instead,
                                       //       it asserts if a write cannot be received into the
                                       //       fifo. This could occur after some number of pipeline
                                       //       stages on the write interface, for example.

);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DEPTH = PIPELINE_DEPTH * 2;
    localparam int CNT_WID = $clog2(DEPTH+1);
    localparam int PIPELINE_CNT_WID = $clog2(PIPELINE_DEPTH+1);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check_lt(PIPELINE_DEPTH, 64, "PIPELINE_DEPTH");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    logic __empty;
    logic [CNT_WID-1:0] __count;
    logic [PIPELINE_CNT_WID-1:0] __reserved_slots;
    logic [PIPELINE_DEPTH-1:0] __empty_vec;

    // -----------------------------
    // Base FIFO
    // -----------------------------
    fifo_small     #(
        .DATA_WID   ( DATA_WID ),
        .DEPTH      ( DEPTH )
    ) i_fifo_small  (
        .clk,
        .srst,
        .wr,
        .wr_data,
        .full      ( ),
        .oflow,
        .rd,
        .rd_data,
        .empty     ( __empty ),
        .uflow     ( ),
        .count     ( __count )
    );

    assign rd_vld = !__empty;

    // Maintain record of outstanding transactions
    initial __empty_vec = '0;
    always @(posedge clk) begin
        if (srst) __empty_vec <= '0;
        else      __empty_vec <= (__empty_vec << 1) | !wr_rdy;
    end

    assign __reserved_slots = PIPELINE_DEPTH - math_pkg::vec#(PIPELINE_DEPTH)::count_ones(__empty_vec);

    // Synthesize wr_rdy (account for potential outstanding transactions)
    assign wr_rdy = (__count + __reserved_slots) < DEPTH;

endmodule : fifo_small_prefetch
