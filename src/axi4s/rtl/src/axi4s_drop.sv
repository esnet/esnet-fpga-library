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
// drop_pkt signal is asserted.  All egress packet words between the assertion
// of the drop_pkt signal and the last ingress pkt word are dropped.
// -----------------------------------------------------------------------------

module axi4s_drop
   import axi4s_pkg::*;
#(
   parameter logic OUT_PIPE = 1
 ) (
   axi4s_intf.rx    axi4s_in,
   axi4s_intf.tx    axi4s_out,

   axi4l_intf.peripheral  axil_if,

   input logic drop_pkt
);

   localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_in.TID_T;
   localparam type TDEST_T       = axi4s_in.TDEST_T;
   localparam type TUSER_T       = axi4s_in.TUSER_T;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axi4s_in  ();
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_out_p ();

   logic drop_pkt_latch, drop;

   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn)                                         drop_pkt_latch <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready && axi4s_in.tlast) drop_pkt_latch <= '0;
      else if (drop_pkt)                                             drop_pkt_latch <= '1;

   assign drop = drop_pkt || drop_pkt_latch;

   // axis4s in interface signalling.
   assign axi4s_in.tready = axi4s_out_p.tready || drop;

   // axis4s out interface signalling.
   assign axi4s_out_p.aclk    = axi4s_in.aclk;
   assign axi4s_out_p.aresetn = axi4s_in.aresetn;
   assign axi4s_out_p.tvalid  = axi4s_in.tvalid && !drop;
   assign axi4s_out_p.tdata   = axi4s_in.tdata;
   assign axi4s_out_p.tkeep   = axi4s_in.tkeep;
   assign axi4s_out_p.tlast   = axi4s_in.tlast;
   assign axi4s_out_p.tid     = axi4s_in.tid;
   assign axi4s_out_p.tdest   = axi4s_in.tdest;
   assign axi4s_out_p.tuser   = axi4s_in.tuser;

   generate
      if (OUT_PIPE)
         axi4s_full_pipe out_pipe_0 (.axi4s_if_from_tx(axi4s_out_p), .axi4s_if_to_rx(axi4s_out));
      else
         axi4s_intf_connector out_intf_connector_0 (.axi4s_from_tx(axi4s_out_p), .axi4s_to_rx(axi4s_out));
   endgenerate



   // axi4s drop counter instantiation and signalling.
   assign __axi4s_in.tready = axi4s_in.tready && drop;

   // axis4s out interface signalling.
   assign __axi4s_in.aclk    = axi4s_in.aclk;
   assign __axi4s_in.aresetn = axi4s_in.aresetn;
   assign __axi4s_in.tvalid  = axi4s_in.tvalid;
   assign __axi4s_in.tdata   = axi4s_in.tdata;
   assign __axi4s_in.tkeep   = axi4s_in.tkeep;
   assign __axi4s_in.tlast   = axi4s_in.tlast;
   assign __axi4s_in.tid     = axi4s_in.tid;
   assign __axi4s_in.tdest   = axi4s_in.tdest;
   assign __axi4s_in.tuser   = axi4s_in.tuser;

   axi4s_probe axi4s_drop_count (
      .axi4l_if  (axil_if),
      .axi4s_if  (__axi4s_in)
   );

endmodule // axi4s_drop
