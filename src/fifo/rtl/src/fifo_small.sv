// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

// Small, synchronous FIFO implementation, with single-cycle write-to-read latency
module fifo_small #(
    parameter type DATA_T = logic[15:0],
    parameter int  DEPTH = 4 // Intended for 'small' FIFOs
                             // Targets distributed RAM; depends on FPGA arch
                             // (typical max == 256),
) (
    // Clock/reset
    input  logic        clk,
    input  logic        srst,

    // Write interface
    input  logic        wr,
    input  DATA_T       wr_data,
    output logic        full,
    output logic        oflow,

    // Read interface
    input  logic        rd,
    output DATA_T       rd_data,
    output logic        empty,
    output logic        uflow
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PTR_WID = DEPTH > 1 ? $clog2(DEPTH) : 1;

    // -----------------------------
    // Signals
    // -----------------------------
    DATA_T mem [DEPTH];

    logic                 wr_safe;
    logic [PTR_WID-1:0]   wr_ptr;

    logic [PTR_WID-1:0]   rd_ptr;

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
        .UFLOW_PROT ( 1 )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr       ( wr ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( wr_ptr ),
        .wr_count ( ),
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
        .axil_if  ( axil_if__unused )
    );

    // Write
    always_ff @(posedge clk) begin
        if (wr_safe) mem[wr_ptr] <= wr_data;
    end

    // Read
    assign rd_data = mem[rd_ptr];

endmodule : fifo_small
