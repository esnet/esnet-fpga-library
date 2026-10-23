// Module: packet_crc_tx
//
// Description: Computes a CRC over a full packet stream and provides the
//              result as an out-of-band output port.  crc_out is valid only
//              on a beat where to_rx.vld && to_rx.eop; it is undefined on all
//              other beats (not held between packets, and not guaranteed to
//              read as any particular value when idle).
//
//              Timing: crc_comb is fed by crc_accum's state-feedback
//              recurrence, which is already multiple logic levels deep.  A
//              dedicated feed-forward register captures data/eop/mty/err/
//              meta together with crc_comb on the input-side handshake, so
//              crc_comb is never combined with other logic before landing in
//              a register of its own — the same shape as the original
//              single-register crc_out design, which had healthy timing
//              margin in isolation (crc_comb driving a wide multi-field
//              register, or a skid buffer fed directly from crc_comb, both
//              eat into that margin — see git history for measurements).
//
//              Correctness under backpressure: the data path is elastic
//              (packet_skid_buffer, backed by fifo_prefetch), so more than
//              one packet can be in flight.  A single crc_out register fed
//              directly from crc_comb would be overwritten by a later
//              packet's CRC before an earlier packet's EOP has drained, if
//              backpressure allows multiple packets to queue.  To avoid
//              losing CRC values this way, the captured CRC (already
//              registered, zeroed on non-EOP beats) is carried through the
//              skid buffer's meta field, appended to the caller's own meta,
//              so it queues and drains atomically with its packet regardless
//              of queue depth; crc_out simply reflects the meta field of
//              whichever word is currently draining.
//
//              from_tx.rdy is driven directly by the skid buffer's own rdy
//              (itself a registered signal, with SKID cycles of lookahead
//              reserved), so the extra register stage added here costs
//              exactly the one cycle of slack that SKID=1 accounts for —
//              no bubbles, no overflow risk.
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

    logic xfer;
    assign xfer = from_tx.vld && from_tx.rdy;

    // Reset crc_accum at srst or one cycle after EOP (the EOP beat itself
    // uses the accumulated state from prior beats; see note in crc_accum).
    logic crc_srst;
    assign crc_srst = srst || (xfer && from_tx.eop);

    logic [CONFIG.WIDTH-1:0] crc_comb;
    logic                    crc_check_unused;

    // -----------------------------
    // CRC accumulator — taps input-side data
    // -----------------------------
    crc_accum #(
        .CONFIG     ( CONFIG ),
        .DATA_BYTES ( DATA_BYTE_WID )
    ) i_crc_accum (
        .clk,
        .srst  ( crc_srst ),
        .en    ( xfer ),
        .mty   ( from_tx.mty ),
        .data  ( from_tx.data ),
        .crc   ( crc_comb ),
        .check ( crc_check_unused )
    );

    // -----------------------------
    // Feed-forward register — captures the beat together with crc_comb.
    // crc_comb lands directly in this register with no other logic in its
    // path (same timing shape as the original crc_out register).
    // -----------------------------
    logic                     vld_r;
    logic [DATA_WID-1:0]      data_r;
    logic                     eop_r;
    logic [MTY_WID-1:0]       mty_r;
    logic                     err_r;
    logic [META_WID-1:0]      meta_r;
    logic [CONFIG.WIDTH-1:0]  crc_r;

    always_ff @(posedge clk) begin
        if (srst) vld_r <= 1'b0;
        else      vld_r <= xfer;

        if (xfer) begin
            data_r <= from_tx.data;
            eop_r  <= from_tx.eop;
            mty_r  <= from_tx.mty;
            err_r  <= from_tx.err;
            meta_r <= from_tx.meta;
            crc_r  <= crc_comb;
        end
    end

    // -----------------------------
    // Widened-meta interface carrying the registered crc_r alongside the
    // caller's registered meta.  crc_r is only meaningful on an EOP beat;
    // zeroed otherwise so the carried field reflects the crc_out contract
    // (valid on EOP only, not held between packets).  This mux sits on the
    // write-data input to the skid buffer, not on crc_comb's path into
    // crc_r, so it adds no logic to the timing-critical register above.
    // -----------------------------
    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( EXT_META_WID )
    ) ext_if (.clk);

    assign ext_if.vld  = vld_r;
    assign ext_if.data = data_r;
    assign ext_if.eop  = eop_r;
    assign ext_if.mty  = mty_r;
    assign ext_if.err  = err_r;
    assign ext_if.meta = {meta_r, (eop_r ? crc_r : '0)};

    // from_tx.rdy is driven directly from the skid buffer's own (registered)
    // rdy — SKID=1 reserves exactly the slot needed for the feed-forward
    // register's one cycle of latency, so this costs no bubble cycles.
    assign from_tx.rdy = ext_if.rdy;

    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( EXT_META_WID )
    ) ext_out_if (.clk);

    packet_skid_buffer #(
        .SKID ( 1 )
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
