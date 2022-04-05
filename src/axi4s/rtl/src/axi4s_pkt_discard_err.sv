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
// axi4s_pkt_discard_err is a pass-through block that is designed to discard 
// the full packet when its first axi4s transaction flags the packet as errored.
// -----------------------------------------------------------------------------

module axi4s_pkt_discard_err
   import axi4s_pkg::*;
(
   axi4s_intf.rx           axi4s_in_if,
   axi4s_intf.tx           axi4s_out_if,
   axi4l_intf.peripheral   axi4l_if
);

   logic err_sop, err_pkt;

   // assert err_sop if first axi4s transaction has error flag set.
   assign err_sop = axi4s_in_if.tvalid && axi4s_in_if.tready && axi4s_in_if.sop &&
                   (axi4s_in_if.TUSER_MODE == ERRORED) && axi4s_in_if.tuser;

   always @(posedge axi4s_in_if.aclk)
      if (~axi4s_in_if.aresetn) err_pkt <= 0;
      else 
         // if err_pkt is asserted, deassert err_pkt at end of inbound packet.
         // else assert err_pkt when inbound packet has error flag set (and if not tlast).
         if (err_pkt && axi4s_in_if.tvalid && axi4s_in_if.tready && axi4s_in_if.tlast) 
            err_pkt <= 1'b0;
         else if (err_sop && !axi4s_in_if.tlast)
            err_pkt <= 1'b1;

   // axis4s input signalling.
   assign axi4s_in_if.tready = axi4s_out_if.tready;

   // axis4s output signalling. gate tvalid when packet is errored.
   assign axi4s_out_if.aclk    = axi4s_in_if.aclk;
   assign axi4s_out_if.aresetn = axi4s_in_if.aresetn;
   assign axi4s_out_if.tvalid  = axi4s_in_if.tvalid && !(err_sop || err_pkt);
   assign axi4s_out_if.tdata   = axi4s_in_if.tdata;
   assign axi4s_out_if.tkeep   = axi4s_in_if.tkeep;
   assign axi4s_out_if.tdest   = axi4s_in_if.tdest;
   assign axi4s_out_if.tid     = axi4s_in_if.tid;
   assign axi4s_out_if.tlast   = axi4s_in_if.tlast;
   assign axi4s_out_if.tuser   = axi4s_in_if.tuser;


   // error counter logic
   axi4s_intf  #( 
      .MODE          (axi4s_in_if.MODE), 
      .TUSER_MODE    (axi4s_in_if.TUSER_MODE), 
      .DATA_BYTE_WID (axi4s_in_if.DATA_BYTE_WID)
   ) __axi4s_in_if ();

   // __axis4s_in_if assignments. ensure tuser is high for full packet if error is detected on sop.
   assign __axi4s_in_if.aclk    = axi4s_in_if.aclk;
   assign __axi4s_in_if.aresetn = axi4s_in_if.aresetn;
   assign __axi4s_in_if.tready  = axi4s_in_if.tready;
   assign __axi4s_in_if.tvalid  = axi4s_in_if.tvalid;
   assign __axi4s_in_if.tlast   = axi4s_in_if.tlast;
   assign __axi4s_in_if.tkeep   = axi4s_in_if.tkeep;
   assign __axi4s_in_if.tuser   = err_sop || err_pkt;
   assign __axi4s_in_if.tdata   = '0;
   assign __axi4s_in_if.tid     = '0;
   assign __axi4s_in_if.tdest   = '0;

   // instantiate error counters
   axi4s_probe #( .MODE(ERRORS) ) axi4s_errors (
      .axi4l_if  (axi4l_if),
      .axi4s_if  (__axi4s_in_if)
   );

endmodule
