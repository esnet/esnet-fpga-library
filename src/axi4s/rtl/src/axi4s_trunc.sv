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
// axi4s_trunc is used to truncate packets to a specified length.  It receives a
// packet stream on the ingress axi4s interface and drives the truncated packet
// stream out the egress axi4s interface (discarding the tail bytes).
// -----------------------------------------------------------------------------

module axi4s_trunc
   import axi4s_pkg::*;
#(
   parameter logic BIGENDIAN = 0  // Little endian by default.
) (
   axi4s_intf.rx axi4s_in,
   axi4s_intf.tx axi4s_out,

   input logic [15:0] length  // specified in bytes (valid range is >= 1).
);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam int COUNT_WID     =   $clog2(DATA_BYTE_WID);


   // count_ones function 
   function automatic logic[COUNT_WID:0] count_ones (input [DATA_BYTE_WID-1:0] tkeep);
      automatic logic[COUNT_WID:0] count = 0;
      for (int i=0; i<DATA_BYTE_WID; i++) count = count + tkeep[i];
      return count;
   endfunction


   // trunc_tkeep function 
   function automatic logic[DATA_BYTE_WID-1:0] trunc_tkeep (input [DATA_BYTE_WID-1:0] tkeep_in, length);
      automatic logic [DATA_BYTE_WID-1:0] tkeep_out = 0;
      automatic logic [COUNT_WID:0]       count = 0;

      automatic logic [DATA_BYTE_WID-1:0] __tkeep_in, __tkeep_out;

      __tkeep_in = BIGENDIAN ? {<<{tkeep_in}} : tkeep_in;  // convert to little endian prior to for loop.

      for (int i=0; i<DATA_BYTE_WID; i++) begin
         if (count < length) __tkeep_out[i] = __tkeep_in[i];
         else                __tkeep_out[i] = 1'b0;

         count = count + __tkeep_in[i];
      end

      tkeep_out = BIGENDIAN ? {<<{__tkeep_out}} : __tkeep_out;  // convert back to big endian if required.

      return tkeep_out;
   endfunction


   // signals
   logic [15:0] byte_count;
   logic        trunc_select;
   logic        trunc_tlast;
   logic [15:0] tkeep_length;

   // byte counter logic
   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn) byte_count <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready) begin
         if (axi4s_in.tlast)    byte_count <= '0;
         else if (trunc_select) byte_count <= byte_count + count_ones(axi4s_in.tkeep);
      end

   // truncation selection logic 
   assign trunc_select = byte_count < length;
   assign trunc_tlast  = length - byte_count <= DATA_BYTE_WID;
   assign tkeep_length = length - byte_count;


   // axis4s input signalling.
   assign axi4s_in.tready = axi4s_out.tready;
   
   // axis4s output signalling - sends packets truncated to length.
   assign axi4s_out.aclk    = axi4s_in.aclk;
   assign axi4s_out.aresetn = axi4s_in.aresetn;
   assign axi4s_out.tvalid  = axi4s_in.tvalid && trunc_select;
   assign axi4s_out.tdata   = axi4s_in.tdata;
   assign axi4s_out.tkeep   = axi4s_out.tlast ? trunc_tkeep(axi4s_in.tkeep, tkeep_length) : axi4s_in.tkeep;
   assign axi4s_out.tdest   = axi4s_in.tdest;
   assign axi4s_out.tid     = axi4s_in.tid;
   assign axi4s_out.tlast   = axi4s_in.tlast || trunc_tlast;
   assign axi4s_out.tuser   = axi4s_in.tuser;

endmodule // axi4s_trunc
