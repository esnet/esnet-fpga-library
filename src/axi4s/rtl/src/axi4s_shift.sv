// -----------------------------------------------------------------------------
// axi4s_shift is a barrel shifter that rotates the byte order of the ingress
// tdata bus by a specified number of positions.  Lower order bytes are shifted
// into higher byte positions, and higher order bytes are circulated back into 
// the lower order byte positions.
// -----------------------------------------------------------------------------

module axi4s_shift
   import axi4s_pkg::*;
#(
   parameter int   SHIFT_WID = 6
) (
   axi4s_intf.rx   axi4s_in,
   axi4s_intf.tx   axi4s_out,

   input logic [SHIFT_WID-1:0] shift  // shift magnitude - specified in byte positions.
);

   localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_in.TID_T;
   localparam type TDEST_T       = axi4s_in.TDEST_T;
   localparam type TUSER_T       = axi4s_in.TUSER_T;

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) ) axi4s_shift ();

   logic [DATA_BYTE_WID-1:0][7:0] tdata, _tdata;
   logic [DATA_BYTE_WID-1:0]      tkeep, _tkeep;

   assign _tdata = axi4s_in.tdata;
   assign _tkeep = axi4s_in.tkeep;

   // circular shift
   always_comb begin  
      tkeep = ({_tkeep, _tkeep} << shift)   >> DATA_BYTE_WID;
      tdata = ({_tdata, _tdata} << shift*8) >> DATA_BYTE_WID*8;
   end


   // axis4s_in interface signalling.
   assign axi4s_in.tready = axi4s_shift.tready;

   // axis4s_shift interface signalling.
   assign axi4s_shift.aclk    = axi4s_in.aclk;
   assign axi4s_shift.aresetn = axi4s_in.aresetn;
   assign axi4s_shift.tvalid  = axi4s_in.tvalid;
   assign axi4s_shift.tlast   = axi4s_in.tlast;
   assign axi4s_shift.tid     = axi4s_in.tid;
   assign axi4s_shift.tdest   = axi4s_in.tdest;
   assign axi4s_shift.tuser   = axi4s_in.tuser;
   assign axi4s_shift.tdata   = tdata; // convert back to big endian.
   assign axi4s_shift.tkeep   = tkeep;

   // output pipeline stage (optional)
//   axi4s_intf_pipe axi4s_intf_pipe_0 (
//      .axi4s_if_from_tx (axi4s_shift),
//      .axi4s_if_to_rx   (axi4s_out)
//   );

   axi4s_intf_connector axi4s_intf_connector_0 (.axi4s_from_tx(axi4s_shift), .axi4s_to_rx(axi4s_out));
   
endmodule // axi4s_shift
