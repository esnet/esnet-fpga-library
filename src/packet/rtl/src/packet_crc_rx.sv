// Module: packet_crc_rx
//
// Description: Verifies a CRC over a full packet stream.  crc_in carries the
//              expected CRC (must be valid and stable on the input-side EOP
//              beat).  On mismatch, packet_if.err is asserted on the output
//              EOP beat.
//
//              Timing: crc_accum's internal mty-selected state-shift MUX sits
//              directly in its state-feedback recurrence and, at wide
//              DATA_BYTE_WID, eats most of the timing margin at 350MHz on its
//              own (see git history for measurements) — independent of the
//              downstream compare.  To remove the MUX from that recurrence,
//              crc_accum here is always driven with mty=0 (every beat,
//              including EOP, is treated as fully valid), with the true
//              trailing empty bytes of an EOP beat zero-masked on the data
//              feeding crc_accum instead.  This makes crc_accum's per-beat
//              state shift a single fixed (DATA_BYTE_WID-byte) function,
//              previously one option among DATA_BYTE_WID MUX-selected ones.
//
//              The resulting crc_comb is therefore the CRC as if the packet
//              were zero-padded to a full beat on EOP — not the true packet
//              CRC.  crc_trim removes the contribution of those zero-padded
//              bytes to recover the true CRC, given the real mty.  This
//              correction is itself multiple logic levels deep, so it gets
//              its own pipeline stage: a first feed-forward register
//              captures data/eop/mty/meta/err together with the *raw*
//              crc_comb and crc_in (unevaluated) on the input-side handshake
//              — crc_comb lands directly in this register with no other
//              logic in its path.  crc_trim then operates on the registered
//              crc_comb_r, and its result is captured in a second register
//              alongside the rest of the beat and the registered crc_in_r,
//              carried forward another cycle.  The 32-bit compare against
//              crc_in is performed on these already-registered,
//              already-trimmed operands — shallow logic, no longer chained
//              after crc_accum's recurrence or crc_trim — and only the
//              resulting (already-compared) err bit is written into the
//              downstream packet_skid_buffer, alongside the rest of the
//              registered beat.
//
//              from_tx.rdy is driven directly by the skid buffer's own rdy
//              (itself a registered signal, with SKID cycles of lookahead
//              reserved), so the two register stages added here cost exactly
//              the two cycles of slack that SKID=2 accounts for — no
//              bubbles, no overflow risk.
//
module packet_crc_rx
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC
) (
    input  logic                    srst,

    packet_intf.rx                  from_tx,
    packet_intf.tx                  to_rx,

    input  logic [CONFIG.WIDTH-1:0] crc_in
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int DATA_WID      = DATA_BYTE_WID * 8;
    localparam int MTY_WID       = $clog2(DATA_BYTE_WID);
    localparam int META_WID      = from_tx.META_WID;

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

    logic crc_srst;
    assign crc_srst = srst || (xfer && from_tx.eop);

    // Zero-mask the true empty trailing bytes before crc_accum, since
    // crc_accum is always driven with mty=0 below (see module header).
    logic [0:DATA_BYTE_WID-1][7:0] data_masked;
    always_comb begin
        data_masked = from_tx.data;
        for (int j = 0; j < DATA_BYTE_WID; j++)
            if (j >= DATA_BYTE_WID - int'(from_tx.mty)) data_masked[j] = 8'h00;
    end

    logic [CONFIG.WIDTH-1:0] crc_comb;
    logic                    crc_check_unused;

    // -----------------------------
    // CRC accumulator — taps input-side data, always treating the beat as
    // fully valid (mty=0 tied off; see module header).
    // -----------------------------
    crc_accum #(
        .CONFIG     ( CONFIG ),
        .DATA_BYTES ( DATA_BYTE_WID )
    ) i_crc_accum (
        .clk,
        .srst  ( crc_srst ),
        .en    ( xfer ),
        .mty   ( '0 ),
        .data  ( data_masked ),
        .crc   ( crc_comb ),
        .check ( crc_check_unused )
    );

    // -----------------------------
    // Feed-forward register — captures the beat together with the *raw*
    // (zero-padded) crc_comb and crc_in.  crc_comb lands directly in this
    // register with no other logic in its path.
    // -----------------------------
    logic                     vld_r;
    logic [DATA_WID-1:0]      data_r;
    logic                     eop_r;
    logic [MTY_WID-1:0]       mty_r;
    logic                     err_r;
    logic [META_WID-1:0]      meta_r;
    logic [CONFIG.WIDTH-1:0]  crc_comb_r;
    logic [CONFIG.WIDTH-1:0]  crc_in_r;

    always_ff @(posedge clk) begin
        if (srst) vld_r <= 1'b0;
        else      vld_r <= xfer;

        if (xfer) begin
            data_r     <= from_tx.data;
            eop_r      <= from_tx.eop;
            mty_r      <= from_tx.mty;
            err_r      <= from_tx.err;
            meta_r     <= from_tx.meta;
            crc_comb_r <= crc_comb;
            crc_in_r   <= crc_in;
        end
    end

    // -----------------------------
    // crc_trim — removes the zero-padded tail's contribution from
    // crc_comb_r, recovering the true packet CRC.  Multiple logic levels
    // deep, so its result gets a register stage of its own below rather
    // than being combined with the compare in the same cycle.
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
    logic [CONFIG.WIDTH-1:0]  crc_trimmed_r;
    logic [CONFIG.WIDTH-1:0]  crc_in_r2;

    always_ff @(posedge clk) begin
        if (srst) vld_r2 <= 1'b0;
        else      vld_r2 <= vld_r;

        data_r2       <= data_r;
        eop_r2        <= eop_r;
        mty_r2        <= mty_r;
        err_r2        <= err_r;
        meta_r2       <= meta_r;
        crc_trimmed_r <= crc_trimmed;
        crc_in_r2     <= crc_in_r;
    end

    // Shallow compare of two already-registered values — no longer chained
    // directly after crc_accum's state-feedback recurrence or crc_trim.
    logic crc_err;
    assign crc_err = (crc_trimmed_r != crc_in_r2);

    // -----------------------------
    // Registered beat with the already-compared err bit, ready to write
    // into the skid buffer.  No meta widening needed: err is a native
    // packet_intf field.
    // -----------------------------
    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( META_WID )
    ) ext_if (.clk);

    assign ext_if.vld  = vld_r2;
    assign ext_if.data = data_r2;
    assign ext_if.eop  = eop_r2;
    assign ext_if.mty  = mty_r2;
    assign ext_if.err  = err_r2 || (crc_err && eop_r2);
    assign ext_if.meta = meta_r2;

    // from_tx.rdy is driven directly from the skid buffer's own (registered)
    // rdy — SKID=2 reserves exactly the slots needed for the two feed-forward
    // register stages' latency, so this costs no bubble cycles.
    assign from_tx.rdy = ext_if.rdy;

    packet_skid_buffer #(
        .SKID ( 2 )
    ) i_packet_skid_buffer (
        .srst,
        .from_tx ( ext_if ),
        .to_rx,
        .oflow   (  )
    );

endmodule : packet_crc_rx
