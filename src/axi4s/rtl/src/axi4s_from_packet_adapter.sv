// Module: axi4s_from_packet_adapter
//
// Description: Adapts a 'generic' packet interface (packet_intf) to an AXI-S interface.
module axi4s_from_packet_adapter #(
    parameter int TID_WID = 1,
    parameter int TDEST_WID = 1,
    parameter int TUSER_WID = 1
) (
    input logic srst = 1'b0,
    // Packet data interface
    packet_intf.rx packet_if,
    // AXI-S data interface
    axi4s_intf.tx  axis_if,
    // AXI-S metadata
    input logic [TID_WID-1:0]   tid = '0,
    input logic [TDEST_WID-1:0] tdest = '0,
    input logic [TUSER_WID-1:0] tuser = '0
);
    // Parameters
    localparam int DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int TKEEP_WID = DATA_BYTE_WID;

    // Parameter checking
    initial begin
        std_pkg::param_check(axis_if.DATA_BYTE_WID, DATA_BYTE_WID, "axis_if.DATA_BYTE_WID");
        std_pkg::param_check(axis_if.TID_WID, TID_WID, "axis_if.TID_WID");
        std_pkg::param_check(axis_if.TDEST_WID, TDEST_WID, "axis_if.TDEST_WID");
        std_pkg::param_check(axis_if.TUSER_WID, TUSER_WID, "axis_if.TUSER_WID");
    end

    // Functions
    function automatic logic[TKEEP_WID-1:0] mty_to_tkeep(input logic[MTY_WID-1:0] mty);
        automatic logic[TKEEP_WID-1:0] __tkeep;
        for (int i = 0; i < TKEEP_WID; i++) begin
            if (mty > TKEEP_WID-i-1) __tkeep[i] = 1'b0; 
            else                     __tkeep[i] = 1'b1;
        end
        return __tkeep;
    endfunction

    // Interfaces
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axis_if (.aclk(axis_if.aclk), .aresetn(axis_if.aresetn));

    // Logic
    assign packet_if.rdy = __axis_if.tready;

    // Pipeline input interface for MTY to TKEEP calculation
    initial __axis_if.tvalid = 1'b0;
    always @(posedge __axis_if.aclk) begin
        if (!__axis_if.aresetn) __axis_if.tvalid <= 1'b0;
        else                    __axis_if.tvalid <= packet_if.vld && packet_if.rdy;
    end

    always_ff @(posedge __axis_if.aclk) begin
        __axis_if.tdata <= {<<8{packet_if.data}};
        __axis_if.tkeep <= packet_if.eop ? mty_to_tkeep(packet_if.mty) : '1;
        __axis_if.tlast <= packet_if.eop;
        __axis_if.tid   <= tid;
        __axis_if.tdest <= tdest;
        __axis_if.tuser <= tuser;
    end

    // Skid buffer to accommodate interface pipelining
    axi4s_skid_buffer #(.SKID (1)) i_axi4s_skid_buffer (
        .srst,
        .from_tx ( __axis_if ),
        .to_rx   ( axis_if ),
        .oflow   ( )
    );

endmodule : axi4s_from_packet_adapter
