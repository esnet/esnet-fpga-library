// Module: packet_crc_tx
//
// Description: Computes a CRC over a full packet stream and provides the
//              result as an out-of-band output port.  The packet data passes
//              through registered (one pipeline stage, no bubble cycles).
//
//              crc_out is registered on the input-side EOP beat and held
//              until the next packet's EOP.  Because packet_pipe(STAGES=1)
//              delays the data stream by one cycle, crc_out is valid and
//              stable exactly when the EOP beat appears on to_rx.
//
//              crc_in for crc_accum is asserted together with the EOP srst
//              so back-to-back packets with no idle gap are handled correctly.
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
    localparam int META_WID      = from_tx.META_WID;
    localparam int MTY_WID       = $clog2(DATA_BYTE_WID);

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

    // Register CRC on input-side EOP.  packet_pipe delays data by one cycle,
    // so crc_out becomes valid exactly when EOP appears on to_rx.
    always_ff @(posedge clk) begin
        if (srst)
            crc_out <= '0;
        else if (xfer && from_tx.eop)
            crc_out <= crc_comb;
    end

    // -----------------------------
    // Data path — registered pipeline stage (no bubbles)
    // -----------------------------
    packet_pipe #(
        .STAGES ( 1 )
    ) i_packet_pipe (
        .srst,
        .from_tx,
        .to_rx
    );

endmodule : packet_crc_tx
