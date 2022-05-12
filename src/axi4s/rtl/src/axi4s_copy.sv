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
  axi4s_intf.tx       axi4s_out0,
  axi4s_intf.tx       axi4s_out1
);

   // axis4s input interface signalling.
   assign axi4s_in.tready = axi4s_out0.tready & axi4s_out1.tready;

   // axis4s output 0 interface signalling.
   assign axi4s_out0.aclk   = axi4s_in.aclk;
   assign axi4s_out0.aresetn= axi4s_in.aresetn;
   assign axi4s_out0.tvalid = axi4s_in.tvalid && axi4s_in.tready;
   assign axi4s_out0.tdata  = axi4s_in.tdata;
   assign axi4s_out0.tkeep  = axi4s_in.tkeep;
   assign axi4s_out0.tlast  = axi4s_in.tlast;
   assign axi4s_out0.tid    = axi4s_in.tid;
   assign axi4s_out0.tdest  = axi4s_in.tdest;
   assign axi4s_out0.tuser  = axi4s_in.tuser;

   // axis4s output 1 interface signalling.
   assign axi4s_out1.aclk   = axi4s_in.aclk;
   assign axi4s_out1.aresetn= axi4s_in.aresetn;
   assign axi4s_out1.tvalid = axi4s_in.tvalid && axi4s_in.tready;
   assign axi4s_out1.tdata  = axi4s_in.tdata;
   assign axi4s_out1.tkeep  = axi4s_in.tkeep;
   assign axi4s_out1.tlast  = axi4s_in.tlast;
   assign axi4s_out1.tid    = axi4s_in.tid;
   assign axi4s_out1.tdest  = axi4s_in.tdest;
   assign axi4s_out1.tuser  = axi4s_in.tuser;

endmodule // axi4s_copy
