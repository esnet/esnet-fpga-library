// Module: axi4s_packet_capture
//
// Description: Provides register interface for capturing a packet from the
//              data plane via an AXI-S interface and inspecting it in the control plane.
//
//              The packet data carried on a packet interface is written at the
//              dataplane word rate (i.e. quickly) into a memory and then read out
//              register-by-register (i.e. slowly)
module axi4s_packet_capture #(
    parameter bit  IGNORE_TREADY = 0,
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
    axi4s_intf.rx               axis_if
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
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_if (.clk, .srst);

    // Signals
    logic  err;
    meta_t meta;

    // Logic
    assign err = 1'b0;
    assign meta.tid = axis_if.tid;
    assign meta.tdest = axis_if.tdest;
    assign meta.tuser = axis_if.tuser;

    axi4s_to_packet_adapter #(
        .META_WID (META_WID)
    ) i_axi4s_to_packet_adapter (.*);

    packet_capture     #(
        .IGNORE_RDY      ( IGNORE_TREADY ),
        .PACKET_MEM_SIZE ( PACKET_MEM_SIZE )
    ) i_packet_capture  (.*);

endmodule : axi4s_packet_capture
