// -----------------------------------------------------------------------------
// axi4s_sync is used to synchronize two packet streams.  As packet data is
// pulled from the two independent egress interfaces, the first ingress packet
// stream to reach the synchronizing event is stalled until the other ingress
// packet stream reach the same event.
//
// The block supports:
// - SOP Mode: Synchonizes ingress pkt streams to the sop word (start of pkt).
// - HDR_TLAST Mode: Synchonizes ingress pkt streams to the last header word.
//   Note: HDR_TLAST mode requires the header packet stream to be connected to
//         axi4s_in0 and the payload packet stream to be connected to axi4s_in1.
// -----------------------------------------------------------------------------

module axi4s_sync
   import axi4s_pkg::*;
#(
   parameter axi4s_sync_mode_t MODE = SOP
) ( 
   axi4s_intf.rx    axi4s_in0,  axi4s_in1,
   axi4s_intf.tx    axi4s_out0, axi4s_out1,

   output logic     sop_mismatch
);

   localparam type TUSER_T = axi4s_in0.TUSER_T;

   TUSER_T tuser_in0, tuser_in1;

   logic  sync_sop, match, mismatch;
   logic  sync, sync0, sync1;

   assign tuser_in0 = axi4s_in0.tuser;
   assign tuser_in1 = axi4s_in1.tuser;

   assign sync_sop = axi4s_in0.sop && axi4s_in0.tvalid && axi4s_in1.sop && axi4s_in1.tvalid;
   assign match = (tuser_in0.pid == tuser_in1.pid);
   assign mismatch = !match;

   assign sop_mismatch = sync_sop && mismatch;

   always_comb begin
      case (MODE)
        SOP : begin
          // synchronize sop words and validate wr pointers (pkt id).
          sync  = sync_sop && match;
          sync0 = (sync && axi4s_out1.tready) || !axi4s_in0.sop;
          sync1 = (sync && axi4s_out0.tready) || !axi4s_in1.sop;
        end

        HDR_TLAST : begin
          // synchronize hdr tlast words (using payload buffer context).
          sync  = axi4s_in0.tvalid && axi4s_in0.tlast && axi4s_in1.tvalid && tuser_in1.hdr_tlast;
          sync0 = (sync && axi4s_out1.tready) || !(axi4s_in0.tvalid && axi4s_in0.tlast);
          sync1 = (sync && axi4s_out0.tready) || !(axi4s_in1.tvalid && tuser_in1.hdr_tlast);
        end

        default : begin
          sync  = 0;
          sync0 = 0;
          sync1 = 0;
        end
      endcase
   end


   // axis4s in0 interface signalling.
   assign axi4s_in0.tready = axi4s_out0.tready && sync0;

   // axis4s out0 interface signalling.
   assign axi4s_out0.aclk    = axi4s_in0.aclk;
   assign axi4s_out0.aresetn = axi4s_in0.aresetn;
   assign axi4s_out0.tvalid  = axi4s_in0.tvalid && sync0;
   assign axi4s_out0.tdata   = axi4s_in0.tdata;
   assign axi4s_out0.tkeep   = axi4s_in0.tkeep;
   assign axi4s_out0.tlast   = axi4s_in0.tlast;
   assign axi4s_out0.tid     = axi4s_in0.tid;
   assign axi4s_out0.tdest   = axi4s_in0.tdest;
   assign axi4s_out0.tuser   = axi4s_in0.tuser;

   // axis4s in1 interface signalling.
   assign axi4s_in1.tready = axi4s_out1.tready && sync1;

   // axis4s out1 interface signalling.
   assign axi4s_out1.aclk    = axi4s_in1.aclk;
   assign axi4s_out1.aresetn = axi4s_in1.aresetn;
   assign axi4s_out1.tvalid  = axi4s_in1.tvalid && sync1;
   assign axi4s_out1.tdata   = axi4s_in1.tdata;
   assign axi4s_out1.tkeep   = axi4s_in1.tkeep;
   assign axi4s_out1.tlast   = axi4s_in1.tlast;
   assign axi4s_out1.tid     = axi4s_in1.tid;
   assign axi4s_out1.tdest   = axi4s_in1.tdest;
   assign axi4s_out1.tuser   = axi4s_in1.tuser;

endmodule // axi4s_sync
