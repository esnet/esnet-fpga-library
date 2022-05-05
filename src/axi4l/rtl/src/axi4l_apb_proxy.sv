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

module axi4l_apb_proxy (
    axi4l_intf.peripheral axi4l_if,
    apb_intf.controller   apb_if
);
    // Standard register interface
    reg_intf reg_if ();

    // Register-indirect proxy interface
    // - terminates AXI-L with memory window supporting register-indirect
    //   access into a (potentially much larger) memory space mapped on
    //   the APB interface
    reg_proxy i_reg_proxy (
        .axil_if ( axi4l_if ),
        .reg_if  ( reg_if )
    );

    // APB controller
    // - map register control interface to downstream APB interface
    apb_controller i_apb_controller (
        .reg_if   ( reg_if ),
        .apb_if   ( apb_if )
    );

endmodule : axi4l_apb_proxy
