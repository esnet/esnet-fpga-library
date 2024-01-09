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
   axi4s_intf.tx   axi4s_out,

   input  logic    enable,
   output logic    sop_mismatch
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
      LAST_PAYLOAD,
      B2B_HEADER
   } state_t;

   state_t state, state_nxt; 

   TID_T    hdr_tid;
   TDEST_T  hdr_tdest;
   TUSER_T  hdr_tuser;

   logic [COUNT_WID:0] hdr_shift;
   logic [COUNT_WID:0] hdr_shift_pipe[7];
   logic [COUNT_WID:0] pyld_shift;
   logic [COUNT_WID:0] pyld_shift_pipe[7];

   logic [DATA_BYTE_WID-1:0] lookahead_tkeep;

   logic drop_pkt, stall_pipe, adv_tlast, adv_tlast_p;


   // internal axi4s interfaces.
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) sync_hdr[2] ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) sync_pyld[2] ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) drop_hdr[2] ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) drop_pyld[2] ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) pipe_hdr[7] ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) pipe_pyld[7] ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) shifted_pyld ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) b2b_hdr ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) joined ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) joined_mux ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) joined_pipe ();

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),
                .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_to_fifo ();


   logic clk, resetn;

   assign clk    = axi4s_in.aclk;
   assign resetn = axi4s_in.aresetn && enable;

   // axi4s SOP synchronizer instantiation.
   axi4s_sync #(.MODE(SOP)) axi4s_sync_0 (
      .axi4s_in0   (axi4s_hdr_in),
      .axi4s_in1   (axi4s_in),
      .axi4s_out0  (sync_hdr[0]),
      .axi4s_out1  (sync_pyld[0]),
      .sop_mismatch (sop_mismatch)
   );

   axi4s_intf_pipe #(.MODE(PUSH)) sync_hdr_pipe  (.axi4s_if_from_tx (sync_hdr[0]),  .axi4s_if_to_rx   (drop_hdr[0]));
   axi4s_intf_pipe #(.MODE(PUSH)) sync_pyld_pipe (.axi4s_if_from_tx (sync_pyld[0]), .axi4s_if_to_rx   (drop_pyld[0]));

   always @(posedge clk) drop_pkt <= sync_hdr[0].tvalid && sync_hdr[0].sop && sync_hdr[0].tlast && sync_hdr[0].tkeep == '0;

   // axi4s header drop instantiation.
   axi4l_intf axil_to_drop_hdr ();

   axi4s_drop #(.OUT_PIPE_MODE(PUSH)) axi4s_drop_hdr (
      .axi4s_in    (drop_hdr[0]),
      .axi4s_out   (drop_hdr[1]),
      .axil_if     (axil_to_drop_hdr),
      .drop_pkt    (drop_pkt)
   );

   axi4l_intf_controller_term axi4l_to_drop_hdr_term (.axi4l_if (axil_to_drop_hdr));

   // axi4s payload drop instantiation.
   axi4l_intf axil_to_drop_pyld ();

   axi4s_drop #(.OUT_PIPE_MODE(PUSH)) axi4s_drop_pyld (
      .axi4s_in    (drop_pyld[0]),
      .axi4s_out   (drop_pyld[1]),
      .axil_if     (axil_to_drop_pyld),
      .drop_pkt    (drop_pkt)
   );

   axi4l_intf_controller_term axi4l_to_drop_pyld_term (.axi4l_if (axil_to_drop_pyld));

   // axi4s HDR_TLAST synchronizer instantiation.
   axi4s_sync #(.MODE(HDR_TLAST)) axi4s_sync_1 (
      .axi4s_in0   (drop_hdr[1]),
      .axi4s_in1   (drop_pyld[1]),
      .axi4s_out0  (sync_hdr[1]),
      .axi4s_out1  (sync_pyld[1]),
      .sop_mismatch()
   );



   // --- hdr pipeline. ---
   axi4s_intf_connector pipe_hdr_connector (.axi4s_from_tx(sync_hdr[1]), .axi4s_to_rx(pipe_hdr[0]));

   generate
      for (genvar i = 0; i < 6; i += 1) begin : g__pipe_hdr
         axi4s_intf_pipe #(.MODE(PUSH)) hdr_pipe (
            .axi4s_if_from_tx (pipe_hdr[i]),
            .axi4s_if_to_rx   (pipe_hdr[i+1])
         );
      end : g__pipe_hdr
   endgenerate

   assign pipe_hdr[6].tready = pipe_pyld[5].tready;  // drive pipe_hdr and pipe_pyld with common tready.


   
   // Datapath pipeline processing stages are as follows:

   // pyld_pipe[0] - Connects pipeline input.
   // pyld_pipe[1] - Captures pipeline input.
   // pyld_pipe[2] - Computes and captures pyld_shift (used by barrel shifter).
   // pyld_pipe[3] - Computes and captures shifted pyld (barrel shifter output).
   // pyld_pipe[4] - Provides lookahead to next cycle for next state determination.
   // pyld_pipe[5] - Captures hdr and pyld data for joined output.
   // pyld_pipe[6] - Captures next hdr when B2B_HEADER is detected.

   // --- pyld pipeline. ---
   axi4s_intf_connector pipe_pyld_connector (.axi4s_from_tx(sync_pyld[1]), .axi4s_to_rx(pipe_pyld[0]));

   generate
      for (genvar i = 0; i < 5; i += 1) begin : g__pipe_pyld
         if (i==2) begin
            axi4s_intf_pipe #(.MODE(PUSH)) pyld_pipe (
               .axi4s_if_from_tx (shifted_pyld),
               .axi4s_if_to_rx   (pipe_pyld[i+1])
            );

         end else begin
            axi4s_intf_pipe #(.MODE(PUSH)) pyld_pipe (
               .axi4s_if_from_tx (pipe_pyld[i]),
               .axi4s_if_to_rx   (pipe_pyld[i+1])
            );
         end
      end : g__pipe_pyld
   endgenerate

   assign pipe_pyld[5].tready = joined.tready;

   // axi4s barrel shifter instantiation.
   axi4s_shift #(
      .BIGENDIAN (BIGENDIAN),
      .SHIFT_WID (COUNT_WID)
   ) axi4s_shift_0 (
      .axi4s_in   (pipe_pyld[2]),
      .axi4s_out  (shifted_pyld),
      .shift      (pyld_shift[COUNT_WID-1:0])
   );



   // --- shift pipeline. ---

   // shift pipeline stage numbering mirrors datapath pipeline stage numbering.
   // i.e. pyld_shift_pipe[4] is used to join data from pipe_pyld[4] and pipe_pyld[5]

   always @(posedge clk) if (pipe_hdr[1].tvalid && pipe_hdr[1].tready)
                         hdr_shift <= tkeep_to_shift (pipe_hdr[1].tkeep);

   always @(posedge clk) if (pipe_hdr[1].tvalid && pipe_hdr[1].tready && pipe_hdr[1].tlast)
                         pyld_shift <= tkeep_to_shift (pipe_hdr[1].tkeep);

   assign pyld_shift_pipe[1] = pyld_shift;
   assign hdr_shift_pipe[1]  = hdr_shift;

   generate 
      for (genvar i = 2; i < 6; i += 1) begin : g__pipe_shift
         always @(posedge clk)
            if (!resetn) begin
               pyld_shift_pipe[i] <= '0;
               hdr_shift_pipe[i]  <= '0;
            end else begin
               if (pipe_pyld[i].tvalid && pipe_pyld[i].tready)  pyld_shift_pipe[i] <= pyld_shift_pipe[i-1];
               if (pipe_hdr[i].tvalid  && pipe_hdr[i].tready)   hdr_shift_pipe[i]  <= hdr_shift_pipe[i-1];
            end
      end : g__pipe_shift
   endgenerate



   // --- state machine logic. ---
   always @(posedge clk) begin
      // latch state.
      if (!resetn)  state <= HEADER;
      else          state <= state_nxt;

      // latch tid and tdest signals.
      if ((state_nxt == B2B_HEADER) && pipe_hdr[5].tvalid && pipe_hdr[5].tready && pipe_hdr[5].sop) begin
         hdr_tid   <= pipe_hdr[5].tid;
         hdr_tdest <= pipe_hdr[5].tdest;
         hdr_tuser <= pipe_hdr[5].tuser;
      end else if ((state_nxt == HEADER) && pipe_hdr[4].tvalid && pipe_hdr[4].tready && pipe_hdr[4].sop) begin
         hdr_tid   <= pipe_hdr[4].tid;
         hdr_tdest <= pipe_hdr[4].tdest;
         hdr_tuser <= pipe_hdr[4].tuser;
      end

      // --- adv_tlast logic ---
      // if last packet word, deassert adv_tlast.
      if (pipe_pyld[4].tready && pipe_pyld[4].tvalid && pipe_pyld[4].tlast)
            adv_tlast <= 0;
      // otherwise assert adv_tlast if next transaction is tlast and tkeep all-zeros (only when combining data in PAYLOAD states).
      else  adv_tlast <= pipe_pyld[3].tvalid && pipe_pyld[3].tlast && (lookahead_tkeep == '0) && (state_nxt != HEADER);

      if (!resetn)  adv_tlast_p <= 0;
      else          adv_tlast_p <= (pipe_pyld[4].tready && pipe_pyld[4].tvalid) ? adv_tlast : adv_tlast_p;
   end

   assign lookahead_tkeep = join_tkeep (.shift(pyld_shift_pipe[2]), .tkeep_lsb(pipe_pyld[3].tkeep), .tkeep_msb('0));


   always_comb begin
      state_nxt = state;
      case (state)
        HEADER : begin
           // transition from HEADER to PAYLOAD or LAST_PAYLOAD if last hdr word, but NOT last pkt word.
           if (pipe_hdr[5].tready && pipe_hdr[5].tvalid && pipe_hdr[5].tlast && !(pipe_pyld[5].tlast && pipe_pyld[5].tvalid)) begin
              if (pipe_pyld[4].tlast && pipe_pyld[4].tvalid) state_nxt = LAST_PAYLOAD;
              else                                           state_nxt = PAYLOAD;
           end
        end
        PAYLOAD : begin
           // transition from PAYLOAD to LAST_PAYLOAD if last pkt word, or back to HEADER if adv_tlast.
           if (adv_tlast)                                                             state_nxt = HEADER;
           else if (pipe_pyld[4].tready && pipe_pyld[4].tvalid && pipe_pyld[4].tlast) state_nxt = LAST_PAYLOAD;
        end
        LAST_PAYLOAD : begin
           // transition from LAST_PAYLOAD back to HEADER at end of pkt, or B2B_HEADER if next sop is concurrent.
           if (pipe_pyld[5].tready && pipe_pyld[5].tvalid && pipe_pyld[5].tlast) begin 
              if (pipe_hdr[5].tready && pipe_hdr[5].tvalid && pipe_hdr[5].sop)  state_nxt = B2B_HEADER;
              else                                                              state_nxt = HEADER;
           end
        end
        B2B_HEADER : begin
           // Always return to HEADER.  Other header scenarios (1-word and 2-word pkts) should not land in this state
           // i.e. hdr and pyld tlasts are synchronized at pipeline input.
	   state_nxt = HEADER;
        end

        default : state_nxt = state;
      endcase
   end


   // hdr and pyld joining assignments.
   assign joined.aclk    = pipe_pyld[5].aclk;
   assign joined.aresetn = pipe_pyld[5].aresetn;
   assign joined.tlast   = adv_tlast || (!adv_tlast_p && pipe_pyld[5].tlast && pipe_pyld[5].tvalid);
   assign joined.tid     = hdr_tid;
   assign joined.tdest   = hdr_tdest;
   assign joined.tuser   = hdr_tuser;

   always_comb begin
      case (state)
        HEADER : begin
           // if last header word AND last packet word.
           if (pipe_hdr[5].tready && pipe_hdr[5].tvalid && pipe_hdr[5].tlast && pipe_pyld[5].tlast) begin
              joined.tdata   = join_tdata (.shift(hdr_shift_pipe[4]), .tdata_lsb( pipe_hdr[5].tdata), .tdata_msb('0));
              joined.tkeep   = join_tkeep (.shift(hdr_shift_pipe[4]), .tkeep_lsb( pipe_hdr[5].tkeep), .tkeep_msb('0));
              joined.tvalid  = pipe_hdr[5].tvalid;
           end else begin
              joined.tdata   = join_tdata (.shift(hdr_shift_pipe[4]), .tdata_lsb( pipe_hdr[5].tdata), .tdata_msb(pipe_pyld[4].tdata));
              joined.tkeep   = join_tkeep (.shift(hdr_shift_pipe[4]), .tkeep_lsb( pipe_hdr[5].tkeep), .tkeep_msb(pipe_pyld[4].tkeep));
              joined.tvalid  = pipe_hdr[5].tvalid;
           end
        end
        PAYLOAD : begin
              joined.tdata   = join_tdata (.shift(pyld_shift_pipe[4]), .tdata_lsb(pipe_pyld[5].tdata), .tdata_msb(pipe_pyld[4].tdata));
              joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[4]), .tkeep_lsb(pipe_pyld[5].tkeep), .tkeep_msb(pipe_pyld[4].tkeep));
              joined.tvalid  = pipe_pyld[5].tvalid && !adv_tlast_p;
        end
        LAST_PAYLOAD : begin
              joined.tdata   = join_tdata (.shift(pyld_shift_pipe[4]), .tdata_lsb(pipe_pyld[5].tdata), .tdata_msb('0));
              joined.tkeep   = join_tkeep (.shift(pyld_shift_pipe[4]), .tkeep_lsb(pipe_pyld[5].tkeep), .tkeep_msb('0));
              joined.tvalid  = pipe_pyld[5].tvalid && !adv_tlast_p;
        end
        default : begin
              joined.tdata   = 'x;
              joined.tkeep   = 'x;
              joined.tvalid  = 'x;
        end
      endcase
   end


   // capture sop transaction for back-to-back header case.
   assign b2b_hdr.aclk    = pipe_hdr[6].aclk;
   assign b2b_hdr.aresetn = pipe_hdr[6].aresetn;
   assign b2b_hdr.tvalid  = pipe_hdr[6].tvalid;
   assign b2b_hdr.tdata   = join_tdata (.shift(hdr_shift_pipe[5]), .tdata_lsb( pipe_hdr[6].tdata), .tdata_msb(pipe_pyld[5].tdata));
   assign b2b_hdr.tkeep   = join_tkeep (.shift(hdr_shift_pipe[5]), .tkeep_lsb( pipe_hdr[6].tkeep), .tkeep_msb(pipe_pyld[5].tkeep));
   assign b2b_hdr.tlast   = pipe_hdr[6].tlast;
   assign b2b_hdr.tid     = hdr_tid;
   assign b2b_hdr.tdest   = hdr_tdest;
   assign b2b_hdr.tuser   = hdr_tuser;

   // stall pipeline for one cycle (B2B_HEADER state) when next header is detected to be concurrent with last pkt byte.
   assign stall_pipe = (state == B2B_HEADER);   

   // joined_mux instantiation - selects captured back-to-back header when pipeline is stalled (in B2B_HEADER state).
   axi4s_intf_2to1_mux join_mux (.axi4s_in_if_0(joined), .axi4s_in_if_1(b2b_hdr), .axi4s_out_if(joined_mux), .mux_sel(stall_pipe));

   // joined output pipe stage.
   axi4s_full_pipe join_pipe (
      .axi4s_if_from_tx (joined_mux),
      .axi4s_if_to_rx   (joined_pipe)
   );

   // advance tlast logic instantiation.  ensures clean (non zero) tlast transactions for open-nic-shell.
   // required for some hdr-to-pyld transitions (which can have empty tlast tansactions, to avoid added complexity in state machine).
   axi4s_adv_tlast axi4s_adv_tlast_0 (.axi4s_if_from_tx(joined_pipe), .axi4s_if_to_rx(axi4s_to_fifo));


   // instantiate and terminate unused AXI-L interfaces.
   axi4l_intf axil_to_probe ();
   axi4l_intf axil_to_ovfl  ();
   axi4l_intf axil_to_fifo  ();

   axi4l_intf_controller_term axi4l_to_probe_term (.axi4l_if (axil_to_probe));
   axi4l_intf_controller_term axi4l_to_ovfl_term  (.axi4l_if (axil_to_ovfl));
   axi4l_intf_controller_term axi4l_to_fifo_term  (.axi4l_if (axil_to_fifo));

   // output fifo instantiation
   axi4s_pkt_fifo_sync #(
      .FIFO_DEPTH(256),  // if MAX_PKT_LEN = 9100B, depth >= 143 words.
      .ALMOST_FULL_THRESH(143),
      .NO_INTRA_PKT_GAP(1)
   ) output_fifo_0 (
      .srst           (1'b0),
      .axi4s_in       (axi4s_to_fifo),
      .axi4s_out      (axi4s_out),
      .axil_to_probe  (axil_to_probe),
      .axil_to_ovfl   (axil_to_ovfl),
      .axil_if        (axil_to_fifo),
      .oflow          ()
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
