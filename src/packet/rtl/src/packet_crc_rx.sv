// Module: packet_crc_rx
//
// Description: Verifies a CRC over a full packet stream.  crc_in carries the
//              expected CRC (must be valid and stable on the input-side EOP
//              beat).  On mismatch, packet_if.err is asserted on the output
//              EOP beat.
//
//              Timing: comparing crc_comb (fed by crc_accum's state-
//              feedback recurrence) against crc_in in the same cycle that
//              the beat is written downstream is too many logic levels for
//              a single cycle at 350MHz.  Instead, a dedicated feed-forward
//              register captures data/eop/mty/meta/err together with the
//              *raw* crc_comb and crc_in (unevaluated) on the input-side
//              handshake — crc_comb lands directly in this register with no
//              other logic in its path, same timing shape as the original
//              single-register crc_out design, which had healthy margin in
//              isolation.  The 32-bit compare is then performed on these
//              already-registered operands — shallow logic, no longer
//              chained after crc_accum's recurrence — and only the
//              resulting (already-compared) err bit is written into the
//              downstream packet_skid_buffer, alongside the rest of the
//              registered beat.
//
//              from_tx.rdy is driven directly by the skid buffer's own rdy
//              (itself a registered signal, with SKID cycles of lookahead
//              reserved), so the extra register stage added here costs
//              exactly the one cycle of slack that SKID=1 accounts for —
//              no bubbles, no overflow risk.
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
    // Feed-forward register — captures the beat together with the *raw*
    // crc_comb and crc_in.  crc_comb lands directly in this register with
    // no other logic in its path.
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

    // Shallow compare of two already-registered 32-bit values — no longer
    // chained directly after crc_accum's state-feedback recurrence.
    logic crc_err;
    assign crc_err = (crc_comb_r != crc_in_r);

    // -----------------------------
    // Registered beat with the already-compared err bit, ready to write
    // into the skid buffer.  No meta widening needed: err is a native
    // packet_intf field.
    // -----------------------------
    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( META_WID )
    ) ext_if (.clk);

    assign ext_if.vld  = vld_r;
    assign ext_if.data = data_r;
    assign ext_if.eop  = eop_r;
    assign ext_if.mty  = mty_r;
    assign ext_if.err  = err_r || (crc_err && eop_r);
    assign ext_if.meta = meta_r;

    // from_tx.rdy is driven directly from the skid buffer's own (registered)
    // rdy — SKID=1 reserves exactly the slot needed for the feed-forward
    // register's one cycle of latency, so this costs no bubble cycles.
    assign from_tx.rdy = ext_if.rdy;

    packet_skid_buffer #(
        .SKID ( 1 )
    ) i_packet_skid_buffer (
        .srst,
        .from_tx ( ext_if ),
        .to_rx,
        .oflow   (  )
    );

endmodule : packet_crc_rx
