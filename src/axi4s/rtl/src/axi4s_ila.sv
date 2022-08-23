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
   import axi4s_pkg::*;
#(
   parameter axi4s_ila_mode_t MODE = FULL
) (
   axi4s_intf.prb axis_in
);

  (* mark_debug="true" *)  logic [511:0]  tdata;
  (* mark_debug="true" *)  logic          tvalid;
  (* mark_debug="true" *)  logic          tlast;
  (* mark_debug="true" *)  logic [63:0]   tkeep;
  (* mark_debug="true" *)  logic          tready;
  (* mark_debug="true" *)  logic [16:0]   tuser;

  assign tdata  = axis_in.tdata;
  assign tvalid = axis_in.tvalid;
  assign tlast  = axis_in.tlast;
  assign tkeep  = axis_in.tkeep;
  assign tready = axis_in.tready;
  assign tuser  = {'0, axis_in.tuser};

  generate
      if (MODE == FULL) begin : g__full
         ila_axi4s ila_axi4s_0 (
            .clk(axis_in.aclk),
            .probe0(tdata),
            .probe1(tvalid),
            .probe2(tlast),
            .probe3(tkeep),
            .probe4(tready),
            .probe5(tuser));
      end : g__full

      else if (MODE == LITE) begin : g__lite
         ila_axi4s_lite ila_axi4s_lite_0 (
            .clk(axis_in.aclk),
            .probe0(tdata[7:0]),
            .probe1(tvalid),
            .probe2(tlast),
            .probe3(tkeep[0]),
            .probe4(tready),
            .probe5(tuser[0]));
      end : g__lite
   endgenerate

endmodule // axi4s_ila
