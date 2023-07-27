// (Asynchronous) Simple Dual-Port RAM
// - Instantiates the mem_ram_sdp_core subcomponent directly, but can
//   leverage pre-defined timing constraints (using mem/build/apply_constraints.tcl)
module mem_ram_sdp_async
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
    // Write interface
    input logic            wr_clk,
    input logic            wr_srst,
    mem_intf.wr_peripheral mem_wr_if,

    // Read interface
    input logic            rd_clk,
    input logic            rd_srst,
    mem_intf.rd_peripheral mem_rd_if,

    // Init status
    output logic           init_done
);

    // Base memory implementation
    mem_ram_sdp_core   #(
        .MEM_RD_MODE    ( MEM_RD_MODE ),
        .ADDR_WID       ( ADDR_WID ),
        .DATA_WID       ( DATA_WID ),
        .ASYNC          ( 1 ),
        .RESET_FSM      ( RESET_FSM ),
        .RESET_VAL      ( RESET_VAL ),
        ._RAM_STYLE     ( _RAM_STYLE ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp_core (
        // Write interface
        .wr_clk    ( wr_clk ),
        .wr_srst   ( wr_srst ),
        .mem_wr_if ( mem_wr_if ),
        // Read interface
        .rd_clk    ( rd_clk ),
        .rd_srst   ( rd_srst ),
        .mem_rd_if ( mem_rd_if ),
        // Init status
        .init_done ( init_done )
    );

endmodule : mem_ram_sdp_async
