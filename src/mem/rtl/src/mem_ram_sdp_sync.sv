// (Synchronous) Simple Dual-Port RAM
module mem_ram_sdp_sync
    import mem_pkg::*;
#(
    parameter mem_rd_mode_t MEM_RD_MODE = STD,
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit RESET_FSM = 0,
    parameter bit [DATA_WID-1:0] RESET_VAL = '0,
    parameter xilinx_ram_style_t _RAM_STYLE = RAM_STYLE_AUTO,
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
        .MEM_RD_MODE    ( MEM_RD_MODE ),
        .DATA_WID       ( DATA_WID ),
        .ADDR_WID       ( ADDR_WID ),
        .ASYNC          ( 0 ),
        .RESET_FSM      ( RESET_FSM ),
        .RESET_VAL      ( RESET_VAL ),
        ._RAM_STYLE     ( _RAM_STYLE ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp_core (
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
