// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
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
// axi4s_pkt_discard_ovfl is used to discard the full ingress packet when an axi4s 
// data transaction fails due fifo overflow.   This component should be used on 
// any axi4s interface that ignores the tready flow control signal. 
// axi4s_pkt_discard_ovfl is a synchronous component which employs a memory sized to
// buffer up to 3 max packets.
// -----------------------------------------------------------------------------

module axi4s_pkt_discard_ovfl
   import axi4s_pkg::*;
#(
   parameter int MAX_PKT_LEN = 9100  // max number of bytes per packet.
)  (
   axi4s_intf.rx   axi4s_in,
   axi4s_intf.tx   axi4s_out
);

   // axi4s_in interface params
   localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_in.TID_T;
   localparam type TDEST_T       = axi4s_in.TDEST_T;
   localparam type TUSER_T       = axi4s_in.TUSER_T;

   // fifo params
   localparam int MAX_PKT_WRDS = $ceil($itor(MAX_PKT_LEN) / $itor(DATA_BYTE_WID));
   localparam int FIFO_DEPTH   = MAX_PKT_WRDS * 3;  // depth supports 3 max pkts.
   localparam int ADDR_WID     = $clog2(FIFO_DEPTH);


   // error detection signals
   logic pkt_error;

   // ovfl discard signals
   logic [ADDR_WID:0] sop_ptr;
   logic              discard;
   logic              tx_pending;

   // fifo context signals
   logic [ADDR_WID:0] wr_ptr, wr_ptr_p, wr_ptr_nxt;
   logic [ADDR_WID:0] rd_ptr;
   logic              rd_req;

   logic [ADDR_WID:0] fill_level;
   logic              almost_full;
   logic              ovfl;
   logic              empty;



   // _axis4s_in signal assignments.
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) 
              _axi4s_in ();

   assign _axi4s_in.aclk    = axi4s_in.aclk;
   assign _axi4s_in.aresetn = axi4s_in.aresetn;
   assign _axi4s_in.tvalid  = axi4s_in.tvalid;
   assign _axi4s_in.tdata   = axi4s_in.tdata;
   assign _axi4s_in.tkeep   = axi4s_in.tkeep;
   assign _axi4s_in.tdest   = axi4s_in.tdest;
   assign _axi4s_in.tid     = axi4s_in.tid;
   assign _axi4s_in.tlast   = axi4s_in.tlast;
   assign _axi4s_in.tuser   = axi4s_in.tuser;

   assign axi4s_in.tready = _axi4s_in.tready && !(discard || ovfl);


   // ---- error detection logic ----
   assign pkt_error = (axi4s_in.TUSER_MODE == PKT_ERROR) && axi4s_in.tuser;


   // ---- ovfl discard logic ----
   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn) begin
         sop_ptr <= 0;
         discard <= 0;
      end else begin
         if (axi4s_in.tready && axi4s_in.tvalid && axi4s_in.tlast && !pkt_error) sop_ptr <= wr_ptr_nxt; // save last sop pointer.

         // if discard is asserted, deassert discard at the end of the inbound packet.
	 // else assert discard signal when fifo overflow occurs.
         if (discard && axi4s_in.tvalid && axi4s_in.tlast) discard <= 1'b0;
         else if (ovfl) discard <= 1'b1;
      end


   // ---- write context logic ----
   assign wr_ptr_nxt = wr_ptr + 1;

   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn) wr_ptr <= '0;   
      else if (axi4s_in.tvalid) begin
	 // restore sop pointer when tlast is asserted and a discard is in progress or a pkt error is detected.
	 // otherwise increment pointer for each valid transfer.
         if (axi4s_in.tlast && (discard || pkt_error))  wr_ptr <= sop_ptr;
         else if (axi4s_in.tready)                      wr_ptr <= wr_ptr_nxt;
      end

   // assert almost_full when there is only FIFO space for one more ingress packet.
   assign fill_level  = wr_ptr-rd_ptr;
   assign almost_full = fill_level > (FIFO_DEPTH-MAX_PKT_WRDS);

   // assert fifo_overflow if almost_full is asserted when new packet arrives i.e. tvalid && sop.
   assign ovfl = almost_full && axi4s_in.tvalid && axi4s_in.sop;





   // ---- pkt buffer instantiation ----
   axi4s_pkt_buffer #(
      .ADDR_WID (ADDR_WID)
   ) axi4s_pkt_buffer_0 (
      .axi4s_in    (_axi4s_in),
      .axi4s_out   (axi4s_out),
      .rd_req      (rd_req),
      .rd_ptr      (rd_ptr),
      .wr_ptr      (wr_ptr),
      .wr_ptr_p    (wr_ptr_p)
   );




   // ---- read context logic ----
   assign rd_req  = axi4s_out.tready && !empty && !tx_pending;

   always @(posedge axi4s_out.aclk)
      if (!axi4s_out.aresetn)  rd_ptr <= 0;
      else if (rd_req)         rd_ptr <= rd_ptr + 1;

   // assert tx_pending if rd_ptr reaches sop_ptr.
   // defers transfer until sop is overwritten on tlast, and the full packet is buffered.
   assign tx_pending = (rd_ptr == sop_ptr);

   // assert empty when pipelined wr_ptr equals rd_ptr.
   assign empty = (rd_ptr == wr_ptr_p);

endmodule
