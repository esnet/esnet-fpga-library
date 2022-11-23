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
// axi4s_pad is used to zero-pad packets that are less than 60B.
// NOTE: DATA_BYTE_WID MUST be > 60B.
// -----------------------------------------------------------------------------

module axi4s_pad
   import axi4s_pkg::*;
#(
   parameter logic BIGENDIAN = 0  // Little endian by default.
) (
   axi4s_intf.rx axi4s_in,
   axi4s_intf.tx axi4s_out
);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;

   // signals
   logic short_pkt;
   logic [DATA_BYTE_WID-1:0][7:0] pad_tdata;


   // pad_tkeep function 
   function automatic logic[DATA_BYTE_WID-1:0] pad_tkeep (input [DATA_BYTE_WID-1:0] tkeep_in);
      automatic logic [DATA_BYTE_WID-1:0] __tkeep_in, __tkeep_out, tkeep_out;

      __tkeep_in = BIGENDIAN ? {<<{tkeep_in}} : tkeep_in;  // convert to little endian prior to for loop.

      __tkeep_out = { __tkeep_in[DATA_BYTE_WID-1:60], 60'hfff_ffff_ffff_ffff };

      tkeep_out = BIGENDIAN ? {<<{__tkeep_out}} : __tkeep_out;  // convert back to big endian if required.

      return tkeep_out;
   endfunction

   assign short_pkt = axi4s_in.tvalid && axi4s_in.sop && axi4s_in.tlast;

   always_comb for (int i=0; i<DATA_BYTE_WID; i++) pad_tdata[i] = axi4s_in.tkeep[i] ? axi4s_in.tdata[i] : 8'h00; 


   // axis4s input signalling.
   assign axi4s_in.tready = axi4s_out.tready;
   
   // axis4s output signalling.
   assign axi4s_out.aclk    = axi4s_in.aclk;
   assign axi4s_out.aresetn = axi4s_in.aresetn;
   assign axi4s_out.tvalid  = axi4s_in.tvalid;
   assign axi4s_out.tdata   = pad_tdata;
   assign axi4s_out.tkeep   = short_pkt ? pad_tkeep(axi4s_in.tkeep) : axi4s_in.tkeep;
   assign axi4s_out.tdest   = axi4s_in.tdest;
   assign axi4s_out.tid     = axi4s_in.tid;
   assign axi4s_out.tlast   = axi4s_in.tlast;
   assign axi4s_out.tuser   = axi4s_in.tuser;

endmodule // axi4s_pad
