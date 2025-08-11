// -----------------------------------------------------------------------------
// axi4s_mux is used to multiplex packets from separate ingress axi4s interfaces
// onto a single egress axi4s interface.  It uses the 'arb_rr' component (in WCRR
// mode) to arbitrate between the ingress axi4s interfaces.
// -----------------------------------------------------------------------------

module axi4s_mux #(
   parameter int   N = 2    // number of ingress axi4s interfaces.
 ) (
   axi4s_intf.rx    axi4s_in[N],
   axi4s_intf.tx    axi4s_out
);
   localparam int DATA_BYTE_WID = axi4s_out.DATA_BYTE_WID;
   localparam int TID_WID       = axi4s_out.TID_WID;
   localparam int TDEST_WID     = axi4s_out.TDEST_WID;
   localparam int TUSER_WID     = axi4s_out.TUSER_WID;

   logic aclk;
   logic aresetn;

   assign aclk = axi4s_out.aclk;
   assign aresetn = axi4s_out.aresetn;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) axi4s_in_p[N] (.*);
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) axi4s_out_p (.*);

   logic [N-1:0] axi4s_in_req;
   logic [N-1:0] axi4s_in_grant;
   logic [N-1:0] axi4s_in_ack;

   logic [$clog2(N)-1:0] sel;

/*
   // axi4s interface mux instance.
   axi4s_intf_mux #(
      .N             (N),
      .DATA_BYTE_WID (DATA_BYTE_WID),
      .TID_T         (TID_T),
      .TDEST_T       (TDEST_T),
      .TUSER_T       (TUSER_T)
   ) axi4s_intf_mux_0 (
      .axi4s_in_if   (axi4s_in_p),
      .axi4s_out_if  (axi4s_out_p),
      .sel           (sel)
   );
*/

   // --- flatten axi4s_intf_mux instance to work around a Vivado elaboration failure (missing port?).
   logic                          tvalid[N];
   logic [DATA_BYTE_WID-1:0][7:0] tdata[N];
   logic [DATA_BYTE_WID-1:0]      tkeep[N];
   logic                          tlast[N];
   logic [TID_WID-1:0]            tid[N];
   logic [TDEST_WID-1:0]          tdest[N];
   logic [TUSER_WID-1:0]          tuser[N];

   logic                          tready[N];

   // Convert between array of signals and array of interfaces
   generate
       for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
           axi4s_tready_pipe in_pipe (.from_tx(axi4s_in[g_if]), .to_rx(axi4s_in_p[g_if]));

           assign  tvalid[g_if] = axi4s_in_p[g_if].tvalid;
           assign   tdata[g_if] = axi4s_in_p[g_if].tdata;
           assign   tkeep[g_if] = axi4s_in_p[g_if].tkeep;
           assign   tlast[g_if] = axi4s_in_p[g_if].tlast;
           assign     tid[g_if] = axi4s_in_p[g_if].tid;
           assign   tdest[g_if] = axi4s_in_p[g_if].tdest;
           assign   tuser[g_if] = axi4s_in_p[g_if].tuser;

           assign axi4s_in_p[g_if].tready = (sel == g_if) ? axi4s_out_p.tready : 1'b0;
       end
   endgenerate

   always_comb begin
       // mux logic
       axi4s_out_p.tvalid  = tvalid  [sel];
       axi4s_out_p.tlast   = tlast   [sel];
       axi4s_out_p.tkeep   = tkeep   [sel];
       axi4s_out_p.tdata   = tdata   [sel];
       axi4s_out_p.tid     = tid     [sel];
       axi4s_out_p.tdest   = tdest   [sel];
       axi4s_out_p.tuser   = tuser   [sel];
   end
   // --- end flatten.


   // req logic (signals valid data) and ack logic (signals last pkt byte).
   generate
       for (genvar g_req = 0; g_req < N; g_req++) begin : g__req
           assign axi4s_in_req[g_req] = axi4s_in_p[g_req].tvalid;
           assign axi4s_in_ack[g_req] = axi4s_in_p[g_req].tvalid && axi4s_in_p[g_req].tlast && axi4s_in_p[g_req].tready;
       end
   endgenerate

   // arbitrate between axi4s ingress interfaces (work-conserving round-robin mode).
   arb_rr #(.MODE(arb_pkg::WCRR), .N(N)) arb_rr_0 (
    .clk   (  axi4s_out.aclk ),
    .srst  ( ~axi4s_out.aresetn ),
    .en    (  1'b1 ),
    .req   (  axi4s_in_req ),
    .grant (  axi4s_in_grant ),
    .ack   (  axi4s_in_ack ),
    .sel   (  sel )
   );

   axi4s_full_pipe out_pipe (.from_tx(axi4s_out_p), .to_rx(axi4s_out));

endmodule // axi4s_mux
