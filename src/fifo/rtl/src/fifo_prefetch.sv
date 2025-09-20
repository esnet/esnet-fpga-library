// Synchronous prefetch buffer implementation
//
// NOTE: this FIFO will attempt to prefetch entries (by
//       asserting wr_rdy) as long as there is a headroom
//       of >= PIPELINE_DEPTH entries.
//
//       Can be used to implement memory read prefetch
//       buffers, interface pipelining stages, etc.
//
module fifo_prefetch
    import fifo_pkg::*;
#(
    parameter int DATA_WID = 1,
    parameter int PIPELINE_DEPTH = 1, // Specify the depth of the prefetch pipeline;
                                      // This represents the (minimum) number of writes
                                      // supported without overflow *after* deassertion of wr_rdy.
                                      // This implementation is intended for 'small-ish' prefetch depths,
                                      // typically <= 64
    parameter opt_mode_t WR_OPT_MODE = OPT_MODE_TIMING,
    parameter opt_mode_t RD_OPT_MODE = OPT_MODE_TIMING
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
    localparam int WR_TO_EMPTY_LATENCY = (WR_OPT_MODE == OPT_MODE_TIMING) ? 1 + 1 : 1; // WR -> RD_COUNT + FWFT BUFFER
    localparam int RD_TO_FULL_LATENCY  = (RD_OPT_MODE == OPT_MODE_TIMING) ? 1 : 0; // RD -> WR_COUNT
    localparam int DEPTH = PIPELINE_DEPTH * 2 + 1 + WR_TO_EMPTY_LATENCY + RD_TO_FULL_LATENCY;
    localparam int PTR_WID = $clog2(DEPTH);
    localparam int MEM_DEPTH = 2**PTR_WID;
    localparam int CNT_WID = $clog2(DEPTH+2);
    localparam int PIPELINE_CNT_WID = $clog2(PIPELINE_DEPTH+1);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check_lt(MEM_DEPTH, 256, "DEPTH");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    logic [CNT_WID-1:0]  __count;
    logic [PIPELINE_CNT_WID-1:0] __reserved_slots;
    logic [PIPELINE_DEPTH-1:0] __empty_vec;

    fifo_mon_intf wr_mon_if__unused (.clk);
    fifo_mon_intf rd_mon_if__unused (.clk);

    // -----------------------------
    // Standard FIFO instantiation
    // -----------------------------
    fifo_core       #(
        .DATA_WID    ( DATA_WID ),
        .DEPTH       ( DEPTH ),
        .ASYNC       ( 0 ),
        .FWFT        ( 1 ),
        .OFLOW_PROT  ( 1 ),
        .UFLOW_PROT  ( 1 ),
        .WR_OPT_MODE ( WR_OPT_MODE ),
        .RD_OPT_MODE ( RD_OPT_MODE )
    ) i_fifo_core (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy   ( ),
        .wr       ( wr ),
        .wr_data  ( wr_data ),
        .wr_count ( __count ),
        .wr_full  ( ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd       ( rd ),
        .rd_ack   ( rd_vld ),
        .rd_data  ( rd_data ),
        .rd_count ( ),
        .rd_empty ( ),
        .rd_uflow ( ),
        .wr_mon_if ( wr_mon_if__unused ),
        .rd_mon_if ( rd_mon_if__unused )
    );

    // Maintain record of outstanding transactions
    initial __empty_vec = '0;
    always @(posedge clk) begin
        if (srst) __empty_vec <= '0;
        else      __empty_vec <= (__empty_vec << 1) | !wr_rdy;
    end

    assign __reserved_slots = PIPELINE_DEPTH - math_pkg::vec#(PIPELINE_DEPTH)::count_ones(__empty_vec);

    // Synthesize wr_rdy (account for potential outstanding transactions)
    initial wr_rdy = 1'b0;
    always @(posedge clk) begin
        if (srst) wr_rdy <= 1'b0;
        else      wr_rdy <= (__count + __reserved_slots) < DEPTH-1;
    end

endmodule : fifo_prefetch
