// SAR segment-from-packet interface adapter
// - converts from the sar_packet_segmentation output format (narrow-meta
//   packet_intf + sideband) to segment representation (wide-meta packet_intf)
// - meta packing convention: meta[BUF_ID_WID+OFFSET_WID : OFFSET_WID+1] = buf_id
//                            meta[OFFSET_WID : 1]                        = offset
//                            meta[0]                                      = last
// - sideband signals are latched at the first word of each packet (vld && rdy)
//   to guard against DUT pipelining that may update them before eop; the
//   packet_intf_monitor samples meta at eop, so a stable value is required
module sar_segment_from_packet #(
    parameter int BUF_ID_WID = 1,
    parameter int OFFSET_WID = 1,
    parameter int PKT_META_WID = 1
) (
    input  logic clk,
    input  logic srst,
    // Packet interface (narrow user meta) + sideband inputs from DUT
    packet_intf.rx pkt_if,
    input logic [BUF_ID_WID-1:0] packet_buf_id,
    input logic [OFFSET_WID-1:0] packet_offset,
    input logic                  packet_last,
    // Segment interface (wide meta = BUF_ID_WID + OFFSET_WID + 1)
    packet_intf.tx seg_if
);
    localparam int SEG_META_WID = BUF_ID_WID + OFFSET_WID + 1;

    // Parameter checks
    initial begin
        std_pkg::param_check(pkt_if.META_WID,   PKT_META_WID,  "pkt_if.META_WID");
        std_pkg::param_check(seg_if.META_WID,   SEG_META_WID,  "seg_if.META_WID");
        std_pkg::param_check(seg_if.DATA_BYTE_WID, pkt_if.DATA_BYTE_WID, "seg_if.DATA_BYTE_WID");
    end

    // Latch sideband signals on first word of each packet (vld && rdy after eop)
    logic [SEG_META_WID-1:0] meta_q;
    logic sop;

    always_ff @(posedge clk) begin
        if (srst) begin
            meta_q <= '0;
            sop  <= 1'b1;  // start of simulation = start of new packet
        end else begin
            if (pkt_if.vld && pkt_if.rdy && sop) begin
                // First word: latch sideband into meta
                meta_q <= {packet_buf_id, packet_offset, packet_last};
            end
            if (pkt_if.vld && pkt_if.rdy) begin
                sop <= pkt_if.eop;
            end
        end
    end

    // Drive seg_if meta from latched value (stable throughout packet)
    assign seg_if.meta = meta_q;

    // Passthrough data signals
    assign seg_if.vld  = pkt_if.vld;
    assign seg_if.data = pkt_if.data;
    assign seg_if.eop  = pkt_if.eop;
    assign seg_if.mty  = pkt_if.mty;
    assign seg_if.err  = pkt_if.err;

    // Backpressure
    assign pkt_if.rdy = seg_if.rdy;

endmodule : sar_segment_from_packet
