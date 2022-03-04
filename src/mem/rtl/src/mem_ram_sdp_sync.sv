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

// (Synchronous) Simple Dual-Port RAM
module mem_ram_sdp_sync
    import mem_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit RESET_FSM = 0,
    parameter bit [DATA_WID-1:0] RESET_VAL = '0,
    parameter bit SIM__FAST_INIT = 0 // Optimize sim time
) (
    // Clock/reset
    input logic            clk,
    input logic            srst,

    // Init status
    output logic           init_done,

    // Write interface
    mem_intf.wr_peripheral mem_wr_if,

    // Read interface
    mem_intf.rd_peripheral mem_rd_if
);

    // Base memory implementation
    mem_ram_sdp_core   #(
        .DATA_WID       ( DATA_WID ),
        .ADDR_WID       ( ADDR_WID ),
        .ASYNC          ( 0 ),
        .RESET_FSM      ( RESET_FSM ),
        .RESET_VAL      ( RESET_VAL ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_sdp_sync_core (
        // Write interface
        .wr_clk    ( clk ),
        .wr_srst   ( srst ),
        .mem_wr_if ( mem_wr_if ),
        // Read interface
        .rd_clk    ( clk ),
        .rd_srst   ( srst ),
        .mem_rd_if ( mem_rd_if ),
        // Init status
        .init_done ( init_done )
    );

endmodule : mem_ram_sdp_sync
