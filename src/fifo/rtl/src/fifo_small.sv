// Small, synchronous, FWFT FIFO implementation, with single-cycle write-to-read latency
//
// NOTE: this FIFO is only suitable where downstream fanout is low,
//       since rd_data is driven directly from LUTRAMs (not registered).
//       If this is not the case (or unknown) use fifo_sync instead.
//
module fifo_small #(
    parameter int DATA_WID = 1,
    parameter int DEPTH = 32, // Intended for 'small' FIFOs
                              // Targets distributed RAM; depends on FPGA arch
                              // (typical max is 256, assuming LUT6 + F7/F8 Muxes)
    // Simulation-only parameters
    parameter bit REPORT_OFLOW = 0,
    parameter bit REPORT_UFLOW = 0,
    // Derived parameters (don't override)
    parameter int CNT_WID = $clog2(DEPTH + 1)
) (
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    // Write interface
    input  logic                wr,
    input  logic [DATA_WID-1:0] wr_data,
    output logic                full,
    output logic                oflow,

    // Read interface
    input  logic                rd,
    output logic [DATA_WID-1:0] rd_data,
    output logic                empty,
    output logic                uflow,

    output logic [CNT_WID-1:0]  count
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PTR_WID = DEPTH > 1 ? $clog2(DEPTH) : 1;
    localparam int MEM_DEPTH = 2**PTR_WID;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check_lt(MEM_DEPTH, 256, "MEM_DEPTH");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    logic [DATA_WID-1:0] mem [MEM_DEPTH];

    logic                wr_safe;
    logic [PTR_WID-1:0]  wr_ptr;

    logic [PTR_WID-1:0]  rd_ptr;

    // -----------------------------
    // Control FSM
    // -----------------------------
    fifo_ctrl_fsm  #(
        .DEPTH      ( DEPTH ),
        .ASYNC      ( 0 ),
        .OFLOW_PROT ( 1 ),
        .UFLOW_PROT ( 1 ),
        .WR_OPT_MODE( fifo_pkg::OPT_MODE_LATENCY ),
        .RD_OPT_MODE( fifo_pkg::OPT_MODE_LATENCY ),
        .REPORT_OFLOW ( REPORT_OFLOW ),
        .REPORT_UFLOW ( REPORT_UFLOW )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy   ( ),
        .wr       ( wr ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( wr_ptr ),
        .wr_count ( count ),
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd       ( rd ),
        .rd_safe  ( ),
        .rd_ptr   ( rd_ptr ),
        .rd_count ( ),
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .mem_rdy  ( 1'b1 )
    );

    // Write
    always_ff @(posedge clk) begin
        if (wr_safe) mem[wr_ptr] <= wr_data;
    end

    // Read
    assign rd_data = mem[rd_ptr];

endmodule : fifo_small
