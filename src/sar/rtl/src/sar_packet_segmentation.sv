// Module: sar_packet_segmentation
//
// Description: Performs segmentation of a data frame into packet data.
module sar_packet_segmentation #(
    parameter int NUM_FRAME_BUFFERS = 1,
    parameter int MAX_FRAME_SIZE = 1,
    parameter int MAX_PKT_SIZE = 16384,
    parameter int MAX_RD_LATENCY = 8,
    // Derived parameters (don't override)
    parameter int BUF_ID_WID = NUM_FRAME_BUFFERS > 1 ? $clog2(NUM_FRAME_BUFFERS) : 1,
    parameter int OFFSET_WID = $clog2(MAX_FRAME_SIZE),
    parameter int FRAME_SIZE_WID = $clog2(MAX_FRAME_SIZE+1),
    parameter int PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1)
) (
    // Clock/Reset
    input  logic                      clk,
    input  logic                      srst,

    output logic                      init_done,

    // Packet data interface
    output  logic [BUF_ID_WID-1:0]    packet_buf_id,
    output  logic [OFFSET_WID-1:0]    packet_offset,
    output  logic [PKT_SIZE_WID-1:0]  packet_size,
    output  logic                     packet_last,
    packet_intf.tx                    packet_if,

    // AXI-L interface
    axi4l_intf.peripheral             axil_if,

    // Frame (output) interface
    input  logic                      frame_valid,
    output logic                      frame_ready,
    input  logic [BUF_ID_WID-1:0]     frame_buf_id,
    input  logic [FRAME_SIZE_WID-1:0] frame_len,

    // Memory read interface
    mem_rd_intf.controller            mem_rd_if,
    input logic                       mem_init_done
);
    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int ADDR_WID = $clog2(NUM_FRAME_BUFFERS*MAX_FRAME_SIZE);
    localparam int DATA_BYTE_WID = packet_if.DATA_BYTE_WID;

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        logic [BUF_ID_WID-1:0]   buf_id;
        logic [PKT_SIZE_WID-1:0] size;
        logic [OFFSET_WID-1:0]   offset;
        logic                    last;
    } packet_meta_t;
    localparam int PACKET_META_WID = $bits(packet_meta_t);

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(PACKET_META_WID)) __packet_if (.clk, .srst);
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(PACKET_META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) rd_descriptor (.clk);

    packet_event_intf event_if (.clk);

    axi4l_intf axil_if__segmentation ();
    axi4l_intf axil_if__packets ();

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic init_done__sar_segmentation;

    packet_meta_t __packet_if_meta;
    packet_meta_t rd_descriptor_meta;

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Block-level decoder
    sar_packet_segmentation_decoder i_sar_packet_segmentation_decoder (
        .axil_if              ( axil_if ),
        .packets_axil_if      ( axil_if__packets ),
        .segmentation_axil_if ( axil_if__segmentation )
    );

    // -------------------------------------------------
    // Input packet counters
    // -------------------------------------------------
    packet_counters #(
        .MAX_PKT_SIZE ( MAX_PKT_SIZE ),
        .COUNT_ERR    ( 0 ),
        .COUNT_OFLOW  ( 0 )
    ) i_packet_counters (
        .clk,
        .axil_if  ( axil_if__packets ),
        .event_if ( event_if )
    );

    // -------------------------------------------------
    // Store packet data to memory
    // -------------------------------------------------
    assign init_done = mem_init_done && init_done__sar_segmentation;

    packet_read        #(
        .IGNORE_RDY     ( 0 ),
        .MAX_RD_LATENCY ( MAX_RD_LATENCY )
    ) i_packet_read  (
        .clk,
        .srst,
        .packet_if     ( __packet_if ),
        .descriptor_if ( rd_descriptor ),
        .event_if,
        .mem_rd_if
    );

    packet_intf_set_meta #(
        .META_WID ( 1 )
    ) i_packet_intf_set_meta (
        .from_tx ( __packet_if ),
        .to_rx   ( packet_if ),
        .meta    ( '0 )
    );
    assign __packet_if_meta = __packet_if.meta;
    assign packet_buf_id = __packet_if_meta.buf_id;
    assign packet_offset = __packet_if_meta.offset;
    assign packet_size   = __packet_if_meta.size;
    assign packet_last   = __packet_if_meta.last;

    assign rd_descriptor.addr = rd_descriptor_meta.buf_id + rd_descriptor_meta.offset;
    assign rd_descriptor_meta.size = rd_descriptor.size;
    assign rd_descriptor.meta = rd_descriptor_meta;
    assign rd_descriptor.err = 1'b0;

    // Segmentation logic
    sar_segmentation      #(
        .NUM_FRAME_BUFFERS ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE    ( MAX_FRAME_SIZE ),
        .MAX_SEGMENT_LEN   ( MAX_PKT_SIZE )
    ) i_sar_segmentation (
        .clk,
        .srst,
        .init_done  ( init_done__sar_segmentation ),
        .frame_ready,
        .frame_valid,
        .frame_buf_id,
        .frame_len,
        .seg_ready  ( rd_descriptor.rdy ),
        .seg_valid  ( rd_descriptor.vld ),
        .seg_buf_id ( rd_descriptor_meta.buf_id ),
        .seg_offset ( rd_descriptor_meta.offset ),
        .seg_len    ( rd_descriptor.size ),
        .seg_last   ( rd_descriptor_meta.last ),
        .axil_if    ( axil_if__segmentation )
    );

endmodule : sar_packet_segmentation

