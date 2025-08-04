// Module: axi4s_to_packet_adapter
//
// Description: Adapts an AXI-S interface to a 'generic' packet interface (packet_intf).
module axi4s_to_packet_adapter #(
    parameter type META_T = logic
) (
    // AXI-S data interface
    axi4s_intf.rx  axis_if,
    // Packet data interface
    packet_intf.tx packet_if,
    // Packet metadata
    input logic    err,
    input META_T   meta
);
    // Parameters
    localparam int DATA_BYTE_WID = axis_if.DATA_BYTE_WID;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int TKEEP_WID = DATA_BYTE_WID;

    localparam type DATA_T  = logic[0:DATA_BYTE_WID-1][7:0]; // packet_intf uses network byte order
    localparam type TKEEP_T = logic[TKEEP_WID-1:0];
    localparam type MTY_T   = logic[MTY_WID-1:0];

    // Parameter checking
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
        std_pkg::param_check($bits(packet_if.META_T), $bits(META_T), "packet_if.META_T");
    end

    // Functions
    function automatic MTY_T tkeep_to_mty(input TKEEP_T tkeep);
        automatic MTY_T __mty;
        __mty = '0;
        for (int i = 0; i < TKEEP_WID; i++) begin
            if (!tkeep[i]) __mty++;
        end
        return __mty;
    endfunction

    // Interfaces
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) __packet_if (.clk(packet_if.clk), .srst(packet_if.srst));

    // Signals
    logic  __valid;
    DATA_T __data;
    logic  __eop;
    MTY_T  __mty;
    logic  __err;
    META_T __meta;

    // Logic
    assign axis_if.tready = __packet_if.rdy;

    // Pipeline input interface for TKEEP to MTY calculation
    initial __valid = 1'b0;
    always @(posedge __packet_if.clk) begin
        if (__packet_if.srst) __valid <= 1'b0;
        else                  __valid <= axis_if.tvalid && axis_if.tready;
    end

    always_ff @(posedge __packet_if.clk) begin
        __data <= {<<8{axis_if.tdata}};
        __eop  <= axis_if.tlast;
        __mty  <= axis_if.tlast ? tkeep_to_mty(axis_if.tkeep) : 0;
        __err  <= err;
        __meta <= meta;
    end

    assign __packet_if.valid = __valid;
    assign __packet_if.data  = __data;
    assign __packet_if.eop   = __eop;
    assign __packet_if.mty   = __mty;
    assign __packet_if.err   = __err;
    assign __packet_if.meta  = __meta;

    // Skid buffer to accommodate interface pipelining
    packet_skid_buffer #(.SKID (1)) i_packet_skid_buffer (
        .from_tx ( __packet_if ),
        .to_rx   ( packet_if ),
        .oflow   ( )
    );

endmodule : axi4s_to_packet_adapter
