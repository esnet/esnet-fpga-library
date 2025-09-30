// -----------------------------------------------------------------------------
// axi4s_pkt_fifo_async is a packet-aware asynchronous fifo.  
// It requires a full packet to be buffered ahead of forwarding it out through 
// its egress interface, and it will discard the full packet if a transaction is 
// lost due to fifo overflow.
// -----------------------------------------------------------------------------

module axi4s_pkt_fifo_async #(
   parameter int   FIFO_DEPTH = 256,
   parameter int   MAX_PKT_LEN = 9100,
   parameter int   TX_THRESHOLD = 0,
   parameter bit   IGNORE_TREADY = 0,
   parameter bit   DROP_ERRORED = 0   // when 1, drop 'errored' packets, where error status is carried in lsb of axi4s_in.TUSER
) (
   axi4s_intf.rx   axi4s_in,
   axi4s_intf.tx   axi4s_out,

   input  logic [15:0] flow_ctl_thresh,
   output logic        flow_ctl,

   axi4l_intf.peripheral axil_to_probe,
   axi4l_intf.peripheral axil_to_ovfl,
   axi4l_intf.peripheral axil_if
);
   import axi4s_pkg::*;

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int TDATA_WID     = DATA_BYTE_WID*8;
   localparam int TKEEP_WID     = DATA_BYTE_WID;
   localparam int TID_WID       = axi4s_in.TID_WID;
   localparam int TDEST_WID     = axi4s_in.TDEST_WID;
   localparam int TUSER_WID     = axi4s_in.TUSER_WID;

   // Parameter check
   initial begin
       std_pkg::param_check(axi4s_out.DATA_BYTE_WID, DATA_BYTE_WID, "axi4s_out.DATA_BYTE_WID");
       std_pkg::param_check(axi4s_out.TID_WID,       TID_WID,       "axi4s_out.TID_WID");
       std_pkg::param_check(axi4s_out.TDEST_WID,     TDEST_WID,     "axi4s_out.TDEST_WID");
       std_pkg::param_check(axi4s_out.TUSER_WID,     TUSER_WID,     "axi4s_out.TUSER_WID");
   end

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID))
                 axi4s_in_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID))
                 __axi4s_in (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID))
                 axi4s_to_fifo (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   localparam CNT_WIDTH = $clog2(FIFO_DEPTH);

   // --- fifo_async signals ---
   typedef struct packed {
       logic                 tlast;
       logic [TID_WID-1:0]   tid;
       logic [TDEST_WID-1:0] tdest;
       logic [TUSER_WID-1:0] tuser;
       logic [TKEEP_WID-1:0] tkeep;
       logic [TDATA_WID-1:0] tdata;
   } fifo_data_t;

   logic                wr_rdy;
   logic                wr;
   fifo_data_t          wr_data;
   logic [CNT_WIDTH:0]  wr_count;
   logic                almost_full, full;
   logic                oflow;

   logic                rd;
   fifo_data_t          rd_data;
   logic [CNT_WIDTH:0]  rd_count;
   logic                empty;
   logic                uflow;

   logic                pkt_empty;
   logic                pkt_ready;

   localparam DATA_WIDTH = $size(wr_data);
   localparam PKT_DISCARD_DEPTH = $ceil($itor(MAX_PKT_LEN) / $itor(DATA_BYTE_WID)) * 3; // axi4s_pkt_discard_ovfl buffers 3 max pkts.
   localparam FIFO_ASYNC_DEPTH = FIFO_DEPTH;
   localparam ALMOST_FULL_THRESH = 4;


   // --- axi4s_pkt_discard_ovfl instantiation (if IGNORE_TREADY mode is enabled) ---
   generate
      if (IGNORE_TREADY) begin : g__pkt_discard_ovfl
         axi4s_intf_pipe axi4s_in_pipe (.from_tx(axi4s_in), .to_rx(axi4s_in_p));

         // connector drives axi4s_in.tready to 1'b1 when in IGNORE_TREADY mode.
         axi4s_intf_connector #(.IGNORE_TREADY(1)) axi4s_in_connector (
            .from_tx (axi4s_in_p),
            .to_rx   (__axi4s_in)
         );

         axi4s_probe axi4s_probe (
            .axi4l_if  (axil_to_probe),
            .axi4s_if  (__axi4s_in)
         );

         axi4s_probe #( .MODE(OVFL) ) axi4s_ovfl (
            .axi4l_if  (axil_to_ovfl),
            .axi4s_if  (__axi4s_in)
         );

         axi4s_pkt_discard_ovfl #(
             .MAX_PKT_LEN  (MAX_PKT_LEN),
             .DROP_ERRORED (DROP_ERRORED)
         ) axi4s_pkt_discard_ovfl_0 (
             .axi4s_in  (__axi4s_in),
             .axi4s_out (axi4s_to_fifo)
         );

         assign axi4s_to_fifo.tready = !almost_full && wr_rdy;
         assign wr = axi4s_to_fifo.tvalid;
      end : g__pkt_discard_ovfl

      else begin : g__no_pkt_discard_ovfl
         axi4s_intf_connector axi4s_in_connector (
             .from_tx (axi4s_in),
             .to_rx   (axi4s_to_fifo)
         );

         axi4s_probe axi4s_probe (
            .axi4l_if  (axil_to_probe),
            .axi4s_if  (axi4s_to_fifo)
         );

         axi4l_intf_peripheral_term axi4l_to_ovfl_peripheral_term (.axi4l_if(axil_to_ovfl));

         assign axi4s_to_fifo.tready = !full && wr_rdy;
         assign wr = axi4s_to_fifo.tvalid && axi4s_to_fifo.tready;
      end : g__no_pkt_discard_ovfl

   endgenerate



   // --- fifo_async signaling ---
   assign wr_data.tuser = axi4s_to_fifo.tuser;
   assign wr_data.tlast = axi4s_to_fifo.tlast;
   assign wr_data.tid   = axi4s_to_fifo.tid;
   assign wr_data.tdest = axi4s_to_fifo.tdest;
   assign wr_data.tkeep = axi4s_to_fifo.tkeep;
   assign wr_data.tdata = axi4s_to_fifo.tdata;

   assign almost_full = wr_count > (FIFO_ASYNC_DEPTH - ALMOST_FULL_THRESH);
   assign flow_ctl    = wr_count > flow_ctl_thresh;

   assign rd = axi4s_out.tvalid && axi4s_out.tready;

   
   // --- fifo_async instantiation ---
   fifo_axil_async #(
      .DATA_WID  ($bits(fifo_data_t)),
      .DEPTH     (FIFO_ASYNC_DEPTH),
      .FWFT      (1)
   ) fifo_async_0 (
      .wr_clk    ( axi4s_to_fifo.aclk ),
      .wr_srst   (~axi4s_to_fifo.aresetn ),
      .wr_rdy    ( wr_rdy ),
      .wr        ( wr ),
      .wr_data   ( wr_data ),
      .wr_count  ( wr_count ),
      .wr_full   ( full ),
      .wr_oflow  ( oflow ),

      .rd_clk    ( axi4s_out.aclk ),
      .rd_srst   (~axi4s_out.aresetn ),
      .rd        ( rd ),
      .rd_ack    ( ),
      .rd_data   ( rd_data ),
      .rd_count  ( rd_count ),
      .rd_empty  ( empty ),
      .rd_uflow  ( uflow ),

      .axil_if   ( axil_if )
   );

   // --- pkt context ---
   fifo_async   #(
       .DATA_WID ( 1 ),
       .DEPTH    ( FIFO_ASYNC_DEPTH ),
       .FWFT     ( 1 )
   ) fifo_async__pkt_ctxt (
       .wr_clk   ( axi4s_to_fifo.aclk ),
       .wr_srst  ( ~axi4s_to_fifo.aresetn ),
       .wr_rdy   ( ),
       .wr       (  axi4s_to_fifo.tvalid && axi4s_to_fifo.tready && axi4s_to_fifo.tlast ),
       .wr_data  (  1'b1 ),
       .wr_count ( ),
       .wr_full  ( ),

       .wr_oflow ( ),
       .rd_clk   (  axi4s_out.aclk ),
       .rd_srst  ( ~axi4s_out.aresetn ),
       .rd       (  axi4s_out.tvalid && axi4s_out.tready && axi4s_out.tlast ),
       .rd_ack   ( ),
       .rd_data  ( ),
       .rd_count ( ),
       .rd_empty ( pkt_empty ),
       .rd_uflow ( )
   );

   // --- pkt_ready ---
   // (optionally) begin packet Tx only if word threshold is met or full packet is available.
   // With appropriate configuration, this can prevent mid-packet underrun.
   generate
       if (TX_THRESHOLD == 0) begin : g__no_tx_threshold
           // No Tx threshold: begin packet Tx as soon as first word is available.
           assign pkt_ready = 1'b1;
       end : g__no_tx_threshold
       else if (TX_THRESHOLD >= MAX_PKT_LEN) begin : g__tx_wait_for_packet
           // Hold off packet Tx until full packet is available.
           assign pkt_ready = !pkt_empty;
       end : g__tx_wait_for_packet
       else begin : g__tx_threshold
           // Tx threshold: begin packet Tx if word threshold is met, or if full packet is available.
           assign pkt_ready = !pkt_empty || (rd_count >= TX_THRESHOLD);
       end : g__tx_threshold
   endgenerate

   // --- axi4s output signaling ---
   assign axi4s_out.tvalid = ~empty && (~axi4s_out.sop || pkt_ready);

   assign axi4s_out.tuser  = rd_data.tuser;
   assign axi4s_out.tlast  = rd_data.tlast;
   assign axi4s_out.tid    = rd_data.tid;
   assign axi4s_out.tdest  = rd_data.tdest;
   assign axi4s_out.tkeep  = rd_data.tkeep;
   assign axi4s_out.tdata  = rd_data.tdata;

endmodule
