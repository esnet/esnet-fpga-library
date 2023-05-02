// -----------------------------------------------------------------------------
// axi4s_pkt_fifo_async is a packet-aware asynchronous fifo.  
// It requires a full packet to be buffered ahead of forwarding it out through 
// its egress interface, and it will discard the full packet if a transaction is 
// lost due to fifo overflow.
// -----------------------------------------------------------------------------

module axi4s_pkt_fifo_async
   import axi4s_pkg::*;
#(
   parameter int   FIFO_DEPTH = 256,
   parameter int   MAX_PKT_LEN = 9100,
   // Debug parameters
   parameter bit   DEBUG_ILA = 1'b0
) (
   axi4s_intf.rx   axi4s_in,

   input logic     clk_out,
   axi4s_intf.tx   axi4s_out,

   input  logic [15:0] flow_ctl_thresh,
   output logic        flow_ctl,

   axi4l_intf.peripheral axil_to_probe,
   axi4l_intf.peripheral axil_to_ovfl,
   axi4l_intf.peripheral axil_if
);
   import axi4s_pkg::*;

   localparam int  DATA_BYTE_WID            = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T                    = axi4s_in.TID_T;
   localparam type TDEST_T                  = axi4s_in.TDEST_T;
   localparam type TUSER_T                  = axi4s_in.TUSER_T;
   localparam axi4s_mode_t MODE             = axi4s_in.MODE;
   localparam axi4s_tuser_mode_t TUSER_MODE = axi4s_in.TUSER_MODE;

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T),
                 .MODE(MODE), .TUSER_MODE(TUSER_MODE))
                 axi4s_in_p ();

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T), .TUSER_MODE(TUSER_MODE))
                 __axi4s_in ();

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T), .TUSER_MODE(TUSER_MODE))
                 axi4s_to_fifo ();

   localparam CNT_WIDTH = $clog2(FIFO_DEPTH);

   // --- fifo_async signals ---
   typedef struct packed {
       logic                          tlast;
       TID_T                          tid;
       TDEST_T                        tdest;
       TUSER_T                        tuser;
       logic [DATA_BYTE_WID-1:0]      tkeep;
       logic [DATA_BYTE_WID-1:0][7:0] tdata;
   } fifo_data_t;

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

   localparam DATA_WIDTH = $size(wr_data);
   localparam PKT_DISCARD_DEPTH = $ceil($itor(MAX_PKT_LEN) / $itor(DATA_BYTE_WID)) * 3; // axi4s_pkt_discard_ovfl buffers 3 max pkts.
   localparam FIFO_ASYNC_DEPTH = FIFO_DEPTH;
   localparam ALMOST_FULL_THRESH = 4;


   // --- axi4s_pkt_discard_ovfl instantiation (if interface MODE == IGNORES_TREADY) ---
   generate
      if (axi4s_in.MODE == IGNORES_TREADY) begin : g__pkt_discard_ovfl
         axi4s_intf_pipe axi4s_in_pipe (.axi4s_if_from_tx(axi4s_in), .axi4s_if_to_rx(axi4s_in_p));

         // connector drives axi4s_in.tready to 1'b1 when interface operates in IGNORE_TREADY mode.
         axi4s_intf_connector axi4s_in_connector (
            .axi4s_from_tx (axi4s_in_p),
            .axi4s_to_rx   (__axi4s_in)
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
             .MAX_PKT_LEN  (MAX_PKT_LEN)
         ) axi4s_pkt_discard_ovfl_0 (
             .axi4s_in  (__axi4s_in),
             .axi4s_out (axi4s_to_fifo)
         );

         assign axi4s_to_fifo.tready = !almost_full;
         assign wr = axi4s_to_fifo.tvalid;
      end : g__pkt_discard_ovfl

      else begin : g__no_pkt_discard_ovfl
         axi4s_intf_connector axi4s_in_connector (
             .axi4s_from_tx (axi4s_in),
             .axi4s_to_rx   (axi4s_to_fifo)
         );

         axi4s_probe axi4s_probe (
            .axi4l_if  (axil_to_probe),
            .axi4s_if  (axi4s_to_fifo)
         );

         axi4l_intf_peripheral_term axi4l_to_ovfl_peripheral_term (.axi4l_if(axil_to_ovfl));

         assign axi4s_to_fifo.tready = !full;
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

   assign rd = !empty && axi4s_out.tready;

   
   // --- fifo_async instantiation ---
   fifo_async_axil #(
      .DATA_T    (fifo_data_t),
      .DEPTH     (FIFO_ASYNC_DEPTH),
      .FWFT      (1),
      .DEBUG_ILA (DEBUG_ILA)
   ) fifo_async_0 (
      .wr_clk    ( axi4s_to_fifo.aclk ),
      .wr_srst   (~axi4s_to_fifo.aresetn ),
      .wr_rdy    ( ),
      .wr        ( wr ),
      .wr_data   ( wr_data ),

      .rd_clk    ( axi4s_out.aclk ),
      .rd_srst   (~axi4s_out.aresetn ),
      .rd        ( rd ),
      .rd_data   ( rd_data ),

      .wr_count  ( wr_count ),
      .rd_count  ( rd_count ),
      .full      ( full ),
      .empty     ( empty ),

      .oflow     ( oflow ),
      .uflow     ( uflow ),

      .axil_if   ( axil_if )
   );


   // --- axi4s output clock/reset ---
   assign axi4s_out.aclk = clk_out;

   sync_reset #(
       .OUTPUT_ACTIVE_LOW ( 1 )
   ) i_sync_reset (
       .rst_in   ( axi4s_in.aresetn ),
       .clk_out  ( clk_out ),
       .srst_out ( axi4s_out.aresetn )
   );

   // --- axi4s output signaling ---
   assign axi4s_out.tvalid = ~empty;

   assign axi4s_out.tuser  = rd_data.tuser;
   assign axi4s_out.tlast  = rd_data.tlast;
   assign axi4s_out.tid    = rd_data.tid;
   assign axi4s_out.tdest  = rd_data.tdest;
   assign axi4s_out.tkeep  = rd_data.tkeep;
   assign axi4s_out.tdata  = rd_data.tdata;

    // Optional debug ILAs
    generate
        if (DEBUG_ILA) begin : g__ila
            fifo_xilinx_ila i_fifo_in_ila (
                .clk (axi4s_in.aclk),
                .probe0 ( !axi4s_in.aresetn ),  // input wire [0:0]  probe0
                .probe1 ( full ),          // input wire [0:0]  probe1
                .probe2 ( almost_full ),   // input wire [0:0]  probe2
                .probe3 ( oflow ),         // input wire [0:0]  probe3
                .probe4 ( '0 ),            // input wire [31:0] probe4
                .probe5 ( {'0, wr_count} ) // input wire [31:0] probe5
            );
            fifo_xilinx_ila i_fifo_out_ila (
                .clk (axi4s_out.aclk),
                .probe0 ( !axi4s_out.aresetn ), // input wire [0:0]  probe0
                .probe1 ( empty ),         // input wire [0:0]  probe1
                .probe2 ( empty ),         // input wire [0:0]  probe2
                .probe3 ( uflow ),         // input wire [0:0]  probe3
                .probe4 ( '0 ),            // input wire [31:0] probe4
                .probe5 ( {'0, rd_count} ) // input wire [31:0] probe5
            );
        end : g__ila
    endgenerate

endmodule
