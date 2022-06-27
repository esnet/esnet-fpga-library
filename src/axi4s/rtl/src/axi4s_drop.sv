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

// -----------------------------------------------------------------------------
// axi4s_drop is used to drop packets from the egress packet stream when the
// drop_pkt signal is asserted.  All egress packet words between the asseertion
// of the drop_pkt signal and the last ingress pkt word are dropped.
// -----------------------------------------------------------------------------

module axi4s_drop
   import axi4s_pkg::*;
( 
   axi4s_intf.rx    axi4s_in,
   axi4s_intf.tx    axi4s_out,

   input logic drop_pkt
);

   logic drop_pkt_latch, drop;

   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn)                                         drop_pkt_latch <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready && axi4s_in.tlast) drop_pkt_latch <= '0;
      else if (drop_pkt)                                             drop_pkt_latch <= '1;

   assign drop = drop_pkt || drop_pkt_latch;

   // axis4s in interface signalling.
   assign axi4s_in.tready = axi4s_out.tready || drop;

   // axis4s out interface signalling.
   assign axi4s_out.aclk    = axi4s_in.aclk;
   assign axi4s_out.aresetn = axi4s_in.aresetn;
   assign axi4s_out.tvalid  = axi4s_in.tvalid && !drop;
   assign axi4s_out.tvalid  = axi4s_in.tvalid;
   assign axi4s_out.tdata   = axi4s_in.tdata;
   assign axi4s_out.tkeep   = axi4s_in.tkeep;
   assign axi4s_out.tlast   = axi4s_in.tlast;
   assign axi4s_out.tid     = axi4s_in.tid;
   assign axi4s_out.tdest   = axi4s_in.tdest;
   assign axi4s_out.tuser   = axi4s_in.tuser;

endmodule // axi4s_drop
