// -----------------------------------------------------------------------------
// axi4s_drop is used to drop packets from the egress packet stream when the
// drop_pkt signal is asserted.  All egress packet words between the assertion
// of the drop_pkt signal and the last ingress pkt word are dropped.
// -----------------------------------------------------------------------------

module axi4s_drop
   import axi4s_pkg::*;
#(
   parameter axi4s_pipe_mode_t OUT_PIPE_MODE = PULL
 ) (
   input logic      clk,
   input logic      srst,

   axi4s_intf.rx    axi4s_in,
   axi4s_intf.tx    axi4s_out,

   axi4l_intf.peripheral  axil_if,

   input logic drop_pkt
);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int TID_WID       = axi4s_in.TID_WID;
   localparam int TDEST_WID     = axi4s_in.TDEST_WID;
   localparam int TUSER_WID     = axi4s_in.TUSER_WID;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axi4s_in  (.aclk(axi4s_in.aclk));
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) axi4s_out_p (.aclk(axi4s_in.aclk));

   logic drop_pkt_latch, drop;

   always @(posedge clk)
      if (srst)                                                      drop_pkt_latch <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready && axi4s_in.tlast) drop_pkt_latch <= '0;
      else if (drop_pkt)                                             drop_pkt_latch <= '1;

   assign drop = drop_pkt || drop_pkt_latch;

   // axis4s in interface signalling.
   assign axi4s_in.tready = axi4s_out_p.tready || drop;

   // axis4s out interface signalling.
   assign axi4s_out_p.tvalid  = axi4s_in.tvalid && !drop;
   assign axi4s_out_p.tdata   = axi4s_in.tdata;
   assign axi4s_out_p.tkeep   = axi4s_in.tkeep;
   assign axi4s_out_p.tlast   = axi4s_in.tlast;
   assign axi4s_out_p.tid     = axi4s_in.tid;
   assign axi4s_out_p.tdest   = axi4s_in.tdest;
   assign axi4s_out_p.tuser   = axi4s_in.tuser;

   axi4s_intf_pipe #(.MODE(OUT_PIPE_MODE)) out_pipe_0 (.srst, .from_tx(axi4s_out_p), .to_rx(axi4s_out));


   // axi4s drop counter instantiation and signalling.
   assign __axi4s_in.tready = axi4s_in.tready && drop;

   // axis4s out interface signalling.
   assign __axi4s_in.tvalid  = axi4s_in.tvalid;
   assign __axi4s_in.tdata   = axi4s_in.tdata;
   assign __axi4s_in.tkeep   = axi4s_in.tkeep;
   assign __axi4s_in.tlast   = axi4s_in.tlast;
   assign __axi4s_in.tid     = axi4s_in.tid;
   assign __axi4s_in.tdest   = axi4s_in.tdest;
   assign __axi4s_in.tuser   = axi4s_in.tuser;

   axi4s_probe axi4s_drop_count (
      .srst,
      .axi4l_if  (axil_if),
      .axi4s_if  (__axi4s_in)
   );

endmodule // axi4s_drop
