// -----------------------------------------------------------------------------
// axi4s_trunc is used to truncate packets to a specified length.  It receives a
// packet stream on the ingress axi4s interface and drives the truncated packet
// stream out the egress axi4s interface (discarding the tail bytes).
// -----------------------------------------------------------------------------

module axi4s_trunc
   import axi4s_pkg::*;
#(
   parameter logic BIGENDIAN = 0,  // Little endian by default.
   parameter logic IN_PIPE  = 0,
   parameter logic OUT_PIPE = 0
) (
   axi4s_intf.rx axi4s_in,
   axi4s_intf.tx axi4s_out,

   input logic [15:0] length  // specified in bytes.
);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int COUNT_WID     =   $clog2(DATA_BYTE_WID);
   localparam type TID_T        = axi4s_in.TID_T;
   localparam type TDEST_T      = axi4s_in.TDEST_T;
   localparam type TUSER_T      = axi4s_in.TUSER_T;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_in_p ();
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_out_p ();


   // count_ones function 
   function automatic logic[COUNT_WID:0] count_ones (input [DATA_BYTE_WID-1:0] tkeep);
      automatic logic[COUNT_WID:0] count = 0;
      for (int i=0; i<DATA_BYTE_WID; i++) count = count + tkeep[i];
      return count;
   endfunction


   // trunc_tkeep function 
   function automatic logic[DATA_BYTE_WID-1:0] trunc_tkeep (input [DATA_BYTE_WID-1:0] tkeep_in, input [15:0] length);
      automatic logic [DATA_BYTE_WID-1:0] tkeep_out = 0;

      automatic logic [DATA_BYTE_WID-1:0] __tkeep_in, __tkeep_out;

      __tkeep_in = BIGENDIAN ? {<<{tkeep_in}} : tkeep_in;  // convert to little endian prior to for loop.

      for (int i=0; i<DATA_BYTE_WID; i++) begin
         if (i < length) __tkeep_out[i] = __tkeep_in[i];
         else            __tkeep_out[i] = 1'b0;
      end

      tkeep_out = BIGENDIAN ? {<<{__tkeep_out}} : __tkeep_out;  // convert back to big endian if required.

      return tkeep_out;
   endfunction


   // signals
   logic [15:0] byte_count;
   logic        trunc_select;
   logic        trunc_tlast;
   logic [15:0] tkeep_length;
   logic [15:0] length_p;


   generate
      if (IN_PIPE) begin
         axi4s_intf_pipe in_pipe_0 (.axi4s_if_from_tx(axi4s_in), .axi4s_if_to_rx(axi4s_in_p));
         always @(posedge axi4s_in.aclk) length_p <= (axi4s_in.tready && axi4s_in.tvalid && axi4s_in.sop) ? length : length_p;
      end else begin
         axi4s_intf_connector out_intf_connector_0 (.axi4s_from_tx(axi4s_in), .axi4s_to_rx(axi4s_in_p));
         assign length_p = length;
      end
   endgenerate


   // byte counter logic
   always @(posedge axi4s_in_p.aclk)
      if (!axi4s_in_p.aresetn)    byte_count <= '0;
      else if (axi4s_in_p.tvalid && axi4s_in_p.tready) begin
         if (axi4s_in_p.tlast)    byte_count <= '0;
         else if (trunc_select)   byte_count <= byte_count + count_ones(axi4s_in_p.tkeep);
      end

   // truncation selection logic 
   assign trunc_select = byte_count < length_p;
   assign tkeep_length = length_p - byte_count;
   assign trunc_tlast  = tkeep_length <= DATA_BYTE_WID;


   // axis4s input signalling.
   assign axi4s_in_p.tready = axi4s_out_p.tready;
   
   // axis4s output signalling - sends packets truncated to length.
   assign axi4s_out_p.aclk    = axi4s_in_p.aclk;
   assign axi4s_out_p.aresetn = axi4s_in_p.aresetn;
   assign axi4s_out_p.tvalid  = axi4s_in_p.tvalid && trunc_select;
   assign axi4s_out_p.tkeep   = trunc_tlast ? trunc_tkeep(axi4s_in_p.tkeep, tkeep_length) : (axi4s_out_p.tvalid ? axi4s_in_p.tkeep : '0);
   assign axi4s_out_p.tlast   = trunc_tlast || (axi4s_out_p.tvalid ? axi4s_in_p.tlast : 1'b0);
   assign axi4s_out_p.tdest   = axi4s_out_p.tvalid ? axi4s_in_p.tdest : '0;
   assign axi4s_out_p.tid     = axi4s_out_p.tvalid ? axi4s_in_p.tid   : '0;
   assign axi4s_out_p.tuser   = axi4s_out_p.tvalid ? axi4s_in_p.tuser : '0;

   always_comb for (int i=0; i<DATA_BYTE_WID; i++) axi4s_out_p.tdata[i] = axi4s_out_p.tkeep[i] ? axi4s_in_p.tdata[i] : '0;

   generate
      if (OUT_PIPE)
         axi4s_intf_pipe out_intf_pipe_0 (.axi4s_if_from_tx(axi4s_out_p), .axi4s_if_to_rx(axi4s_out));
      else
         axi4s_intf_connector out_intf_connector_0 (.axi4s_from_tx(axi4s_out_p), .axi4s_to_rx(axi4s_out));
   endgenerate

endmodule // axi4s_trunc
