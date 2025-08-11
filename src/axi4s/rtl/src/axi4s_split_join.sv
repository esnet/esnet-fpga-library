// -----------------------------------------------------------------------------
// axi4s_split_join is a module that combines the axi4s split, join and
// pkt_fifo_sync components for the purpose of separating the headers of a packet
// stream (for in-line header processing).  It also recombines the processed pkt 
// header stream with the packet payloads (after processing).  
// -----------------------------------------------------------------------------

module axi4s_split_join
#(
   parameter int   FIFO_DEPTH   = 512,
   parameter logic IN_PIPE      = 1,
   parameter logic OUT_PIPE     = 1,
   parameter logic HDR_IN_PIPE  = 1,
   parameter logic HDR_OUT_PIPE = 1
 ) (
   input logic       clk,
   input logic       srst,

   axi4s_intf.rx     axi4s_in,
   axi4s_intf.tx     axi4s_out,
   axi4s_intf.tx     axi4s_hdr_out,
   axi4s_intf.rx     axi4s_hdr_in,

   axi4l_intf.peripheral axil_if,

   input logic [15:0] hdr_length  // specified in bytes.
);
   import axi4s_pkg::*;

   logic        enable;
   logic [15:0] hdr_length_p;

   localparam int PTR_LEN = $clog2(FIFO_DEPTH);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int TID_WID   = axi4s_in.TID_WID;
   localparam int TDEST_WID = axi4s_in.TDEST_WID;
   localparam int TUSER_EXT_WID = axi4s_in.TUSER_WID;

   typedef struct packed {
       logic [TUSER_EXT_WID-1:0] opaque;
       logic [PTR_LEN-1:0]       pid;
       logic                     hdr_tlast;
   } tuser_int_t;
   localparam int TUSER_INT_WID = $bits(tuser_int_t);

   axi4s_intf_parameter_check param_check_pkt (.from_tx(axi4s_in), .to_rx(axi4s_out));
   axi4s_intf_parameter_check param_check_hdr (.from_tx(axi4s_hdr_in), .to_rx(axi4s_hdr_out));
   initial begin
       std_pkg::param_check(axi4s_hdr_in.TID_WID, TID_WID, "axi4s_hdr_in.TID_WID");
       std_pkg::param_check(axi4s_hdr_in.TDEST_WID, TDEST_WID, "axi4s_hdr_in.TDEST_WID");
       std_pkg::param_check(axi4s_hdr_in.TUSER_WID, TUSER_INT_WID, "axi4s_hdr_in.TUSER_WID");
   end


   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_EXT_WID) ) axi4s_in_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) __axi4s_in_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_EXT_WID) ) axi4s_out_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_hdr_in_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) __axi4s_hdr_in_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_hdr_out_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_to_pyld_fifo (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_to_pyld_fifo_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_from_pyld_fifo (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_from_pyld_fifo_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_EXT_WID) ) axi4s_to_split (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) __axi4s_to_split (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) axi4s_from_split (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_EXT_WID) ) axi4s_to_join_mux (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) _axi4s_to_join_mux (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_INT_WID) ) _axi4s_from_join_mux (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));

   generate
      if (IN_PIPE)
         axi4s_full_pipe in_pipe_0 (.from_tx(axi4s_in), .to_rx(axi4s_in_p));
      else
         axi4s_intf_connector in_intf_connector_0  (.from_tx(axi4s_in), .to_rx(axi4s_in_p));

      if (OUT_PIPE)
         axi4s_full_pipe out_pipe_0 (.from_tx(axi4s_out_p), .to_rx(axi4s_out));
      else
         axi4s_intf_connector out_intf_connector_0 (.from_tx(axi4s_out_p), .to_rx(axi4s_out));

      if (HDR_IN_PIPE)
         axi4s_full_pipe hdr_in_pipe_0 (.from_tx(axi4s_hdr_in), .to_rx(axi4s_hdr_in_p));
      else
         axi4s_intf_connector hdr_in_intf_connector_0  (.from_tx(axi4s_hdr_in), .to_rx(axi4s_hdr_in_p));

      if (HDR_OUT_PIPE)
         axi4s_full_pipe hdr_out_pipe_0 (.from_tx(axi4s_hdr_out_p), .to_rx(axi4s_hdr_out));
      else
         axi4s_intf_connector hdr_out_intf_connector_0 (.from_tx(axi4s_hdr_out_p), .to_rx(axi4s_hdr_out));

   endgenerate



   tuser_int_t __axi4s_in_p_tuser;
   assign __axi4s_in_p_tuser.opaque = axi4s_in_p.tuser;
   assign __axi4s_in_p_tuser.pid = '0;
   assign __axi4s_in_p_tuser.hdr_tlast = '0;
   axi4s_intf_set_meta #(
      .TID_WID (TID_WID),
      .TDEST_WID (TDEST_WID),
      .TUSER_WID (TUSER_INT_WID)
   ) axi4s_intf_set_meta_in_p (
      .from_tx (axi4s_in_p),
      .to_rx   (__axi4s_in_p),
      .tid     (axi4s_in_p.tid),
      .tdest   (axi4s_in_p.tdest),
      .tuser   (__axi4s_in_p_tuser)
   );

   // mux instantation used to bypass axi4s_split if not enabled.
   axi4s_intf_bypass_mux #(
      .PIPE_STAGES(1)
    ) bypass_split_mux (
      .from_tx    (__axi4s_in_p),
      .to_block   (__axi4s_to_split),
      .from_block (axi4s_from_split),
      .to_rx      (axi4s_hdr_out_p),
      .bypass     (!enable)
    );

   always @(posedge clk) begin
      enable       <= hdr_length != 0;  // disable and bypass if hdr_length is zero.
      hdr_length_p <= hdr_length;
   end

   // condition input metadata for splitter
   tuser_int_t __axi4s_to_split_tuser;
   assign __axi4s_to_split_tuser = __axi4s_to_split.tuser;
   axi4s_intf_set_meta #(
      .TID_WID (TID_WID),
      .TDEST_WID (TDEST_WID),
      .TUSER_WID (TUSER_EXT_WID)
   ) axi4s_intf_set_meta_to_split (
      .from_tx (__axi4s_to_split),
      .to_rx   (axi4s_to_split),
      .tid     (__axi4s_to_split.tid),
      .tdest   (__axi4s_to_split.tdest),
      .tuser   (__axi4s_to_split_tuser.opaque)
   );

   // header splitter instantiation
   axi4s_split #(
      .PTR_LEN   (PTR_LEN)
   ) axi4s_split_0 (
      .clk,
      .srst,
      .axi4s_in      (axi4s_to_split),
      .axi4s_out     (axi4s_to_pyld_fifo_p),
      .axi4s_hdr_out (axi4s_from_split),
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
       .clk_to_peripheral          ( clk ),
       .axi4l_if_to_peripheral     ( axil_to_reg_blk__clk )
   );

   axi4s_split_join_reg_blk axi4s_split_join_reg_blk_0 (
      .axil_if     (axil_to_reg_blk__clk),
      .reg_blk_if  (axi4s_split_join_regs)
   );



   // sop_mismatch tracking logic.
   logic sop_mismatch, sop_mismatch_latch;

   always @(posedge clk) begin
      if (srst)                                            sop_mismatch_latch <= 0;
      else if (axi4s_split_join_regs.sop_mismatch_rd_evt)  sop_mismatch_latch <= 0;
      else if (sop_mismatch)                               sop_mismatch_latch <= 1;
   end

   assign axi4s_split_join_regs.sop_mismatch_nxt = sop_mismatch_latch;
   assign axi4s_split_join_regs.sop_mismatch_nxt_v = 1;




   // packet fifo instantiation, plus ingress and egress pipeline stages.
   axi4s_full_pipe to_pyld_fifo_pipe_0 (.from_tx(axi4s_to_pyld_fifo_p), .to_rx(axi4s_to_pyld_fifo));

   axi4s_pkt_fifo_sync #(
       .FIFO_DEPTH(FIFO_DEPTH),
       .STR_FWD_MODE(0), // FIFO needs to store-and-forward, but achieves this when axi4s_to_buffer i/f IGNORES_TREADY.
       .IGNORE_TREADY(1)
    ) pyld_fifo_0 (
       .srst           (!enable),
       .axi4s_in       (axi4s_to_pyld_fifo),
       .axi4s_out      (axi4s_from_pyld_fifo),
       .axil_to_probe  (axil_to_probe),
       .axil_to_ovfl   (axil_to_ovfl),
       .axil_if        (axil_to_fifo),
       .oflow          ()
    );

   axi4s_full_pipe from_pyld_fifo_pipe_0 (.from_tx(axi4s_from_pyld_fifo), .to_rx(axi4s_from_pyld_fifo_p));


   // payload joiner instantiation.
   axi4s_join #(
      .PTR_LEN ( PTR_LEN )
   ) axi4s_join_0 (
      .clk,
      .srst,
      .axi4s_hdr_in  (__axi4s_hdr_in_p),
      .axi4s_in      (axi4s_from_pyld_fifo_p),
      .axi4s_out     (axi4s_to_join_mux),
      .enable        (enable),
      .sop_mismatch  (sop_mismatch)
   );

   tuser_int_t _axi4s_to_join_mux_tuser;
   assign _axi4s_to_join_mux_tuser.opaque = axi4s_to_join_mux.tuser;
   assign _axi4s_to_join_mux_tuser.pid = '0;
   assign _axi4s_to_join_mux_tuser.hdr_tlast = '0;
   axi4s_intf_set_meta #(
      .TID_WID (TID_WID),
      .TDEST_WID (TDEST_WID),
      .TUSER_WID (TUSER_INT_WID)
   ) axi4s_intf_set_meta_join_mux (
      .from_tx (axi4s_to_join_mux),
      .to_rx   (_axi4s_to_join_mux),
      .tid     (axi4s_to_join_mux.tid),
      .tdest   (axi4s_to_join_mux.tdest),
      .tuser   (_axi4s_to_join_mux_tuser)
   );

   // mux instantation used to bypass axi4s_join if not enabled.
   axi4s_intf_bypass_mux #(
      .PIPE_STAGES(1)
    ) bypass_join_mux (
      .from_tx    (axi4s_hdr_in_p),
      .to_block   (__axi4s_hdr_in_p),
      .from_block (_axi4s_to_join_mux),
      .to_rx      (_axi4s_from_join_mux),
      .bypass     (!enable)
    );
 
    tuser_int_t _axi4s_from_join_mux_tuser;
    assign _axi4s_from_join_mux_tuser = _axi4s_from_join_mux.tuser;
    axi4s_intf_set_meta #(
      .TID_WID (TID_WID),
      .TDEST_WID (TDEST_WID),
      .TUSER_WID (TUSER_EXT_WID)
    ) axi4s_intf_set_meta_out (
      .from_tx (_axi4s_from_join_mux),
      .to_rx   (axi4s_out_p),
      .tid     (_axi4s_from_join_mux.tid),
      .tdest   (_axi4s_from_join_mux.tdest),
      .tuser   (_axi4s_from_join_mux_tuser.opaque)
    );



endmodule // axi4s_split_join
