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
// axi4s_copy is used to replicate a packet stream.  It copies the packet stream 
// received on the ingress axi4s interface to two egress axi4s interfaces.
// Both ports have to be ready, so one egress port can block the other.
// -----------------------------------------------------------------------------

module axi4s_copy
  import axi4s_pkg::*;
( 
  axi4s_intf.rx       axi4s_in,
  axi4s_intf.tx       axi4s_out,
  axi4s_intf.tx       axi4s_cp_out
);

   // axis4s input interface signalling.
   assign axi4s_in.tready = axi4s_out.tready;

   // axis4s output interface signalling.
   assign axi4s_out.aclk   = axi4s_in.aclk;
   assign axi4s_out.aresetn= axi4s_in.aresetn;
   assign axi4s_out.tvalid = axi4s_in.tvalid;
   assign axi4s_out.tdata  = axi4s_in.tdata;
   assign axi4s_out.tkeep  = axi4s_in.tkeep;
   assign axi4s_out.tlast  = axi4s_in.tlast;
   assign axi4s_out.tid    = axi4s_in.tid;
   assign axi4s_out.tdest  = axi4s_in.tdest;
   assign axi4s_out.tuser  = axi4s_in.tuser;

   // axis4s copy interface signalling.
   assign axi4s_cp_out.aclk   = axi4s_in.aclk;
   assign axi4s_cp_out.aresetn= axi4s_in.aresetn;
   assign axi4s_cp_out.tvalid = axi4s_in.tvalid && axi4s_in.tready;
   assign axi4s_cp_out.tdata  = axi4s_in.tdata;
   assign axi4s_cp_out.tkeep  = axi4s_in.tkeep;
   assign axi4s_cp_out.tlast  = axi4s_in.tlast;
   assign axi4s_cp_out.tid    = axi4s_in.tid;
   assign axi4s_cp_out.tdest  = axi4s_in.tdest;
   assign axi4s_cp_out.tuser  = axi4s_in.tuser;

endmodule // axi4s_copy
