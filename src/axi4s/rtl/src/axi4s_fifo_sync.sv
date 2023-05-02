// -----------------------------------------------------------------------------
// Word-based synchronous AXI-S FIFO
// - synchronous word-based (i.e. not packet-aware) FIFO
//   with AXI-S write/read interfaces
// -----------------------------------------------------------------------------

module axi4s_fifo_sync
#(
    parameter int DEPTH = 32,
    parameter fifo_pkg::opt_mode_t FIFO_OPT_MODE = fifo_pkg::OPT_MODE_TIMING

) (
    axi4s_intf.rx axi4s_in,
    axi4s_intf.tx axi4s_out
);
    //----------------------------------------------
    // Imports
    //----------------------------------------------
    import axi4s_pkg::*;

    //----------------------------------------------
    // Parameters
    //----------------------------------------------
    localparam int  DATA_BYTE_WID = axi4s_out.DATA_BYTE_WID;
    localparam type TID_T         = axi4s_out.TID_T;
    localparam type TDEST_T       = axi4s_out.TDEST_T;
    localparam type TUSER_T       = axi4s_out.TUSER_T;
    localparam axi4s_mode_t MODE  = axi4s_out.MODE;
    localparam axi4s_tuser_mode_t TUSER_MODE = axi4s_out.TUSER_MODE;

    //----------------------------------------------
    // Interfaces
    //----------------------------------------------
    axi4s_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .TID_T         ( TID_T ),
        .TDEST_T       ( TDEST_T ),
        .TUSER_T       ( TUSER_T ),
        .MODE          ( MODE ),
        .TUSER_MODE    ( TUSER_MODE )
    ) __axi4s_out ();

    // Drive AXI-S output clock/reset with input clock/reset (synchronous)
    assign __axi4s_out.aclk = axi4s_in.aclk;
    assign __axi4s_out.aresetn = axi4s_in.aresetn;
    
    //----------------------------------------------
    // AXI-S FIFO instance
    //----------------------------------------------
    axi4s_fifo_core       #(
        .DEPTH             ( DEPTH ),
        .ASYNC             ( 0 ),
        .FIFO_OPT_MODE     ( FIFO_OPT_MODE )
    ) i_axi4s_fifo_core    (
        .axi4s_in          ( axi4s_in ),
        .axi4s_out         ( __axi4s_out )
    );

    // Drive output interface (with clock/reset embedded)
    axi4s_intf_connector i_axi4s_intf_connector (
        .axi4s_from_tx       ( __axi4s_out ),
        .axi4s_to_rx         ( axi4s_out )
    );

endmodule : axi4s_fifo_sync
