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
    parameter int  PACKET_MEM_SIZE = 16384,
    parameter bit  NETWORK_BYTE_ORDER = 1
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
    localparam type TID_T   = logic[$bits(axis_if.TID_T)-1:0];
    localparam type TDEST_T = logic[$bits(axis_if.TDEST_T)-1:0];
    localparam type TUSER_T = logic[$bits(axis_if.TUSER_T)-1:0];
    localparam type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};

    // Parameter checking
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
    end

    // Interfaces
    packet_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .META_T(struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;})
    ) packet_if (.clk(clk), .srst(srst));

    // Signals
    TID_T   tid;
    TDEST_T tdest;
    TUSER_T tuser;

    // Logic
    packet_playback     #(
        .IGNORE_RDY      ( IGNORE_TREADY ),
        .MAX_RD_LATENCY  ( MAX_RD_LATENCY ),
        .PACKET_MEM_SIZE ( PACKET_MEM_SIZE )
    ) i_packet_playback  (.*);

    assign tid = packet_if.meta.tid;
    assign tdest = packet_if.meta.tdest;
    assign tuser = packet_if.meta.tuser;

    axi4s_from_packet_adapter #(
        .TID_T   ( TID_T),
        .TDEST_T ( TDEST_T ),
        .TUSER_T ( TUSER_T ),
        .NETWORK_BYTE_ORDER ( NETWORK_BYTE_ORDER )
    ) i_axi4s_from_packet_adapter (.*);

endmodule : axi4s_packet_playback
