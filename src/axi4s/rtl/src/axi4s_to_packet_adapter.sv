// Module: axi4s_to_packet_adapter
//
// Description: Adapts an AXI-S interface to a 'generic' packet interface (packet_intf).
module axi4s_to_packet_adapter #(
    parameter int META_WID = 1
) (
    input logic                srst = 1'b0,
    // AXI-S data interface
    axi4s_intf.rx              axis_if,
    // Packet data interface
    packet_intf.tx             packet_if,
    // Packet metadata
    input logic [META_WID-1:0] meta = '0,
    input logic                err = 1'b0
);
    // Parameters
    localparam int DATA_BYTE_WID = axis_if.DATA_BYTE_WID;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int TKEEP_WID = DATA_BYTE_WID;

    // Parameter checking
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
        std_pkg::param_check(packet_if.META_WID, META_WID, "packet_if.META_WID");
    end

    // Functions
    function automatic logic[MTY_WID-1:0] tkeep_to_mty(input logic[TKEEP_WID-1:0] tkeep);
        automatic logic[MTY_WID-1:0] __mty;
        __mty = '0;
        for (int i = 0; i < TKEEP_WID; i++) begin
            if (!tkeep[i]) __mty++;
        end
        return __mty;
    endfunction

    // Interfaces
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) __packet_if (.clk(packet_if.clk));

    // Signals
    logic  __vld;
    logic [0:DATA_BYTE_WID-1][7:0] __data;
    logic                __eop;
    logic [MTY_WID-1:0]  __mty;
    logic                __err;
    logic [META_WID-1:0] __meta;

    // Logic
    assign axis_if.tready = __packet_if.rdy;

    // Pipeline input interface for TKEEP to MTY calculation
    initial __vld = 1'b0;
    always @(posedge axis_if.aclk) __vld <= axis_if.tvalid && axis_if.tready;

    always_ff @(posedge __packet_if.clk) begin
        __data <= {<<8{axis_if.tdata}};
        __eop  <= axis_if.tlast;
        __mty  <= axis_if.tlast ? tkeep_to_mty(axis_if.tkeep) : 0;
        __err  <= err;
        __meta <= meta;
    end

    assign __packet_if.vld  = __vld;
    assign __packet_if.data = __data;
    assign __packet_if.eop  = __eop;
    assign __packet_if.mty  = __mty;
    assign __packet_if.err  = __err;
    assign __packet_if.meta = __meta;

    // Skid buffer to accommodate interface pipelining
    packet_skid_buffer #(.SKID (1)) i_packet_skid_buffer (
        .srst,
        .from_tx ( __packet_if ),
        .to_rx   ( packet_if ),
        .oflow   ( )
    );

endmodule : axi4s_to_packet_adapter
