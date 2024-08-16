// -----------------------------------------------------------------------------
// axi4s_split_join is a module that combines the axi4s split, join and
// pkt_fifo_sync components for the purpose of separating the headers of a packet
// stream (for in-line header processing).  It also recombines the processed pkt 
// header stream with the packet payloads (after processing).  
// -----------------------------------------------------------------------------

module axi4s_split_join
   import axi4s_pkg::*;
#(
   parameter logic BIGENDIAN    = 0,  // Little endian by default.
   parameter int   FIFO_DEPTH   = 512,
   parameter logic IN_PIPE      = 1,
   parameter logic OUT_PIPE     = 1,
   parameter logic HDR_IN_PIPE  = 1,
   parameter logic HDR_OUT_PIPE = 1
 ) (
   axi4s_intf.rx     axi4s_in,
   axi4s_intf.tx     axi4s_out,
   axi4s_intf.tx     axi4s_hdr_out,
   axi4s_intf.rx     axi4s_hdr_in,

   axi4l_intf.peripheral axil_if,

   input logic [15:0] hdr_length  // specified in bytes.
);

   logic        enable;
   logic [15:0] hdr_length_p;

   localparam int PTR_LEN = $clog2(FIFO_DEPTH);

   localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_in.TID_T;
   localparam type TDEST_T       = axi4s_in.TDEST_T;
   localparam type TUSER_T       = axi4s_in.TUSER_T;

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) __axi4s_in ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_in_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) __axi4s_in_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_out_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) __axi4s_hdr_in ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_hdr_in_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) __axi4s_hdr_in_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_hdr_out_p ();

   axi4s_intf #( .MODE(IGNORES_TREADY), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_to_pyld_fifo ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_to_pyld_fifo_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_from_pyld_fifo ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_from_pyld_fifo_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_to_split_mux ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_to_join_mux ();


   // input interface connectors (to workaround synthesis failure due to unresolved interface parameters).
   axi4s_intf_connector axi4s_in_connector     (.axi4s_from_tx(axi4s_in),     .axi4s_to_rx(__axi4s_in));
   axi4s_intf_connector axi4s_hdr_in_connector (.axi4s_from_tx(axi4s_hdr_in), .axi4s_to_rx(__axi4s_hdr_in));

   generate
      if (IN_PIPE)
         axi4s_full_pipe in_pipe_0 (.axi4s_if_from_tx(__axi4s_in), .axi4s_if_to_rx(axi4s_in_p));
      else
         axi4s_intf_connector in_intf_connector_0  (.axi4s_from_tx(__axi4s_in), .axi4s_to_rx(axi4s_in_p));

      if (OUT_PIPE)
         axi4s_full_pipe out_pipe_0 (.axi4s_if_from_tx(axi4s_out_p), .axi4s_if_to_rx(axi4s_out));
      else
         axi4s_intf_connector out_intf_connector_0 (.axi4s_from_tx(axi4s_out_p), .axi4s_to_rx(axi4s_out));

      if (HDR_IN_PIPE)
         axi4s_full_pipe hdr_in_pipe_0 (.axi4s_if_from_tx(__axi4s_hdr_in), .axi4s_if_to_rx(axi4s_hdr_in_p));
      else
         axi4s_intf_connector hdr_in_intf_connector_0  (.axi4s_from_tx(__axi4s_hdr_in), .axi4s_to_rx(axi4s_hdr_in_p));

      if (HDR_OUT_PIPE)
         axi4s_full_pipe hdr_out_pipe_0 (.axi4s_if_from_tx(axi4s_hdr_out_p), .axi4s_if_to_rx(axi4s_hdr_out));
      else
         axi4s_intf_connector hdr_out_intf_connector_0 (.axi4s_from_tx(axi4s_hdr_out_p), .axi4s_to_rx(axi4s_hdr_out));

   endgenerate




   // mux instantation used to bypass axi4s_split if not enabled.
   axi4s_intf_bypass_mux #(
      .PIPE_STAGES(1), .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)
    ) bypass_split_mux (
      .axi4s_in         (axi4s_in_p),
      .axi4s_to_block   (__axi4s_in_p),
      .axi4s_from_block (axi4s_to_split_mux),
      .axi4s_out        (axi4s_hdr_out_p),
      .bypass           (!enable)
    );

   always @(posedge axi4s_in.aclk) begin
      enable       <= hdr_length != 0;  // disable and bypass if hdr_length is zero.
      hdr_length_p <= hdr_length;
   end

   // header splitter instantiation
   axi4s_split #(
      .BIGENDIAN (BIGENDIAN),
      .PTR_LEN   (PTR_LEN)
   ) axi4s_split_0 (
      .axi4s_in      (__axi4s_in_p),
      .axi4s_out     (axi4s_to_pyld_fifo_p),
      .axi4s_hdr_out (axi4s_to_split_mux),
      .hdr_length    (hdr_length_p),
      .enable        (enable)
   );



   // instantiate AXI-L interfaces and regmap decoder.
   axi4l_intf axil_to_reg_blk ();
   axi4l_intf axil_to_probe   ();
   axi4l_intf axil_to_ovfl    ();
   axi4l_intf axil_to_fifo    ();

   axi4l_intf_controller_term axi4l_to_fifo_term (.axi4l_if (axil_to_fifo));

   axi4s_split_join_reg_intf axi4s_split_join_regs();

   axi4s_split_join_decoder axi4s_split_join_decoder_0 (
      .axil_if (axil_if),
      .axi4s_split_join_axil_if   (axil_to_reg_blk),
      .probe_to_pyld_fifo_axil_if (axil_to_probe),
      .drops_to_pyld_fifo_axil_if (axil_to_ovfl)
   );

   axi4l_intf axil_to_reg_blk__clk ();

   axi4l_intf_cdc axi4l_intf_cdc_0 (
       .axi4l_if_from_controller   ( axil_to_reg_blk ),
       .clk_to_peripheral          ( axi4s_in.aclk ),
       .axi4l_if_to_peripheral     ( axil_to_reg_blk__clk )
   );

   axi4s_split_join_reg_blk axi4s_split_join_reg_blk_0 (
      .axil_if     (axil_to_reg_blk__clk),
      .reg_blk_if  (axi4s_split_join_regs)
   );



   // sop_mismatch tracking logic.
   logic sop_mismatch, sop_mismatch_latch;

   always @(posedge axi4s_in.aclk) begin
      if (!axi4s_in.aresetn)                               sop_mismatch_latch <= 0;
      else if (axi4s_split_join_regs.sop_mismatch_rd_evt)  sop_mismatch_latch <= 0;
      else if (sop_mismatch)                               sop_mismatch_latch <= 1;
   end

   assign axi4s_split_join_regs.sop_mismatch_nxt = sop_mismatch_latch;
   assign axi4s_split_join_regs.sop_mismatch_nxt_v = 1;




   // packet fifo instantiation, plus ingress and egress pipeline stages.
   axi4s_full_pipe to_pyld_fifo_pipe_0 (.axi4s_if_from_tx(axi4s_to_pyld_fifo_p), .axi4s_if_to_rx(axi4s_to_pyld_fifo));

   axi4s_pkt_fifo_sync #(
       .FIFO_DEPTH(FIFO_DEPTH),
       .STR_FWD_MODE(0) // FIFO needs to store-and-forward, but achieves this when axi4s_to_buffer i/f IGNORES_TREADY.
    ) pyld_fifo_0 (
       .srst           (!enable),
       .axi4s_in       (axi4s_to_pyld_fifo),
       .axi4s_out      (axi4s_from_pyld_fifo),
       .axil_to_probe  (axil_to_probe),
       .axil_to_ovfl   (axil_to_ovfl),
       .axil_if        (axil_to_fifo),
       .oflow          ()
    );

   axi4s_full_pipe from_pyld_fifo_pipe_0 (.axi4s_if_from_tx(axi4s_from_pyld_fifo), .axi4s_if_to_rx(axi4s_from_pyld_fifo_p));


   // payload joiner instantiation.
   axi4s_join #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_join_0 (
      .axi4s_hdr_in  (__axi4s_hdr_in_p),
      .axi4s_in      (axi4s_from_pyld_fifo_p),
      .axi4s_out     (axi4s_to_join_mux),
      .enable        (enable),
      .sop_mismatch  (sop_mismatch)
   );

   // mux instantation used to bypass axi4s_join if not enabled.
   axi4s_intf_bypass_mux #(
      .PIPE_STAGES(1), .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)
    ) bypass_join_mux (
      .axi4s_in         (axi4s_hdr_in_p),
      .axi4s_to_block   (__axi4s_hdr_in_p),
      .axi4s_from_block (axi4s_to_join_mux),
      .axi4s_out        (axi4s_out_p),
      .bypass           (!enable)
    );

endmodule // axi4s_split_join
