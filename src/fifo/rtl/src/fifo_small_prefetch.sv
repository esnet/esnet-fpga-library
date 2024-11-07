// Small, synchronous prefetch buffer implementation
// Low latency, targeted at registers or distributed RAM
// 
// NOTE: this FIFO will attempt to prefetch entries (by
//       asserting wr_rdy) as long as there is a headroom
//       of >= PIPELINE_DEPTH entries.
//
//       Can be used to implement memory read prefetch
//       buffers, interface pipelining stages, etc.
//
module fifo_small_prefetch #(
    parameter type DATA_T = logic[15:0],
    parameter int  PIPELINE_DEPTH = 1 // Specify the depth of the prefetch pipeline;
                                      // This represents the (minimum) number of writes
                                      // supported without overflow *after* deassertion of wr_rdy.
                                      // This implementation is intended for 'small' buffers,
                                      // typically <= 128
) (
    // Clock/reset
    input  logic        clk,
    input  logic        srst,

    // Write interface
    input  logic        wr,
    output logic        wr_rdy, // Ready to receive data; can receive PIPELINE_DEPTH
                                // writes after deassertion of wr_rdy
    input  DATA_T       wr_data,
    output logic        oflow,  // An overflow of the prefetch buffer is possible
                                // if the transmitter does not respect the
                                // PIPELINE_DEPTH maximum; this output can be used
                                // to monitor for that scenario

    // Read interface
    input  logic        rd,
    output logic        rd_rdy,
    output DATA_T       rd_data
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PTR_WID = $clog2(2 * (PIPELINE_DEPTH + 1));
    localparam int DEPTH = 2**PTR_WID;
    localparam int CNT_WID = $clog2(DEPTH+1);

    // -----------------------------
    // Signals
    // -----------------------------
    DATA_T mem [DEPTH];

    logic                 wr_safe;
    logic [PTR_WID-1:0]   wr_ptr;

    logic [PTR_WID-1:0]   rd_ptr;

    logic [CNT_WID-1:0]     count;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf #() axil_if__unused ();

    // -----------------------------
    // Control FSM
    // -----------------------------
    fifo_ctrl_fsm  #(
        .DEPTH      ( DEPTH ),
        .ASYNC      ( 0 ),
        .OFLOW_PROT ( 1 ),
        .UFLOW_PROT ( 1 ),
        .WR_OPT_MODE( fifo_pkg::OPT_MODE_LATENCY ),
        .RD_OPT_MODE( fifo_pkg::OPT_MODE_LATENCY )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy   ( ),
        .wr       ( wr ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( wr_ptr ),
        .wr_count ( count ),
        .wr_full  ( ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd       ( rd ),
        .rd_safe  ( ),
        .rd_ptr   ( rd_ptr ),
        .rd_count ( ),
        .rd_empty ( ),
        .rd_uflow ( ),
        .mem_rdy  ( 1'b1 ),
        .axil_if  ( axil_if__unused )
    );

    // Deassert wr_rdy at buffer midpoint
    assign wr_rdy = (count <= DEPTH/2);

    // Write
    always_ff @(posedge clk) begin
        if (wr_safe) mem[wr_ptr] <= wr_data;
    end

    // Read
    assign rd_data = mem[rd_ptr];

    assign rd_rdy = (count > 0);

    // Terminate unused AXI-L interface
    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if (axil_if__unused));

endmodule : fifo_small_prefetch
