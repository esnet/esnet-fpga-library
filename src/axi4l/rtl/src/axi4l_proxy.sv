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

module axi4l_proxy (
    axi4l_intf.peripheral  axi4l_if_from_controller,
    axi4l_intf.controller  axi4l_if_to_peripheral
);
    // Imports
    import axi4l_pkg::*;

    // Standard register interface
    reg_intf reg_if ();

    // Register-indirect proxy interface
    // - terminates AXI-L with memory window supporting register-indirect
    //   access into a (potentially much larger) memory space mapped on
    //   the APB interface
    reg_proxy i_reg_proxy (
        .axil_if ( axi4l_if_from_controller ),
        .reg_if  ( reg_if )
    );

    // AXI-L controller
    // - map register control interface to downstream AXI-L interface
    resp_t wr_resp;
    resp_t rd_resp;

    assign reg_if.wr_error = wr_resp == RESP_OKAY ? 1'b0 : 1'b1;
    assign reg_if.rd_error = rd_resp == RESP_OKAY ? 1'b0 : 1'b1;

    axi4l_controller i_axi4l_controller (
        .clk      ( reg_if.clk ),
        .srst     ( reg_if.srst ),
        .wr       ( reg_if.wr ),
        .wr_addr  ( reg_if.wr_addr ),
        .wr_data  ( reg_if.wr_data ),
        .wr_strb  ( reg_if.wr_byte_en ),
        .wr_ack   ( reg_if.wr_ack ),
        .wr_resp  ( wr_resp ),
        .rd       ( reg_if.rd ),
        .rd_addr  ( reg_if.rd_addr ),
        .rd_data  ( reg_if.rd_data ),
        .rd_ack   ( reg_if.rd_ack ),
        .rd_resp  ( rd_resp ),
        .axi4l_if ( axi4l_if_to_peripheral )
    );

endmodule : axi4l_proxy
