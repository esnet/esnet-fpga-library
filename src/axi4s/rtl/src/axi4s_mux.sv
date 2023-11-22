// -----------------------------------------------------------------------------
// axi4s_mux is used to multiplex packets from separate ingress axi4s interfaces
// onto a single egress axi4s interface.  It uses the 'arb_rr' component (in WCRR
// mode) to arbitrate between the ingress axi4s interfaces.
// -----------------------------------------------------------------------------

module axi4s_mux
   import axi4s_pkg::*;
   import arb_pkg::*;
#(
   parameter int   N = 2,         // number of ingress axi4s interfaces.
   parameter logic OUT_PIPE = 0
 ) (
   axi4s_intf.rx    axi4s_in [N],
   axi4s_intf.tx    axi4s_out
);

   localparam int  DATA_BYTE_WID = axi4s_out.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_out.TID_T;
   localparam type TDEST_T       = axi4s_out.TDEST_T;
   localparam type TUSER_T       = axi4s_out.TUSER_T;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_out_p ();

   logic axi4s_in_grant [N];
   logic axi4s_in_ack   [N];


   // axi4s interface mux instance.
   axi4s_intf_2to1_mux axi4s_mux_0 (
    .axi4s_in_if_0 (axi4s_in[0]),
    .axi4s_in_if_1 (axi4s_in[1]),
    .axi4s_out_if  (axi4s_out_p),
    .mux_sel       (axi4s_in_grant[1])
   );

   // ack logic for arbiter (signals last pkt byte).
   assign axi4s_in_ack[0] = axi4s_in[0].tvalid && axi4s_in[0].tlast && axi4s_in[0].tready;
   assign axi4s_in_ack[1] = axi4s_in[1].tvalid && axi4s_in[1].tlast && axi4s_in[1].tready;

   // arbitrate between axi4s ingress interfaces (work-conserving round-robin mode).
   arb_rr #(.MODE(WCRR), .N(N)) arb_rr_0 (
    .clk   (  axi4s_out.aclk ),
    .srst  ( ~axi4s_out.aresetn ),
    .en    (  1'b1 ),
    .req   (  {axi4s_in[1].tvalid, axi4s_in[0].tvalid} ),
    .grant (  {axi4s_in_grant[1],  axi4s_in_grant[0]} ),
    .ack   (  {axi4s_in_ack[1],    axi4s_in_ack[0]} )
   );


   generate
      if (OUT_PIPE)
         axi4s_full_pipe out_pipe_0 (.axi4s_if_from_tx(axi4s_out_p), .axi4s_if_to_rx(axi4s_out));
      else
         axi4s_intf_connector out_intf_connector_0 (.axi4s_from_tx(axi4s_out_p), .axi4s_to_rx(axi4s_out));
   endgenerate

endmodule // axi4s_mux
