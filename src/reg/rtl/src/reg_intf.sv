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

interface reg_intf #(
    parameter int ADDR_WID = 32,
    parameter int DATA_BYTE_WID = 4
) ();
    // Clock/reset
    logic                          clk;
    logic                          srst;

    // Write
    logic                          wr;
    logic [ADDR_WID-1:0]           wr_addr;
    logic [DATA_BYTE_WID-1:0][7:0] wr_data;
    logic [DATA_BYTE_WID-1:0]      wr_byte_en;
    logic                          wr_ack;
    logic                          wr_error;

    // Read
    logic                          rd;
    logic [ADDR_WID-1:0]           rd_addr;
    logic [DATA_BYTE_WID-1:0][7:0] rd_data;
    logic                          rd_ack;
    logic                          rd_error;

    modport controller (
        output clk,
        output srst,
        output wr,
        output wr_addr,
        output wr_data,
        output wr_byte_en,
        input  wr_ack,
        input  wr_error,
        output rd,
        output rd_addr,
        input  rd_data,
        input  rd_ack,
        input  rd_error
    );

    modport peripheral (
        input  clk,
        input  srst,
        input  wr,
        input  wr_addr,
        input  wr_data,
        input  wr_byte_en,
        output wr_ack,
        output wr_error,
        input  rd,
        input  rd_addr,
        output rd_data,
        output rd_ack,
        output rd_error
    );

endinterface : reg_intf
