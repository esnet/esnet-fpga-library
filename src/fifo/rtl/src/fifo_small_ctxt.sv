// Small, synchronous context buffer implementation
// Low latency, low-fanout; targeted at registers or distributed RAM
//
// Single-cycle write-to-read latency makes this block useful
// as a context FIFO for similarly low-latency read operations
// (e.g. a read to an on-chip RAM).
//
// NOTE: this FIFO is only suitable where downstream
//       fanout is low, since rd_data is driven directly
//       from LUTRAMs (not registered). If this is not
//       the case (or unknown) consider using fifo_prefetch
//       instead.
//
module fifo_small_ctxt #(
    parameter type DATA_T = logic[15:0],
    parameter int  DEPTH = 4 // Intended for 'small' FIFOs
                              // Targets distributed RAM; depends on FPGA arch
                              // (typical max is 256, assuming LUT6 + F7/F8 Muxes)
) (
    // Clock/reset
    input  logic        clk,
    input  logic        srst,

    // Write interface
    input  logic        wr,
    output logic        wr_rdy,
    input  DATA_T       wr_data,

    // Read interface
    input  logic        rd,
    output logic        rd_vld,
    output DATA_T       rd_data,

    // Status
    output logic        oflow,
    output logic        uflow
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int CTXT_DEPTH = DEPTH + 1; // Allow for simultaneous write/read during steady-state operation

    // -----------------------------
    // Signals
    // -----------------------------
    logic __full;
    logic __empty;

    // -----------------------------
    // Base FIFO
    // -----------------------------
    fifo_small     #(
        .DATA_T     ( DATA_T ),
        .DEPTH      ( CTXT_DEPTH )
    ) i_fifo_small (
        .clk,
        .srst,
        .wr,
        .wr_data,
        .full     ( __full ),
        .oflow,
        .rd,
        .rd_data,
        .empty    ( __empty ),
        .uflow,
        .count    ( )
    );

    assign wr_rdy = !__full;
    assign rd_vld = !__empty;

endmodule : fifo_small_ctxt
