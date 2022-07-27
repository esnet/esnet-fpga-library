// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Peter Bengough hereinafter the Contractor, under Contract No.
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

module axi4s_ila
(
   axi4s_intf.prb axis_in
);

   (* mark_debug="true" *)  logic [511:0]  tdata  = axis_in.tdata;
   (* mark_debug="true" *)  logic          tvalid = axis_in.tvalid;
   (* mark_debug="true" *)  logic          tlast  = axis_in.tlast;
   (* mark_debug="true" *)  logic [63:0]   tkeep  = axis_in.tkeep;
   (* mark_debug="true" *)  logic          tready = axis_in.tready;

   ila_axi4s ila_axi4s(
     .clk(axis_in.aclk),
     .probe0(tdata),
     .probe1(tvalid),
     .probe2(tlast),
     .probe3(tkeep),
     .probe4(tready)
   );                                                                                                                                                                                                       
endmodule // axi4s_ila
