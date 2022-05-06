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
// axi4s_join is used to rejoin a stream of packet header and payload data.
// It receives a header packet stream on the ingress header axi4s interface.
// It then reads the associated payload packet through another ingress axi4s 
// interface. It drives the joined packet stream out the egress axi4s interface.
// -----------------------------------------------------------------------------

module axi4s_join
   import axi4s_pkg::*;
#(
   parameter PTR_LEN = 16  // wordlength of wr_ptr (used for buffer context).
)  (
   axi4s_intf.rx            axi4s_hdr_in,
   axi4s_intf.rx            axi4s_in,
   axi4s_intf.tx            axi4s_out,

   output logic             rd_req,
   output logic [PTR_LEN:0] rd_ptr
);

   // state machine signals and logic.
   typedef enum logic {
      HEADER,
      PAYLOAD
   } state_t;

   state_t state, state_nxt; 

   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn) state <= HEADER;
      else                   state <= state_nxt;

   always_comb begin
      state_nxt = state;
      case (state)
        HEADER  : begin
           // transition from HEADER to PAYLOAD if last hdr word, but NOT last pkt word.
           if (axi4s_hdr_in.tready && axi4s_hdr_in.tvalid && 
               axi4s_hdr_in.tlast && !axi4s_hdr_in.tuser.tlast) state_nxt = PAYLOAD;
        end
        PAYLOAD : begin
           // transition from PAYLOAD to HEADER if last pkt word.
           if (axi4s_in.tready && axi4s_in.tvalid && axi4s_in.tlast) state_nxt = HEADER;
        end
        default : state_nxt = state;
      endcase
   end
   


   assign rd_req = (state_nxt == PAYLOAD);  // read from axi4s_in when in PAYLOAD state.
   
   // rd_ptr is based on wr_ptr in last header word, or previous payload word (depending on state).
   assign rd_ptr = (state == PAYLOAD) ? axi4s_in.tuser.wr_ptr + 1 : axi4s_hdr_in.tuser.wr_ptr + 1;

   // axis4s hdr interface signalling.
   assign axi4s_hdr_in.tready = axi4s_out.tready && (state == HEADER);
   
   // axis4s input interface signalling.
   assign axi4s_in.tready = axi4s_out.tready && (state == PAYLOAD);
   
   // axis4s output interface signalling.
   assign axi4s_out.aclk    = axi4s_in.aclk;
   assign axi4s_out.aresetn = axi4s_in.aresetn;
   assign axi4s_out.tvalid  = (state == HEADER) ? axi4s_hdr_in.tvalid      : axi4s_in.tvalid;
   assign axi4s_out.tdata   = (state == HEADER) ? axi4s_hdr_in.tdata       : axi4s_in.tdata;
   assign axi4s_out.tkeep   = (state == HEADER) ? axi4s_hdr_in.tkeep       : axi4s_in.tkeep;
   assign axi4s_out.tdest   = (state == HEADER) ? axi4s_hdr_in.tdest       : axi4s_in.tdest;
   assign axi4s_out.tid     = (state == HEADER) ? axi4s_hdr_in.tid         : axi4s_in.tid;
   assign axi4s_out.tlast   = (state == HEADER) ? axi4s_hdr_in.tuser.tlast : axi4s_in.tlast;
   assign axi4s_out.tuser   = '0;

endmodule // axi4s_join
