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

module axi4l_apb_bridge (
    axi4l_intf.peripheral axi4l_if,
    apb_intf.controller   apb_if
);
    // Standard register interface
    reg_intf #(.DATA_BYTE_WID(axi4l_if.DATA_BYTE_WID), .ADDR_WID(axi4l_if.ADDR_WID)) reg_if ();

    // AXI-L register peripheral
    // - map downstream control interface to standard register
    //   interface for interacting with register block endpoints
    axi4l_reg_peripheral i_axi4l_reg_peripheral (
        .axi4l_if ( axi4l_if ),
        .reg_if   ( reg_if )
    );

    // APB controller
    // - map register control interface to downstream APB interface
    apb_controller i_apb_controller (
        .reg_if   ( reg_if ),
        .apb_if   ( apb_if )
    );

endmodule : axi4l_apb_bridge
