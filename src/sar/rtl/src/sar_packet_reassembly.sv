// Module: sar_packet_reassembly
//
// Description: Performs reassembly of a data frame from packet data.
module sar_packet_reassembly #(
    parameter int NUM_FRAME_BUFFERS = 1,
    parameter int MAX_FRAME_SIZE = 1,
    parameter int MAX_PKT_SIZE = 16384,
    parameter int TIMER_WID = 1,
    parameter int MAX_FRAGMENTS = 8192,
    parameter int BURST_SIZE = 8,
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
    input  logic [BUF_ID_WID-1:0]     packet_buf_id,
    input  logic [OFFSET_WID-1:0]     packet_offset,
    input  logic                      packet_last,
    packet_intf.rx                    packet_if,

    // AXI-L interface
    axi4l_intf.peripheral             axil_if,

    // Timer interface
    input  logic                      ms_tick,

    // Frame (output) interface
    input logic                       frame_ready,
    output logic                      frame_valid,
    output logic [BUF_ID_WID-1:0]     frame_buf_id,
    output logic [FRAME_SIZE_WID-1:0] frame_len,

    // Memory read interface
    mem_wr_intf.controller            mem_wr_if,
    input logic                       mem_init_done
);
    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int ADDR_WID = $clog2(NUM_FRAME_BUFFERS*MAX_FRAME_SIZE/DATA_BYTE_WID);

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        logic [BUF_ID_WID-1:0] buf_id;
        logic [OFFSET_WID-1:0] offset;
        logic                  last;
    } packet_meta_t;
    localparam int PACKET_META_WID = $bits(packet_meta_t);

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(PACKET_META_WID)) __packet_if (.clk);

    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(1), .MAX_PKT_SIZE(MAX_PKT_SIZE)) nxt_descriptor (.clk);
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(PACKET_META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) wr_descriptor (.clk);

    packet_event_intf event_if (.clk);

    axi4l_intf axil_if__reassembly ();
    axi4l_intf axil_if__packets ();

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic init_done__sar_reassembly;

    packet_meta_t packet_if_meta;
    packet_meta_t wr_descriptor_meta;

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Block-level decoder
    sar_packet_reassembly_decoder i_sar_packet_reassembly_decoder (
        .axil_if            ( axil_if ),
        .packets_axil_if    ( axil_if__packets ),
        .reassembly_axil_if ( axil_if__reassembly )
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
    assign init_done = mem_init_done && init_done__sar_reassembly;

    assign packet_if_meta.buf_id = packet_buf_id;
    assign packet_if_meta.offset = packet_offset;
    assign packet_if_meta.last = packet_last;

    packet_intf_set_meta #(
        .META_WID ( PACKET_META_WID )
    ) i_packet_intf_set_meta (
        .from_tx ( packet_if ),
        .to_rx   ( __packet_if ),
        .meta    ( packet_if_meta )
    );

    packet_write     #(
        .IGNORE_RDY   ( 0 ),
        .DROP_ERRORED ( 0 ),
        .MIN_PKT_SIZE ( 0 ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE )
    ) i_packet_write  (
        .clk,
        .srst,
        .packet_if         ( __packet_if ),
        .nxt_descriptor_if ( nxt_descriptor ),
        .descriptor_if     ( wr_descriptor ),
        .event_if,
        .mem_wr_if,
        .mem_init_done
    );

    assign nxt_descriptor.vld  = 1'b1;
    assign nxt_descriptor.addr = packet_buf_id + packet_offset;
    assign nxt_descriptor.size = MAX_PKT_SIZE;
    assign nxt_descriptor.err  = 1'b0;
    assign nxt_descriptor.meta = '0;

    assign wr_descriptor_meta = wr_descriptor.meta;

    // Reassembly cache
    sar_reassembly        #(
        .NUM_FRAME_BUFFERS ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE    ( MAX_FRAME_SIZE ),
        .MAX_SEGMENT_SIZE  ( MAX_PKT_SIZE ),
        .TIMER_WID         ( TIMER_WID ),
        .MAX_FRAGMENTS     ( MAX_FRAGMENTS ),
        .BURST_SIZE        ( BURST_SIZE )
    ) i_sar_reassembly     (
        .clk,
        .srst,
        .en ( 1'b1 ),
        .init_done  ( init_done__sar_reassembly ),
        .seg_ready  ( wr_descriptor.rdy ),
        .seg_valid  ( wr_descriptor.vld ),
        .seg_buf_id ( wr_descriptor_meta.buf_id ),
        .seg_offset ( wr_descriptor_meta.offset ),
        .seg_len    ( wr_descriptor.size ),
        .seg_last   ( wr_descriptor_meta.last ),
        .ms_tick,
        .frame_ready,
        .frame_valid,
        .frame_buf_id,
        .frame_len,
        .axil_if ( axil_if__reassembly )
    );

endmodule : sar_packet_reassembly

