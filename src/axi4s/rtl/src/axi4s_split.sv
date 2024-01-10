// -----------------------------------------------------------------------------
// axi4s_split is used to split a copy of the header data from the each packet.
// It receives a packet stream on the ingress axi4s interface and drives the 
// the selected header stream out the egress header axi4s interface.  It also 
// propagates the ingress packet stream (untouched) to a separate egress axi4s 
// interface.
// Note: axi4s_split uses the tuser signal of the axis4s_hdr_out bus to carry
// packet id (pid) information.
// -----------------------------------------------------------------------------

module axi4s_split
   import axi4s_pkg::*;
#(
   parameter logic BIGENDIAN = 0,  // Little endian by default.
   parameter int   PTR_LEN = 16    // wordlength of wr_ptr (for buffer context, or pkt_id).
)  (
   axi4s_intf.rx     axi4s_in,
   axi4s_intf.tx     axi4s_out,
   axi4s_intf.tx     axi4s_hdr_out,

   input logic [15:0] hdr_length,  // specified in bytes.
   input logic        enable
);

   localparam int  DATA_BYTE_WID = axi4s_hdr_out.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_hdr_out.TID_T;
   localparam type TDEST_T       = axi4s_hdr_out.TDEST_T;
   localparam type TUSER_T       = axi4s_hdr_out.TUSER_T;

   // signals
   logic [PTR_LEN-1:0] wr_ptr; // wr pointer for pkt buffer addressing, or pkt_id.   
   logic [PTR_LEN-1:0] pid;    // wr_ptr of hdr_out sop.

   // internal axi4s interfaces.
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T),
                .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_to_copy ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T),
                .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_to_trunc ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T),
                .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axi4s_hdr_out ();


   // wr_ptr logic
   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn || !enable)            wr_ptr <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready) wr_ptr <= wr_ptr + 1;


   // axis4s_to_copy interface signalling. assigns buffer context to the tuser signal.
   assign axi4s_to_copy.aclk             = axi4s_in.aclk;
   assign axi4s_to_copy.aresetn          = axi4s_in.aresetn;
   assign axi4s_to_copy.tvalid           = axi4s_in.tvalid;
   assign axi4s_to_copy.tdata            = axi4s_in.tdata;
   assign axi4s_to_copy.tkeep            = axi4s_in.tkeep;
   assign axi4s_to_copy.tdest            = axi4s_in.tdest;
   assign axi4s_to_copy.tid              = axi4s_in.tid;
   assign axi4s_to_copy.tlast            = axi4s_in.tlast;
   assign axi4s_to_copy.tuser.pid        = {'0, wr_ptr};
   assign axi4s_to_copy.tuser.hdr_tlast  = axi4s_hdr_out.tvalid && axi4s_hdr_out.tlast;

   assign axi4s_in.tready                = axi4s_to_copy.tready;


   // axi4s_copy instance.
   axi4s_copy axi4s_copy_0 (
      .axi4s_in     (axi4s_to_copy),
      .axi4s_out    (axi4s_to_trunc),
      .axi4s_cp_out (axi4s_out)
   );

   // axi4s_trunc instance.
   axi4s_trunc #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_trunc_0 (
      .axi4s_in   (axi4s_to_trunc),
      .axi4s_out  (__axi4s_hdr_out),
      .length     (hdr_length)
   );

   always @(posedge axi4s_in.aclk) pid <= (__axi4s_hdr_out.tvalid && __axi4s_hdr_out.sop) ? __axi4s_hdr_out.tuser.pid : pid;

   // axi4s_hdr_out interface signalling. assigns pid (sop wr_ptr) to hdr pkt.
   assign axi4s_hdr_out.aclk             = __axi4s_hdr_out.aclk;
   assign axi4s_hdr_out.aresetn          = __axi4s_hdr_out.aresetn;
   assign axi4s_hdr_out.tvalid           = __axi4s_hdr_out.tvalid;
   assign axi4s_hdr_out.tdata            = __axi4s_hdr_out.tdata;
   assign axi4s_hdr_out.tkeep            = __axi4s_hdr_out.tkeep;
   assign axi4s_hdr_out.tdest            = __axi4s_hdr_out.tdest;
   assign axi4s_hdr_out.tid              = __axi4s_hdr_out.tid;
   assign axi4s_hdr_out.tlast            = __axi4s_hdr_out.tlast;
   assign axi4s_hdr_out.tuser.pid        = (__axi4s_hdr_out.tvalid && __axi4s_hdr_out.sop) ? __axi4s_hdr_out.tuser.pid : {'0, pid};
   assign axi4s_hdr_out.tuser.hdr_tlast  = '0;

   assign __axi4s_hdr_out.tready         = axi4s_hdr_out.tready;

endmodule // axi4s_split
