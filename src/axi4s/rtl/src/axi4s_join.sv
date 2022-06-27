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
   parameter logic BIGENDIAN = 0  // Little endian by default.
)  (
   axi4s_intf.rx   axi4s_hdr_in,
   axi4s_intf.rx   axi4s_in,
   axi4s_intf.tx   axi4s_out
);

   localparam int  DATA_BYTE_WID = axi4s_hdr_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_hdr_in.TID_T;
   localparam type TDEST_T       = axi4s_hdr_in.TDEST_T;
   localparam type TUSER_T       = axi4s_hdr_in.TUSER_T;
   localparam int  COUNT_WID     = $clog2(DATA_BYTE_WID);

   // signals
   typedef enum logic[1:0] {
      HEADER,
      PAYLOAD,
      LAST_PAYLOAD
   } state_t;

   state_t state, state_nxt; 

   logic [COUNT_WID:0] pyld_shift;
   logic [COUNT_WID:0] pyld_shift_pipe[2];
   logic               drop_pkt;

   TID_T    hdr_tid;
   TDEST_T  hdr_tdest;

   // TODO: consider adding an interface check for buffer context mode.
   // internal axi4s interfaces.
   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) sync_hdr[2] ();

   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) sync_pyld[2] ();

   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) drop[2] ();

   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID), 
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) pipe_hdr[3] ();

   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) pipe_pyld[3] ();

   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) shifted_pyld ();

   axi4s_intf #(.TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID), 
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) joined ();

   logic clk, resetn;

   assign clk    = axi4s_in.aclk;
   assign resetn = axi4s_in.aresetn;



   // axi4s SOP synchronizer instantiation.
   axi4s_sync #(.MODE(SOP)) axi4s_sync_0 (
      .axi4s_in0   (axi4s_hdr_in),
      .axi4s_in1   (axi4s_in),
      .axi4s_out0  (sync_hdr[0]),
      .axi4s_out1  (sync_pyld[0])
   );

   assign drop_pkt = sync_hdr[0].tready && sync_hdr[0].tvalid && sync_hdr[0].sop &&
                     sync_hdr[0].tlast  && sync_hdr[0].tkeep == '0;

   // axi4s header drop instantiation.
   axi4s_drop axi4s_drop_0 (
      .axi4s_in    (sync_hdr[0]),
      .axi4s_out   (drop[0]),
      .drop_pkt    (drop_pkt)
   );

   // axi4s payload drop instantiation.
   axi4s_drop axi4s_drop_1 (
      .axi4s_in    (sync_pyld[0]),
      .axi4s_out   (drop[1]),
      .drop_pkt    (drop_pkt)
   );

   // axi4s HDR_TLAST synchronizer instantiation.
   axi4s_sync #(.MODE(HDR_TLAST)) axi4s_sync_1 (
      .axi4s_in0   (drop[0]),
      .axi4s_in1   (drop[1]),
      .axi4s_out0  (sync_hdr[1]),
      .axi4s_out1  (sync_pyld[1])
   );

   

   // axi4s hdr pipeline.
   axi4s_intf_pipe #(.MODE(PUSH)) hdr_pipe_0 (
      .axi4s_if_from_tx (sync_hdr[1]),
      .axi4s_if_to_rx   (pipe_hdr[0])
   );

   axi4s_intf_pipe #(.MODE(PUSH)) hdr_pipe_1 (
      .axi4s_if_from_tx (pipe_hdr[0]),
      .axi4s_if_to_rx   (pipe_hdr[1])
   );

   axi4s_intf_pipe #(.MODE(PUSH)) hdr_pipe_2 (
      .axi4s_if_from_tx (pipe_hdr[1]),
      .axi4s_if_to_rx   (pipe_hdr[2])
   );

   assign pipe_hdr[2].tready = pipe_pyld[2].tready;  // drive pipe_hdr and pipe_pyld with common tready.


   
   // axi4s pyld pipeline.
   axi4s_intf_pipe #(.MODE(PUSH)) pyld_pipe_0 (
      .axi4s_if_from_tx (sync_pyld[1]),
      .axi4s_if_to_rx   (pipe_pyld[0])
   );

   // axi4s barrel shifter instantiation.
   axi4s_shift #(
      .BIGENDIAN (BIGENDIAN),
      .SHIFT_WID (COUNT_WID)
   ) axi4s_shift_0 (
      .axi4s_in   (pipe_pyld[0]),
      .axi4s_out  (shifted_pyld),
      .shift      (pyld_shift[COUNT_WID-1:0])
   );

   axi4s_intf_pipe #(.MODE(PUSH)) pyld_pipe_1 (
      .axi4s_if_from_tx (shifted_pyld),
      .axi4s_if_to_rx   (pipe_pyld[1])
   );

   axi4s_intf_pipe #(.MODE(PUSH)) pyld_pipe_2 (
      .axi4s_if_from_tx (pipe_pyld[1]),
      .axi4s_if_to_rx   (pipe_pyld[2])
   );

   assign pipe_pyld[2].tready = joined.tready;



   // capture required payload shift.
   assign pyld_shift = (pipe_hdr[0].tvalid && pipe_hdr[0].tready) ?
                       tkeep_to_shift (pipe_hdr[0].tkeep) : pyld_shift_pipe[0];

   always @(posedge clk)
      if (!resetn) begin
         pyld_shift_pipe[0] <= '0;
         pyld_shift_pipe[1] <= '0;
      end else begin 
         if (pipe_hdr[0].tvalid && pipe_hdr[0].tready)  pyld_shift_pipe[0] <= pyld_shift;
         if (pipe_hdr[1].tvalid && pipe_hdr[1].tready)  pyld_shift_pipe[1] <= pyld_shift_pipe[0];
      end



   // state machine logic.
   always @(posedge clk)
      if (!resetn)  state <= HEADER;
      else          state <= state_nxt;

   always_comb begin
      state_nxt = state;
      case (state)

        HEADER : begin
           // transition from HEADER to PAYLOAD or LAST_PAYLOAD if last hdr word, but NOT last pkt word.
           if (pipe_hdr[2].tready && pipe_hdr[2].tvalid && pipe_hdr[2].tlast && !(pipe_pyld[2].tlast && pipe_pyld[2].tvalid)) begin
              if (pipe_pyld[1].tlast && pipe_pyld[1].tvalid) state_nxt = LAST_PAYLOAD;
              else                                           state_nxt = PAYLOAD;
           end
        end
        PAYLOAD : begin
           // transition from PAYLOAD to LAST_PAYLOAD if last pkt word.
           if (pipe_pyld[1].tready && pipe_pyld[1].tvalid && pipe_pyld[1].tlast) state_nxt = LAST_PAYLOAD;
        end
        LAST_PAYLOAD : begin
           // transition from LAST_PAYLOAD back to HEADER at end of pkt.
           if (pipe_pyld[2].tready && pipe_pyld[2].tvalid && pipe_pyld[2].tlast) state_nxt = HEADER;
        end
        default : state_nxt = state;
      endcase
   end

   // hdr and pyld joining assignments.
   always_comb begin
      case (state)
        HEADER : begin
           // if last header word AND last packet word.
           if (pipe_hdr[2].tready && pipe_hdr[2].tvalid && pipe_hdr[2].tlast && pipe_pyld[2].tlast) begin
              joined.tdata   = join_tdata (.shift(pyld_shift_pipe[1]), .tdata_lsb( pipe_hdr[2].tdata), .tdata_msb('0));
              joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[1]), .tkeep_lsb( pipe_hdr[2].tkeep), .tkeep_msb('0));
              joined.tvalid  = pipe_hdr[2].tvalid;
           end else begin
              joined.tdata   = join_tdata (.shift(pyld_shift_pipe[1]), .tdata_lsb( pipe_hdr[2].tdata), .tdata_msb(pipe_pyld[1].tdata));
              joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[1]), .tkeep_lsb( pipe_hdr[2].tkeep), .tkeep_msb(pipe_pyld[1].tkeep));
              joined.tvalid  = pipe_hdr[2].tvalid;
           end
        end
        PAYLOAD : begin
           joined.tdata   = join_tdata (.shift(pyld_shift_pipe[1]), .tdata_lsb(pipe_pyld[2].tdata), .tdata_msb(pipe_pyld[1].tdata));
           joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[1]), .tkeep_lsb(pipe_pyld[2].tkeep), .tkeep_msb(pipe_pyld[1].tkeep));
           joined.tvalid  = pipe_pyld[2].tvalid;
        end
        LAST_PAYLOAD : begin
           joined.tdata   = join_tdata (.shift(pyld_shift_pipe[1]), .tdata_lsb(pipe_pyld[2].tdata), .tdata_msb('0));
           joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[1]), .tkeep_lsb(pipe_pyld[2].tkeep), .tkeep_msb('0));
           joined.tvalid  = pipe_pyld[2].tvalid;
        end

        default : begin
           joined.tdata   = join_tdata (.shift(pyld_shift_pipe[1]), .tdata_lsb( pipe_hdr[2].tdata), .tdata_msb(pipe_pyld[1].tdata));
           joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[1]), .tkeep_lsb( pipe_hdr[2].tkeep), .tkeep_msb(pipe_pyld[1].tkeep));
           joined.tvalid  = pipe_hdr[2].tvalid;
        end
      endcase
   end

   assign joined.aclk    = pipe_pyld[2].aclk;
   assign joined.aresetn = pipe_pyld[2].aresetn;
   assign joined.tlast   = pipe_pyld[2].tlast && pipe_pyld[2].tvalid;
   assign joined.tid     = hdr_tid;   // TODO: validate tid and tdest output functionality
   assign joined.tdest   = hdr_tdest;
   assign joined.tuser   = '0;


   // latch tid and tdest signals.
   always @(posedge clk)
      if (pipe_hdr[1].tready && pipe_hdr[1].tvalid && pipe_hdr[1].sop) begin
         hdr_tid   <= pipe_hdr[1].tid;
         hdr_tdest <= pipe_hdr[1].tdest;
      end

   // output interface pipe stage.
   axi4s_intf_pipe #(.MODE(PUSH)) join_pipe (
      .axi4s_if_from_tx (joined),
      .axi4s_if_to_rx   (axi4s_out)
   );



   

   // tkeep_to_shift function 
   function automatic logic[COUNT_WID:0] tkeep_to_shift (input [DATA_BYTE_WID-1:0] tkeep);
      automatic logic[COUNT_WID:0] shift = 0;
      automatic logic[DATA_BYTE_WID-1:0] __tkeep;

      __tkeep = BIGENDIAN ? {<<{tkeep}} : tkeep;  // convert to little endian prior to for loop.

      for (int i=0; i<DATA_BYTE_WID; i++) if (__tkeep[DATA_BYTE_WID-1-i]==1'b1) begin
         shift = DATA_BYTE_WID-i;
         return shift;
      end
      return shift;
   endfunction



/*
   // join_tdata function
   function automatic logic [DATA_BYTE_WID-1:0][7:0] join_tdata 
      (input [DATA_BYTE_WID-1:0] tkeep, input [DATA_BYTE_WID-1:0][7:0] tdata_lsb, tdata_msb);

      automatic logic [DATA_BYTE_WID-1:0][7:0] tdata_out;
      automatic logic select_tdata_lsb = 0;
      for (int i=0; i<DATA_BYTE_WID; i++) 
         if (tkeep[DATA_BYTE_WID-1-i]==1'b1) select_tdata_lsb = 1'b1;
         tdata_out[i] = select_tdata_lsb ? tdata_lsb[i] : tdata_msb[i];
      return tdata_out;
   endfunction
*/



   // join_tdata function
   function automatic logic[DATA_BYTE_WID-1:0][7:0] join_tdata 
      (input [COUNT_WID:0] shift, input [DATA_BYTE_WID-1:0][7:0] tdata_lsb, tdata_msb);

      automatic logic[DATA_BYTE_WID-1:0][7:0] tdata_out;
      automatic logic[DATA_BYTE_WID-1:0][7:0] __tdata_lsb, __tdata_msb, __tdata_out;

      // convert to little endian prior to for loop.
      __tdata_lsb = BIGENDIAN ? {<<byte{tdata_lsb}} : tdata_lsb; 
      __tdata_msb = BIGENDIAN ? {<<byte{tdata_msb}} : tdata_msb;

      for (int i=0; i<DATA_BYTE_WID; i++) __tdata_out[i] = (i < shift) ? __tdata_lsb[i] : __tdata_msb[i];

      // convert back to big endian if required.
      tdata_out = BIGENDIAN ? {<<byte{__tdata_out}} : __tdata_out; 

      return tdata_out;
   endfunction



   // join_tkeep function
   function automatic logic[DATA_BYTE_WID-1:0] join_tkeep
      (input [COUNT_WID:0] shift, input [DATA_BYTE_WID-1:0] tkeep_lsb, tkeep_msb);

      automatic logic[DATA_BYTE_WID-1:0] tkeep_out;
      automatic logic[DATA_BYTE_WID-1:0] __tkeep_lsb, __tkeep_msb, __tkeep_out;

      // convert to little endian prior to for loop.
      __tkeep_lsb = BIGENDIAN ? {<<{tkeep_lsb}} : tkeep_lsb;
      __tkeep_msb = BIGENDIAN ? {<<{tkeep_msb}} : tkeep_msb;

      for (int i=0; i<DATA_BYTE_WID; i++) 
         __tkeep_out[i] = (i < shift) ? __tkeep_lsb[i] : __tkeep_msb[i];

      // convert back to big endian if required.
      tkeep_out = BIGENDIAN ? {<<{__tkeep_out}} : __tkeep_out;

      return tkeep_out;
   endfunction


endmodule // axi4s_join
