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
// axi4s_pkt_fifo_sync is a packet-aware synchronous fifo.  
// It buffers a full ingress packet prior to forwarding it to the egress fifo, and
// will discard the full packet if an ingress transaction is lost due to fifo
// overflow.
// It also supports a store-and-forward egress mode, for instantiations that do not
// incorporate ingress discard logic.
// -----------------------------------------------------------------------------

module axi4s_pkt_fifo_sync
   import axi4s_pkg::*;
#(
   parameter int   FIFO_DEPTH = 256,
   parameter int   MAX_PKT_LEN = 9100,
   parameter logic STR_FWD_MODE = 0, // when 1, full packet is required to deassert empty.
   // Debug parameters
   parameter bit   DEBUG_ILA = 1'b0
) (
   input logic srst,

   axi4s_intf.rx   axi4s_in,
   axi4s_intf.tx   axi4s_out,

   axi4l_intf.peripheral axil_to_probe,
   axi4l_intf.peripheral axil_to_ovfl,
   axi4l_intf.peripheral axil_if
);
   import axi4s_pkg::*;

   localparam int  DATA_BYTE_WID            = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T                    = axi4s_in.TID_T;
   localparam type TDEST_T                  = axi4s_in.TDEST_T;
   localparam type TUSER_T                  = axi4s_in.TUSER_T;
   localparam axi4s_tuser_mode_t TUSER_MODE = axi4s_in.TUSER_MODE;

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), 
                 .TDEST_T(TDEST_T), .TUSER_T(TUSER_T), .TUSER_MODE(TUSER_MODE)) __axi4s_in ();

   axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T),
                 .TDEST_T(TDEST_T), .TUSER_T(TUSER_T), .TUSER_MODE(TUSER_MODE)) axi4s_to_fifo ();

   localparam CNT_WIDTH = $clog2(FIFO_DEPTH);

   // --- fifo_sync signals ---
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
   logic [CNT_WIDTH:0]  count;
   logic                almost_full, full;
   logic                oflow;

   logic                rd;
   fifo_data_t          rd_data;
   logic                empty, __empty;
   logic                uflow;

   localparam DATA_WIDTH = $size(wr_data);
   localparam PKT_DISCARD_DEPTH = $ceil($itor(MAX_PKT_LEN) / $itor(DATA_BYTE_WID)) * 3; // axi4s_pkt_discard_ovfl buffers 3 max pkts.
   localparam FIFO_SYNC_DEPTH = FIFO_DEPTH;
   localparam ALMOST_FULL_THRESH = 4;


   // --- axi4s_pkt_discard_ovfl instantiation (if interface MODE == IGNORES_TREADY) ---
   generate
      if (axi4s_in.MODE == IGNORES_TREADY) begin : g__pkt_discard_ovfl
         // connector drives axi4s_in.tready to 1'b1 when interface operates in IGNORE_TREADY mode.
         axi4s_intf_connector axi4s_in_connector (
            .axi4s_from_tx (axi4s_in),
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



   // --- fifo_sync signaling ---
   assign wr_data.tuser = axi4s_to_fifo.tuser;
   assign wr_data.tlast = axi4s_to_fifo.tlast;
   assign wr_data.tid   = axi4s_to_fifo.tid;
   assign wr_data.tdest = axi4s_to_fifo.tdest;
   assign wr_data.tkeep = axi4s_to_fifo.tkeep;
   assign wr_data.tdata = axi4s_to_fifo.tdata;

   assign almost_full = count > (FIFO_SYNC_DEPTH - ALMOST_FULL_THRESH);

   assign rd = !empty && axi4s_out.tready;

   
   // --- fifo_sync instantiation ---
   fifo_sync_axil #(
      .DATA_T    (fifo_data_t),
      .DEPTH     (FIFO_SYNC_DEPTH),
      .FWFT      (1),
      .DEBUG_ILA (DEBUG_ILA)
   ) fifo_sync_0 (
      .clk       ( axi4s_to_fifo.aclk ),
      .srst      (~axi4s_to_fifo.aresetn || srst),
      .wr        ( wr ),
      .wr_data   ( wr_data ),
      .rd        ( rd ),
      .rd_data   ( rd_data ),
      .count     ( count ),
      .full      ( full ),
      .empty     ( __empty ),
      .oflow     ( oflow ),
      .uflow     ( uflow ),
      .axil_if   ( axil_if )
   );

   // --- store-and-forward mode logic ---
   // tracks count of tlasts in FIFO and defers deassertion of empty unless >= 1 tlast (full pkt) in fifo.
   generate
      if (STR_FWD_MODE == 1) begin : g__str_fwd
         logic [CNT_WIDTH:0] wr_tlast_count, rd_tlast_count, tlast_count;

         always @(posedge axi4s_to_fifo.aclk) begin
            if (!axi4s_to_fifo.aresetn)   wr_tlast_count <= '0;
            else if (wr && wr_data.tlast) wr_tlast_count <= wr_tlast_count + 1;
         end

         always @(posedge axi4s_out.aclk) begin
            if (!axi4s_out.aresetn) rd_tlast_count <= '0;
            else if (axi4s_out.tvalid && axi4s_out.tready && axi4s_out.tlast) rd_tlast_count <= rd_tlast_count + 1;
         end

         assign tlast_count = wr_tlast_count - rd_tlast_count;

         assign empty = __empty || (tlast_count == '0);

      end : g__str_fwd

      else begin : g__
         assign empty = __empty;

      end : g__

   endgenerate


   // --- axi4s output clock/reset ---
   assign axi4s_out.aclk    = axi4s_to_fifo.aclk;
   assign axi4s_out.aresetn = axi4s_to_fifo.aresetn;


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
                .probe5 ( {'0, count} )    // input wire [31:0] probe5
            );
            fifo_xilinx_ila i_fifo_out_ila (
                .clk (axi4s_out.aclk),
                .probe0 ( !axi4s_out.aresetn ), // input wire [0:0]  probe0
                .probe1 ( empty ),         // input wire [0:0]  probe1
                .probe2 ( empty ),         // input wire [0:0]  probe2
                .probe3 ( uflow ),         // input wire [0:0]  probe3
                .probe4 ( '0 ),            // input wire [31:0] probe4
                .probe5 ( {'0, count} )    // input wire [31:0] probe5
            );
        end : g__ila
    endgenerate

endmodule
