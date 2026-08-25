// SAR segment-to-packet interface adapter
// - converts from segment representation (wide-meta packet_intf) to the
//   sar_packet_reassembly input format (narrow-meta packet_intf + sideband)
// - meta packing convention: meta = {buf_id, offset, last, packet (opaque) metadata}
// - mirrors the packet_intf_set_meta pattern (pure combinational passthrough)
module sar_segment_to_packet #(
    parameter int BUF_ID_WID = 1,
    parameter int OFFSET_WID = 1,
    parameter int PKT_META_WID = 1
) (
    // Segment interface (wide meta = BUF_ID_WID + OFFSET_WID + 1)
    packet_intf.rx seg_if,
    // Packet interface (narrow user meta)
    packet_intf.tx pkt_if,
    // Sideband outputs to DUT
    output logic [BUF_ID_WID-1:0] packet_buf_id,
    output logic [OFFSET_WID-1:0] packet_offset,
    output logic                  packet_last
);

    // Define metadata packing
    typedef struct packed {
        logic [BUF_ID_WID-1:0]    buf_id;
        logic [OFFSET_WID-1:0]    offset;
        logic                     last;
        logic  [PKT_META_WID-1:0] opaque;
    } meta_t;
    localparam int SEG_META_WID = $bits(meta_t);

    // Parameter checks
    initial begin
        std_pkg::param_check(seg_if.META_WID,   SEG_META_WID,  "seg_if.META_WID");
        std_pkg::param_check(pkt_if.META_WID,   PKT_META_WID,  "pkt_if.META_WID");
        std_pkg::param_check(pkt_if.DATA_BYTE_WID, seg_if.DATA_BYTE_WID, "pkt_if.DATA_BYTE_WID");
    end

    // Signals
    meta_t __meta;

    // Unpack sideband fields from segment meta (MSB-first: {buf_id, offset, last})
    assign __meta = seg_if.meta;
    assign packet_buf_id = __meta.buf_id;
    assign packet_offset = __meta.offset;
    assign packet_last   = __meta.last;

    // Passthrough data signals
    assign pkt_if.vld  = seg_if.vld;
    assign pkt_if.data = seg_if.data;
    assign pkt_if.eop  = seg_if.eop;
    assign pkt_if.mty  = seg_if.mty;
    assign pkt_if.err  = seg_if.err;
    assign pkt_if.meta = __meta.opaque;

    // Backpressure
    assign seg_if.rdy = pkt_if.rdy;

endmodule : sar_segment_to_packet
