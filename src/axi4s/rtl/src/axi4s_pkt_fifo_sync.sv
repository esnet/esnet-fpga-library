// -----------------------------------------------------------------------------
// axi4s_pkt_fifo_sync is a packet-aware synchronous fifo.  
// It buffers a full ingress packet prior to forwarding it to the egress fifo, and
// will discard the full packet if an ingress transaction is lost due to fifo
// overflow.
// It also supports a store-and-forward egress mode, for instantiations that do not
// incorporate ingress discard logic.
// -----------------------------------------------------------------------------

module axi4s_pkt_fifo_sync #(
   parameter int   FIFO_DEPTH = 256,
   parameter int   ALMOST_FULL_THRESH = 4,  // set to 4 for pkt_discard (IGNORES_TREADY) mode.
   parameter int   MAX_PKT_LEN = 9100,
   parameter logic STR_FWD_MODE = 0,        // when 1, full packet is required to deassert empty.
   parameter logic NO_INTRA_PKT_GAP = 0,    // when 1, space for full packet is required to assert tready.
   parameter bit   IGNORE_TREADY = 0,
   parameter bit   DROP_ERRORED = 0         // when 1, drop 'errored' packets, where error status is carried in lsb of axi4s_in.TUSER
) (
   input logic srst,

   axi4s_intf.rx   axi4s_in,
   axi4s_intf.tx   axi4s_out,

   axi4l_intf.peripheral axil_to_probe,
   axi4l_intf.peripheral axil_to_ovfl,
   axi4l_intf.peripheral axil_if,

   output logic oflow
);
   import axi4s_pkg::*;

   // Parameter check
   initial begin
       std_pkg::param_check(axi4s_in.DATA_BYTE_WID, axi4s_out.DATA_BYTE_WID, "DATA_BYTE_WID");
       std_pkg::param_check(axi4s_in.TID_WID,       axi4s_out.TID_WID,       "TID_WID");
       std_pkg::param_check(axi4s_in.TDEST_WID,     axi4s_out.TDEST_WID,     "TDEST_WID");
       std_pkg::param_check(axi4s_in.TUSER_WID,     axi4s_out.TUSER_WID,     "TUSER_WID");
   end

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int TDATA_WID     = DATA_BYTE_WID*8;
   localparam int TKEEP_WID     = DATA_BYTE_WID;
   localparam int TID_WID       = axi4s_in.TID_WID;
   localparam int TDEST_WID     = axi4s_in.TDEST_WID;
   localparam int TUSER_WID     = axi4s_in.TUSER_WID;

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID))
                 __axi4s_in (.aclk(axi4s_in.aclk));

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID))
                 axi4s_to_fifo (.aclk(axi4s_in.aclk));

   localparam CNT_WIDTH = $clog2(FIFO_DEPTH+1);

   // --- fifo_sync signals ---
   typedef struct packed {
       logic                 tlast;
       logic [TID_WID-1:0]   tid;
       logic [TDEST_WID-1:0] tdest;
       logic [TUSER_WID-1:0] tuser;
       logic [TKEEP_WID-1:0] tkeep;
       logic [TDATA_WID-1:0] tdata;
   } fifo_data_t;

   logic                wr;
   fifo_data_t          wr_data;
   logic [CNT_WIDTH-1:0] wr_count;
   logic                almost_full, full;

   logic                rd;
   fifo_data_t          rd_data;
   logic [CNT_WIDTH-1:0] rd_count;
   logic                empty, __empty;
   logic                uflow;

   localparam DATA_WIDTH = $size(wr_data);
   localparam PKT_DISCARD_DEPTH = $ceil($itor(MAX_PKT_LEN) / $itor(DATA_BYTE_WID)) * 3; // axi4s_pkt_discard_ovfl buffers 3 max pkts.
   localparam FIFO_SYNC_DEPTH = FIFO_DEPTH;


   // --- axi4s_pkt_discard_ovfl instantiation (if IGNORE_TREADY mode is enabled) ---
   generate
      if (IGNORE_TREADY) begin : g__pkt_discard_ovfl
         // connector drives axi4s_in.tready to 1'b1 when in IGNORE_TREADY mode.
         axi4s_intf_connector #(.IGNORE_TREADY(1)) axi4s_in_connector (
            .from_tx (axi4s_in),
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
             .MAX_PKT_LEN   (MAX_PKT_LEN),
             .DROP_ERRORED  (DROP_ERRORED)
         ) axi4s_pkt_discard_ovfl_0 (
             .srst,
             .axi4s_in  (__axi4s_in),
             .axi4s_out (axi4s_to_fifo)
         );

         assign axi4s_to_fifo.tready = !almost_full;
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

         if (NO_INTRA_PKT_GAP) begin : g__no_intra_pkt_gap
            logic sop;

            // track sop
            initial sop = 1'b1;
            always @(posedge axi4s_in.aclk) begin
                if (srst) sop <= 1'b1;
                else begin
                    if (axi4s_to_fifo.tvalid && axi4s_to_fifo.tready && axi4s_to_fifo.tlast) sop <= 1'b1;
                    else if (axi4s_to_fifo.tvalid && axi4s_to_fifo.tready)                   sop <= 1'b0;
                end
            end

            assign axi4s_to_fifo.tready = !(almost_full && sop);
            assign wr = axi4s_to_fifo.tvalid && axi4s_to_fifo.tready;
         end : g__no_intra_pkt_gap

         else begin 
            assign axi4s_to_fifo.tready = !full;
            assign wr = axi4s_to_fifo.tvalid && axi4s_to_fifo.tready;
         end
      end : g__no_pkt_discard_ovfl
   endgenerate



   // --- fifo_sync signaling ---
   assign wr_data.tuser = axi4s_to_fifo.tuser;
   assign wr_data.tlast = axi4s_to_fifo.tlast;
   assign wr_data.tid   = axi4s_to_fifo.tid;
   assign wr_data.tdest = axi4s_to_fifo.tdest;
   assign wr_data.tkeep = axi4s_to_fifo.tkeep;
   assign wr_data.tdata = axi4s_to_fifo.tdata;

   assign almost_full = wr_count > (FIFO_SYNC_DEPTH - ALMOST_FULL_THRESH);

   assign rd = !empty && axi4s_out.tready;

   
   // --- fifo_sync instantiation ---
   fifo_axil_sync #(
      .DATA_WID  ($bits(fifo_data_t)),
      .DEPTH     (FIFO_SYNC_DEPTH),
      .FWFT      (1)
   ) fifo_sync_0 (
      .clk       ( axi4s_to_fifo.aclk ),
      .srst,
      .wr_rdy    ( ),
      .wr        ( wr ),
      .wr_data   ( wr_data ),
      .wr_count  ( wr_count ),
      .full      ( full ),
      .oflow     ( oflow ),
      .rd        ( rd ),
      .rd_data   ( rd_data ),
      .rd_count  ( rd_count ),
      .rd_ack    ( ),
      .empty     ( __empty ),
      .uflow     ( uflow ),
      .axil_if   ( axil_if )
   );

   // --- store-and-forward mode logic ---
   // tracks count of tlasts in FIFO and defers deassertion of empty unless >= 1 tlast (full pkt) in fifo.
   generate
      if (STR_FWD_MODE == 1) begin : g__str_fwd
         logic [CNT_WIDTH-1:0] wr_tlast_count, rd_tlast_count, tlast_count;

         always @(posedge axi4s_to_fifo.aclk) begin
            if (srst)                     wr_tlast_count <= '0;
            else if (wr && wr_data.tlast) wr_tlast_count <= wr_tlast_count + 1;
         end

         always @(posedge axi4s_out.aclk) begin
            if (srst)                                                         rd_tlast_count <= '0;
            else if (axi4s_out.tvalid && axi4s_out.tready && axi4s_out.tlast) rd_tlast_count <= rd_tlast_count + 1;
         end

         assign tlast_count = wr_tlast_count - rd_tlast_count;

         assign empty = __empty || (tlast_count == '0);

      end : g__str_fwd

      else begin : g__cut_through
         assign empty = __empty;

      end : g__cut_through

   endgenerate

   // --- axi4s output signaling ---
   assign axi4s_out.tvalid = ~empty;

   assign axi4s_out.tuser  = rd_data.tuser;
   assign axi4s_out.tlast  = rd_data.tlast;
   assign axi4s_out.tid    = rd_data.tid;
   assign axi4s_out.tdest  = rd_data.tdest;
   assign axi4s_out.tkeep  = rd_data.tkeep;
   assign axi4s_out.tdata  = rd_data.tdata;

endmodule
