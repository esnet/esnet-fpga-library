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

module reg_rd_evt #(
    parameter type T = bit[31:0],
    parameter T INIT_VALUE = 0
)(
    input  logic clk,
    input  logic srst,
    input  logic upd_en,
    input  T     upd_data,
    output T     rd_data,
    input  logic rd,
    input  logic rd_en,
    output logic rd_evt
);

    // Implement underlying register as read only
    reg_ro #(.T (T), .INIT_VALUE (INIT_VALUE)) _reg_ro (.*);

    // Synthesize read event strobe
    assign rd_evt = rd && rd_en;

endmodule : reg_rd_evt
