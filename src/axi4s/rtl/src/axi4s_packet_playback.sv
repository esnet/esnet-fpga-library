// Module: axi4s_packet_playback
//
// Description: Provides register interface for injecting a packet from the
//              control plane into the data plane via an AXI-S interface.
//
//              The packet data written register-by-register (i.e. slowly)
//              into a memory and then read out at the dataplane word rate
//              (i.e. quickly) into a packet interface.
module axi4s_packet_playback #(
    parameter bit  IGNORE_TREADY = 0,
    parameter int  MAX_RD_LATENCY = 8,
    parameter int  PACKET_MEM_SIZE = 16384
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Outputs
    output logic                en,

    // AXI-L control interface
    axi4l_intf.peripheral       axil_if,

    // Packet data interface
    axi4s_intf.tx               axis_if
);
    // Parameters
    localparam int DATA_BYTE_WID = axis_if.DATA_BYTE_WID;
    localparam int TID_WID   = axis_if.TID_WID;
    localparam int TDEST_WID = axis_if.TDEST_WID;
    localparam int TUSER_WID = axis_if.TUSER_WID;

    typedef struct packed {
        logic [TID_WID-1:0] tid;
        logic [TDEST_WID-1:0] tdest;
        logic [TUSER_WID-1:0] tuser;
    } meta_t;
    localparam int META_WID = $bits(meta_t);

    // Interfaces
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_if (.clk);

    // Signals
    logic [TID_WID-1:0]   tid;
    logic [TDEST_WID-1:0] tdest;
    logic [TUSER_WID-1:0] tuser;
    meta_t  meta;

    // Logic
    packet_playback     #(
        .IGNORE_RDY      ( IGNORE_TREADY ),
        .MAX_RD_LATENCY  ( MAX_RD_LATENCY ),
        .PACKET_MEM_SIZE ( PACKET_MEM_SIZE )
    ) i_packet_playback  (.*);

    assign meta = packet_if.meta;
    assign tid = meta.tid;
    assign tdest = meta.tdest;
    assign tuser = meta.tuser;

    axi4s_from_packet_adapter #(
        .TID_WID   ( TID_WID),
        .TDEST_WID ( TDEST_WID ),
        .TUSER_WID ( TUSER_WID )
    ) i_axi4s_from_packet_adapter (.*);

endmodule : axi4s_packet_playback
