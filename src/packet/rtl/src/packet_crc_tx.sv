// Module: packet_crc_tx
//
// Description: Computes a CRC over a full packet stream and provides the
//              result as an out-of-band output port.  crc_out is valid only
//              on a beat where to_rx.vld && to_rx.eop; it is undefined on all
//              other beats (not held between packets, and not guaranteed to
//              read as any particular value when idle).
//
//              Timing: crc_accum's internal mty-selected state-shift MUX sits
//              directly in its state-feedback recurrence and, at wide
//              DATA_BYTE_WID, can dominate the achievable clock rate on its
//              own — independent of anything downstream.  To remove the MUX
//              from that recurrence, crc_accum here is always driven with
//              mty=0 (every beat, including EOP, is treated as fully valid),
//              with the true trailing empty bytes of an EOP beat zero-masked
//              on the data feeding crc_accum instead.  This makes crc_accum's
//              per-beat state shift a single fixed (DATA_BYTE_WID-byte)
//              function, previously one option among DATA_BYTE_WID
//              MUX-selected ones.
//
//              The resulting crc_comb is therefore the CRC as if the packet
//              were zero-padded to a full beat on EOP — not the true
//              packet CRC.  crc_trim removes the contribution of those
//              zero-padded bytes to recover the true CRC, given the real
//              mty.  This correction is itself multiple logic levels deep,
//              so it gets its own pipeline stage: a first feed-forward
//              register captures data/eop/mty/err/meta together with the raw
//              crc_comb on the input-side handshake (crc_comb lands directly
//              in this register with no other logic in its path); a second
//              register then captures crc_trim's output alongside the rest
//              of the beat carried forward another cycle.  Neither crc_comb
//              nor crc_trim's output is ever combined with other logic
//              before landing in a register of its own.
//
//              Correctness under backpressure: the data path is elastic
//              (packet_skid_buffer, backed by fifo_prefetch), so more than
//              one packet can be in flight.  A single crc_out register fed
//              directly from the trimmed CRC would be overwritten by a later
//              packet's CRC before an earlier packet's EOP has drained, if
//              backpressure allows multiple packets to queue.  To avoid
//              losing CRC values this way, the captured CRC (already
//              registered, zeroed on non-EOP beats) is carried through the
//              skid buffer's meta field, appended to the caller's own meta,
//              so it queues and drains atomically with its packet regardless
//              of queue depth; crc_out simply reflects the meta field of
//              whichever word is currently draining.
//
//              Ingress register: from_tx is captured into a local register
//              before anything else reads it, so crc_accum's first state
//              update is always driven from a register local to this module
//              rather than directly from whatever drives from_tx. This keeps
//              the CRC computation's timing self-contained, independent of
//              the driver's own logic.
//
//              from_tx.rdy is driven directly by the skid buffer's own rdy
//              (itself a registered signal, with SKID cycles of lookahead
//              reserved), so the three register stages added here (ingress,
//              plus the two feed-forward stages below) cost exactly the three
//              cycles of slack that SKID=3 accounts for — no bubbles, no
//              overflow risk.
//
module packet_crc_tx
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC
) (
    input  logic                    srst,

    packet_intf.rx                  from_tx,
    packet_intf.tx                  to_rx,

    output logic [CONFIG.WIDTH-1:0] crc_out
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int DATA_WID      = DATA_BYTE_WID * 8;
    localparam int MTY_WID       = $clog2(DATA_BYTE_WID);
    localparam int META_WID      = from_tx.META_WID;
    localparam int EXT_META_WID  = META_WID + CONFIG.WIDTH;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(to_rx.DATA_BYTE_WID, DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check(to_rx.META_WID,      META_WID,      "to_rx.META_WID");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    logic clk;
    assign clk = from_tx.clk;

    // -----------------------------
    // Ingress register — captures from_tx before any other logic touches it,
    // so crc_accum's first state update is always driven from a register
    // local to this module rather than whatever combinational logic the
    // caller's from_tx happens to be (see module header).
    // -----------------------------
    logic                xfer_in;
    assign xfer_in = from_tx.vld && from_tx.rdy;

    logic                     in_vld_r;
    logic [DATA_WID-1:0]      in_data_r;
    logic                     in_eop_r;
    logic [MTY_WID-1:0]       in_mty_r;
    logic                     in_err_r;
    logic [META_WID-1:0]      in_meta_r;

    always_ff @(posedge clk) begin
        if (srst) in_vld_r <= 1'b0;
        else      in_vld_r <= xfer_in;

        if (xfer_in) begin
            in_data_r <= from_tx.data;
            in_eop_r  <= from_tx.eop;
            in_mty_r  <= from_tx.mty;
            in_err_r  <= from_tx.err;
            in_meta_r <= from_tx.meta;
        end
    end

    // Reset crc_accum at srst or one cycle after EOP (the EOP beat itself
    // uses the accumulated state from prior beats; see note in crc_accum).
    logic crc_srst;
    assign crc_srst = srst || (in_vld_r && in_eop_r);

    // Zero-mask the true empty trailing bytes before crc_accum, since
    // crc_accum is always driven with mty=0 below (see module header).
    logic [0:DATA_BYTE_WID-1][7:0] data_masked;
    always_comb begin
        data_masked = in_data_r;
        for (int j = 0; j < DATA_BYTE_WID; j++)
            if (j >= DATA_BYTE_WID - int'(in_mty_r)) data_masked[j] = 8'h00;
    end

    logic [CONFIG.WIDTH-1:0] crc_comb;
    logic                    crc_check_unused;

    // -----------------------------
    // CRC accumulator — taps the registered ingress data, always treating
    // the beat as fully valid (mty=0 tied off; see module header).
    // -----------------------------
    crc_accum #(
        .CONFIG     ( CONFIG ),
        .DATA_BYTES ( DATA_BYTE_WID )
    ) i_crc_accum (
        .clk,
        .srst  ( crc_srst ),
        .en    ( in_vld_r ),
        .mty   ( '0 ),
        .data  ( data_masked ),
        .crc   ( crc_comb ),
        .check ( crc_check_unused )
    );

    // -----------------------------
    // Feed-forward register — captures the beat together with the *raw*
    // (zero-padded) crc_comb.  crc_comb lands directly in this register with
    // no other logic in its path (same timing shape as the original
    // crc_out register).
    // -----------------------------
    logic                     vld_r;
    logic [DATA_WID-1:0]      data_r;
    logic                     eop_r;
    logic [MTY_WID-1:0]       mty_r;
    logic                     err_r;
    logic [META_WID-1:0]      meta_r;
    logic [CONFIG.WIDTH-1:0]  crc_comb_r;

    always_ff @(posedge clk) begin
        if (srst) vld_r <= 1'b0;
        else      vld_r <= in_vld_r;

        if (in_vld_r) begin
            data_r     <= in_data_r;
            eop_r      <= in_eop_r;
            mty_r      <= in_mty_r;
            err_r      <= in_err_r;
            meta_r     <= in_meta_r;
            crc_comb_r <= crc_comb;
        end
    end

    // -----------------------------
    // crc_trim — removes the zero-padded tail's contribution from
    // crc_comb_r, recovering the true packet CRC.  Multiple logic levels
    // deep, so its result gets a register stage of its own below rather
    // than being combined with the feed-forward register above.
    // -----------------------------
    logic [CONFIG.WIDTH-1:0] crc_trimmed;
    logic                    crc_trim_check_unused;

    crc_trim #(
        .CONFIG     ( CONFIG ),
        .DATA_BYTES ( DATA_BYTE_WID )
    ) i_crc_trim (
        .crc_in ( crc_comb_r ),
        .mty    ( mty_r ),
        .crc    ( crc_trimmed ),
        .check  ( crc_trim_check_unused )
    );

    logic                     vld_r2;
    logic [DATA_WID-1:0]      data_r2;
    logic                     eop_r2;
    logic [MTY_WID-1:0]       mty_r2;
    logic                     err_r2;
    logic [META_WID-1:0]      meta_r2;
    logic [CONFIG.WIDTH-1:0]  crc_r;

    always_ff @(posedge clk) begin
        if (srst) vld_r2 <= 1'b0;
        else      vld_r2 <= vld_r;

        data_r2 <= data_r;
        eop_r2  <= eop_r;
        mty_r2  <= mty_r;
        err_r2  <= err_r;
        meta_r2 <= meta_r;
        crc_r   <= crc_trimmed;
    end

    // -----------------------------
    // Widened-meta interface carrying the registered crc_r alongside the
    // caller's registered meta.  crc_r is only meaningful on an EOP beat;
    // zeroed otherwise so the carried field reflects the crc_out contract
    // (valid on EOP only, not held between packets).  This mux sits on the
    // write-data input to the skid buffer, not on crc_trimmed's path into
    // crc_r, so it adds no logic to the timing-critical register above.
    // -----------------------------
    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( EXT_META_WID )
    ) ext_if (.clk);

    assign ext_if.vld  = vld_r2;
    assign ext_if.data = data_r2;
    assign ext_if.eop  = eop_r2;
    assign ext_if.mty  = mty_r2;
    assign ext_if.err  = err_r2;
    assign ext_if.meta = {meta_r2, (eop_r2 ? crc_r : '0)};

    // from_tx.rdy is driven directly from the skid buffer's own (registered)
    // rdy — SKID=3 reserves exactly the slots needed for the ingress register
    // plus the two feed-forward register stages' latency, so this costs no
    // bubble cycles.
    assign from_tx.rdy = ext_if.rdy;

    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( EXT_META_WID )
    ) ext_out_if (.clk);

    packet_skid_buffer #(
        .SKID ( 3 )
    ) i_packet_skid_buffer (
        .srst,
        .from_tx ( ext_if ),
        .to_rx   ( ext_out_if ),
        .oflow   (  )
    );

    assign to_rx.vld  = ext_out_if.vld;
    assign to_rx.data = ext_out_if.data;
    assign to_rx.eop  = ext_out_if.eop;
    assign to_rx.mty  = ext_out_if.mty;
    assign to_rx.err  = ext_out_if.err;
    assign to_rx.meta = ext_out_if.meta[EXT_META_WID-1:CONFIG.WIDTH];
    assign ext_out_if.rdy = to_rx.rdy;

    // crc_out is the meta field's crc bits, valid when to_rx.vld && to_rx.eop
    // and undefined otherwise (the field is zeroed on non-EOP beats at the
    // ext_if assignment above, but that's stricter than the contract
    // requires — the skid buffer's output register holds its last value
    // when idle between packets, which is fine since crc_out is undefined
    // there).  Directly wired from the skid buffer's own output; no
    // additional logic.
    assign crc_out = ext_out_if.meta[CONFIG.WIDTH-1:0];

endmodule : packet_crc_tx
