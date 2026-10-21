// Module: packet_crc_rx
//
// Description: Verifies a CRC over a full packet stream.  crc_in carries the
//              expected CRC (must be valid and stable on the input-side EOP
//              beat).  On mismatch, packet_if.err is asserted on the output
//              EOP beat.
//
//              The packet data passes through registered (one pipeline stage,
//              no bubble cycles).  err is OR'd with the mismatch signal before
//              the pipeline stage so it travels with the data and arrives on
//              the output EOP beat.
//
module packet_crc_rx
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC
) (
    input  logic                   srst,

    packet_intf.rx                 from_tx,
    packet_intf.tx                 to_rx,

    input  logic [CONFIG.WIDTH-1:0] crc_in
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
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

    // Combinatorial mismatch — only meaningful on EOP beat
    logic crc_err;
    assign crc_err = (crc_comb != crc_in);

    // -----------------------------
    // Intermediate interface with err override
    // Following the packet_intf_set_meta pattern: wire all signals through,
    // override err on EOP.  rdy flows back from packet_pipe's input port.
    // -----------------------------
    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( META_WID )
    ) modified_if (.clk);

    assign modified_if.vld  = from_tx.vld;
    assign modified_if.data = from_tx.data;
    assign modified_if.eop  = from_tx.eop;
    assign modified_if.mty  = from_tx.mty;
    assign modified_if.err  = from_tx.err || (crc_err && from_tx.eop);
    assign modified_if.meta = from_tx.meta;
    assign from_tx.rdy      = modified_if.rdy;

    // -----------------------------
    // Data path — registered pipeline stage (no bubbles)
    // -----------------------------
    packet_pipe #(
        .STAGES ( 1 )
    ) i_packet_pipe (
        .srst,
        .from_tx ( modified_if ),
        .to_rx
    );

endmodule : packet_crc_rx
