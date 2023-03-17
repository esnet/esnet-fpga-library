// -----------------------------------------------------------------------------
// axi4s_copy is used to replicate a packet stream on a second output interface.
// Flow control is determined entirely by the primary output interface, and the
// tready signal on the cp_out interface is ignored (i.e. assumed to be always 1).
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
