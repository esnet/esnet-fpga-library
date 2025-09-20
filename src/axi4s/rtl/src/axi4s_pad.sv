// -----------------------------------------------------------------------------
// axi4s_pad is used to zero-pad packets that are less than 60B.
// NOTE: DATA_BYTE_WID MUST be > 60B.
// -----------------------------------------------------------------------------

module axi4s_pad
   import axi4s_pkg::*;
(
   axi4s_intf.rx axi4s_in,
   axi4s_intf.tx axi4s_out
);

   localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;

   // signals
   logic short_pkt;
   logic [DATA_BYTE_WID-1:0][7:0] pad_tdata;


   // pad_tkeep function 
   function automatic logic[DATA_BYTE_WID-1:0] pad_tkeep (input [DATA_BYTE_WID-1:0] tkeep_in);
      automatic logic [DATA_BYTE_WID-1:0] tkeep_out;

      tkeep_out = { tkeep_in[DATA_BYTE_WID-1:60], 60'hfff_ffff_ffff_ffff };

      return tkeep_out;
   endfunction

   assign short_pkt = axi4s_in.tvalid && axi4s_in.sop && axi4s_in.tlast;

   always_comb for (int i=0; i<DATA_BYTE_WID; i++) pad_tdata[i] = axi4s_in.tkeep[i] ? axi4s_in.tdata[i] : 8'h00; 


   // axis4s input signalling.
   assign axi4s_in.tready = axi4s_out.tready;
   
   // axis4s output signalling.
   assign axi4s_out.tvalid  = axi4s_in.tvalid;
   assign axi4s_out.tdata   = pad_tdata;
   assign axi4s_out.tkeep   = short_pkt ? pad_tkeep(axi4s_in.tkeep) : axi4s_in.tkeep;
   assign axi4s_out.tdest   = axi4s_in.tdest;
   assign axi4s_out.tid     = axi4s_in.tid;
   assign axi4s_out.tlast   = axi4s_in.tlast;
   assign axi4s_out.tuser   = axi4s_in.tuser;

endmodule // axi4s_pad
