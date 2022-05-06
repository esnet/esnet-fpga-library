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
(
   axi4s_intf.rx axi4s_in,
   axi4s_intf.tx axi4s_out,

   input logic [7:0] length  // specified in words (valid range is >= 1).
);

   // signals
   logic [7:0] word_count;
   logic       trunc_select;
   logic       trunc_tlast;

   // truncation selection logic 
   assign trunc_select = (word_count <  length);
   assign trunc_tlast  = (word_count == length-1);

   // word counter logic
   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn) word_count <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready) begin
         if (axi4s_in.tlast)    word_count <= '0;
         else if (trunc_select) word_count <= word_count + 1;
      end
   
   // axis4s input signalling.
   assign axi4s_in.tready = axi4s_out.tready;
   
   // axis4s output signalling - sends packets truncated to length.
   assign axi4s_out.aclk    = axi4s_in.aclk;
   assign axi4s_out.aresetn = axi4s_in.aresetn;
   assign axi4s_out.tvalid  = axi4s_in.tvalid && trunc_select;
   assign axi4s_out.tdata   = axi4s_in.tdata;
   assign axi4s_out.tkeep   = axi4s_in.tkeep;
   assign axi4s_out.tdest   = axi4s_in.tdest;
   assign axi4s_out.tid     = axi4s_in.tid;
   assign axi4s_out.tlast   = axi4s_in.tlast || trunc_tlast;
   assign axi4s_out.tuser   = axi4s_in.tuser;

endmodule // axi4s_trunc
