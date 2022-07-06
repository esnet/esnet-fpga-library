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

module fifo_async #(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 32,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    // Derived parameters (don't override)
    parameter int  CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1),
    // Debug parameters
    parameter bit DEBUG_ILA = 1'b0
) (
    // Write interface
    input  logic               wr_clk,
    input  logic               wr_srst,
    input  logic               wr,
    input  DATA_T              wr_data,

    // Read interface
    input  logic               rd_clk,
    input  logic               rd_srst,
    input  logic               rd,
    output logic               rd_ack,
    output DATA_T              rd_data,

    // Status
    output logic [CNT_WID-1:0] wr_count,
    output logic [CNT_WID-1:0] rd_count,
    output logic               full,
    output logic               empty,

    output logic               oflow,
    output logic               uflow
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic [CNT_WID-1:0] __wr_count;
    logic [CNT_WID-1:0] __rd_count;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf axil_if__unused ();

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_core #(
        .DATA_T ( DATA_T ),
        .DEPTH  ( DEPTH ),
        .ASYNC  ( 1 ),
        .FWFT   ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT ),
        .AXIL_IF    ( 0 ),
        .DEBUG_ILA  ( DEBUG_ILA )
    ) i_fifo_core (
        .wr_clk   ( wr_clk ),
        .wr_srst  ( wr_srst ),
        .wr       ( wr ),
        .wr_data  ( wr_data ),
        .wr_count ( __wr_count ),
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( rd_clk ),
        .rd_srst  ( rd_srst ),
        .rd       ( rd ),
        .rd_ack   ( rd_ack ),
        .rd_data  ( rd_data ),
        .rd_count ( __rd_count ),
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .axil_if  ( axil_if__unused )
    );

    initial wr_count = 0;
    always @(posedge wr_clk) begin
        if (wr_srst) wr_count <= 0;
        else         wr_count <= __wr_count;
    end
   
    initial rd_count = 0;
    always @(posedge rd_clk) begin
        if (rd_srst) rd_count <= 0;
        else         rd_count <= __rd_count;
    end
   
    // Tie off (unused AXI-L interface)
    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if(axil_if__unused));
    
endmodule : fifo_async
