// -----------------------------------------------------------------------------
// axi4s_split is used to split a copy of the header data from the each packet.
// It receives a packet stream on the ingress axi4s interface and drives the 
// the selected header stream out the egress header axi4s interface.  It also 
// propagates the ingress packet stream (untouched) to a separate egress axi4s 
// interface.
// Note: axi4s_split uses the tuser signal of the axis4s_hdr_out bus to carry
// packet id (pid) information.
// -----------------------------------------------------------------------------

module axi4s_split #(
   parameter int   PTR_LEN = 16    // wordlength of wr_ptr (for buffer context, or pkt_id).
)  (
   input logic       clk,
   input logic       srst,
   axi4s_intf.rx     axi4s_in,
   axi4s_intf.tx     axi4s_out,
   axi4s_intf.tx     axi4s_hdr_out,

   input logic [15:0] hdr_length,  // specified in bytes.
   input logic        enable
);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int TID_WID       = axi4s_in.TID_WID;
   localparam int TDEST_WID     = axi4s_in.TDEST_WID;
   localparam int TUSER_WID_IN  = axi4s_in.TUSER_WID;

   typedef struct packed {
       logic [TUSER_WID_IN-1:0] opaque;
       logic [PTR_LEN-1:0] pid;
       logic hdr_tlast;
   } tuser_t;

   localparam int TUSER_OUT_WID = $bits(tuser_t);

   // parameter checking
   initial begin
       std_pkg::param_check_gt(axi4s_out.TID_WID, TID_WID, "axi4s_out.TID_WID");
       std_pkg::param_check_gt(axi4s_out.TDEST_WID, TDEST_WID, "axi4s_out.TDEST_WID");
       std_pkg::param_check_gt(axi4s_out.TUSER_WID, TUSER_OUT_WID, "axi4s_out.TUSER_WID");
       std_pkg::param_check_gt(axi4s_hdr_out.TID_WID, TID_WID, "axi4s_hdr_out.TID_WID");
       std_pkg::param_check_gt(axi4s_hdr_out.TDEST_WID, TDEST_WID, "axi4s_hdr_out.TDEST_WID");
       std_pkg::param_check_gt(axi4s_hdr_out.TUSER_WID, TUSER_OUT_WID, "axi4s_hdr_out.TUSER_WID");
   end

   // signals
   logic [PTR_LEN-1:0] wr_ptr; // wr pointer for pkt buffer addressing, or pkt_id.   
   logic [PTR_LEN-1:0] pid;    // wr_ptr of hdr_out sop.

   logic reset, resetn;
   tuser_t axi4s_to_copy_tuser;
   tuser_t _axi4s_hdr_out_p_tuser;
   tuser_t axi4s_hdr_out_p_tuser;

   // internal axi4s interfaces.
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID),
                .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_OUT_WID)) axi4s_to_copy (.aclk(clk), .aresetn(resetn));

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID),
                .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_OUT_WID)) axi4s_to_trunc (.aclk(clk), .aresetn(resetn));

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID),
                .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_OUT_WID)) _axi4s_hdr_out_p (.aclk(clk), .aresetn(resetn));

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID),
                .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_OUT_WID)) axi4s_hdr_out_p (.aclk(clk), .aresetn(resetn));

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID),
                .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_OUT_WID)) axi4s_out_p (.aclk(clk), .aresetn(resetn));

   always @(posedge clk) reset <= srst || !enable;
   assign resetn = !reset;


   // wr_ptr logic
   always @(posedge clk)
      if (reset)                                   wr_ptr <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready) wr_ptr <= wr_ptr + 1;


   // axis4s_to_copy interface signalling. assigns buffer context to the tuser signal.
   assign axi4s_to_copy.tvalid           = axi4s_in.tvalid;
   assign axi4s_to_copy.tdata            = axi4s_in.tdata;
   assign axi4s_to_copy.tkeep            = axi4s_in.tkeep;
   assign axi4s_to_copy.tdest            = axi4s_in.tdest;
   assign axi4s_to_copy.tid              = axi4s_in.tid;
   assign axi4s_to_copy.tlast            = axi4s_in.tlast;
   assign axi4s_to_copy_tuser.opaque     = axi4s_in.tuser;
   assign axi4s_to_copy_tuser.hdr_tlast  = axi4s_hdr_out_p.tvalid && axi4s_hdr_out_p.tlast;
   assign axi4s_to_copy_tuser.pid        = {'0, wr_ptr};
   assign axi4s_to_copy.tuser            = axi4s_to_copy_tuser;

   assign axi4s_in.tready                = axi4s_to_copy.tready;


   // axi4s_copy instance.
   axi4s_copy axi4s_copy_0 (
      .axi4s_in     (axi4s_to_copy),
      .axi4s_out    (axi4s_to_trunc),
      .axi4s_cp_out (axi4s_out_p)
   );

   // axi4s_trunc instance.
   axi4s_trunc #(
      .OUT_PIPE  (0)
   ) axi4s_trunc_0 (
      .clk,
      .srst       (reset),
      .axi4s_in   (axi4s_to_trunc),
      .axi4s_out  (_axi4s_hdr_out_p),
      .length     (hdr_length)
   );
   assign _axi4s_hdr_out_p_tuser = _axi4s_hdr_out_p.tuser;

   always @(posedge clk) pid <= (_axi4s_hdr_out_p.tvalid && _axi4s_hdr_out_p.sop) ? _axi4s_hdr_out_p_tuser.pid : pid;

   // axi4s_hdr_out_p interface signalling. assigns pid (sop wr_ptr) to hdr pkt.
   assign axi4s_hdr_out_p.tvalid           = _axi4s_hdr_out_p.tvalid;
   assign axi4s_hdr_out_p.tdata            = _axi4s_hdr_out_p.tdata;
   assign axi4s_hdr_out_p.tkeep            = _axi4s_hdr_out_p.tkeep;
   assign axi4s_hdr_out_p.tdest            = _axi4s_hdr_out_p.tdest;
   assign axi4s_hdr_out_p.tid              = _axi4s_hdr_out_p.tid;
   assign axi4s_hdr_out_p.tlast            = _axi4s_hdr_out_p.tlast;

   always_comb begin
       axi4s_hdr_out_p_tuser = _axi4s_hdr_out_p_tuser;
       axi4s_hdr_out_p_tuser.pid        = (_axi4s_hdr_out_p.tvalid && _axi4s_hdr_out_p.sop) ? _axi4s_hdr_out_p_tuser.pid : {'0, pid};
       axi4s_hdr_out_p_tuser.hdr_tlast  = '0;
       axi4s_hdr_out_p.tuser            = axi4s_hdr_out_p_tuser;
   end

   assign _axi4s_hdr_out_p.tready         = axi4s_hdr_out_p.tready;

   axi4s_intf_pipe axi4s_hdr_out_pipe (.from_tx(axi4s_hdr_out_p), .to_rx(axi4s_hdr_out));
   axi4s_intf_pipe axi4s_out_pipe     (.from_tx(axi4s_out_p),     .to_rx(axi4s_out));

endmodule // axi4s_split
