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
    localparam type TID_T   = logic[$bits(axis_if.TID_T)-1:0];
    localparam type TDEST_T = logic[$bits(axis_if.TDEST_T)-1:0];
    localparam type TUSER_T = logic[$bits(axis_if.TUSER_T)-1:0];
    // renamed localparam META_T to avoid vivado segmentation fault.
    localparam type _META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};

    // Parameter checking
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
    end

    // Interfaces
    packet_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
//        .META_T(struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;})
        .META_T(_META_T) // reinstantiated with localparam _META_T to avoid vivado parameterization error.
    ) packet_if (.clk(clk), .srst(srst));

    // Signals
    logic  err;
    _META_T meta;

    // Logic
    assign err = 1'b0;
    assign meta.tid = axis_if.tid;
    assign meta.tdest = axis_if.tdest;
    assign meta.tuser = axis_if.tuser;

    axi4s_to_packet_adapter #(
        .META_T ( _META_T )
    ) i_axi4s_to_packet_adapter (.*);

    packet_capture     #(
        .IGNORE_RDY      ( IGNORE_TREADY ),
        .PACKET_MEM_SIZE ( PACKET_MEM_SIZE )
    ) i_packet_capture  (.*);

endmodule : axi4s_packet_capture
