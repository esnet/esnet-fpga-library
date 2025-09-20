// -----------------------------------------------------------------------------
// axi4s_trunc is used to truncate packets to a specified length.  It receives a
// packet stream on the ingress axi4s interface and drives the truncated packet
// stream out the egress axi4s interface (discarding the tail bytes).
// -----------------------------------------------------------------------------

module axi4s_trunc
   import axi4s_pkg::*;
#(
   parameter logic IN_PIPE  = 0,
   parameter logic OUT_PIPE = 1
) (
   input logic clk,
   input logic srst,
   axi4s_intf.rx axi4s_in,
   axi4s_intf.tx axi4s_out,

   input logic [15:0] length  // specified in bytes.
);

   // Check that input/output interfaces have identical parameterization
   axi4s_intf_parameter_check param_check_0 (.from_tx(axi4s_in), .to_rx(axi4s_out));

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int COUNT_WID     =   $clog2(DATA_BYTE_WID);
   localparam int TID_WID       = axi4s_in.TID_WID;
   localparam int TDEST_WID     = axi4s_in.TDEST_WID;
   localparam int TUSER_WID     = axi4s_in.TUSER_WID;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) axi4s_in_p (.aclk(axi4s_in.aclk), .aresetn(axi4s_in.aresetn));
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) axi4s_out_p (.aclk(axi4s_out.aclk), .aresetn(axi4s_out.aresetn));


   // count_ones function 
   function automatic logic[COUNT_WID:0] count_ones (input [DATA_BYTE_WID-1:0] tkeep);
      automatic logic[COUNT_WID:0] count = 0;
      for (int i=0; i<DATA_BYTE_WID; i++) count = count + tkeep[i];
      return count;
   endfunction


   // trunc_tkeep function 
   function automatic logic[DATA_BYTE_WID-1:0] trunc_tkeep (input [DATA_BYTE_WID-1:0] tkeep_in, input [15:0] length);
      automatic logic [DATA_BYTE_WID-1:0] tkeep_out = 0;

      for (int i=0; i<DATA_BYTE_WID; i++) begin
         if (i < length) tkeep_out[i] = tkeep_in[i];
         else            tkeep_out[i] = 1'b0;
      end

      return tkeep_out;
   endfunction


   // signals
   logic [15:0] byte_count;
   logic        trunc_select;
   logic        trunc_tlast;
   logic [15:0] tkeep_length;
   logic [15:0] length_p;


   generate
      if (IN_PIPE) begin : g__in_pipe
         axi4s_intf_pipe in_pipe_0 (.from_tx(axi4s_in), .to_rx(axi4s_in_p));
         initial length_p = 0;
         always @(posedge clk) length_p <= (axi4s_in.tready && axi4s_in.tvalid && axi4s_in.sop) ? length : length_p;
      end : g__in_pipe
      else begin : g__no_in_pipe
         axi4s_intf_connector out_intf_connector_0 (.from_tx(axi4s_in), .to_rx(axi4s_in_p));
         assign length_p = length;
      end : g__no_in_pipe
   endgenerate


   // byte counter logic
   initial byte_count = 0;
   always @(posedge clk)
      if (srst)                   byte_count <= '0;
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
   assign axi4s_out_p.tvalid  = axi4s_in_p.tvalid && trunc_select;
   assign axi4s_out_p.tkeep   = axi4s_out_p.tvalid ? (trunc_tlast ? trunc_tkeep(axi4s_in_p.tkeep, tkeep_length) : axi4s_in_p.tkeep) : '0;
   assign axi4s_out_p.tlast   = axi4s_out_p.tvalid ? trunc_tlast || axi4s_in_p.tlast : 1'b0;
   assign axi4s_out_p.tdest   = axi4s_out_p.tvalid ? axi4s_in_p.tdest : '0;
   assign axi4s_out_p.tid     = axi4s_out_p.tvalid ? axi4s_in_p.tid   : '0;
   assign axi4s_out_p.tuser   = axi4s_out_p.tvalid ? axi4s_in_p.tuser : '0;

   always_comb for (int i=0; i<DATA_BYTE_WID; i++) axi4s_out_p.tdata[i] = axi4s_out_p.tkeep[i] ? axi4s_in_p.tdata[i] : '0;

   generate
      if (OUT_PIPE) begin : g__out_pipe
         axi4s_intf_pipe out_intf_pipe_0 (.from_tx(axi4s_out_p), .to_rx(axi4s_out));
      end : g__out_pipe
      else begin : g__no_out_pipe
         axi4s_intf_connector out_intf_connector_0 (.from_tx(axi4s_out_p), .to_rx(axi4s_out));
      end : g__no_out_pipe
   endgenerate

endmodule // axi4s_trunc
