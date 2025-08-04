// Module: axi4s_from_packet_adapter
//
// Description: Adapts a 'generic' packet interface (packet_intf) to an AXI-S interface.
module axi4s_from_packet_adapter #(
    parameter type TID_T = logic,
    parameter type TDEST_T = logic,
    parameter type TUSER_T = logic
) (
    // Packet data interface
    packet_intf.rx packet_if,
    // AXI-S data interface
    axi4s_intf.tx  axis_if,
    // AXI-S metadata
    input TID_T    tid,
    input TDEST_T  tdest,
    input TUSER_T  tuser
);
    // Parameters
    localparam int DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int TKEEP_WID = DATA_BYTE_WID;

    localparam type TKEEP_T = logic[TKEEP_WID-1:0];
    localparam type TDATA_T = logic[DATA_BYTE_WID-1:0][7:0]; // AXI-S is little-endian
    localparam type MTY_T   = logic[MTY_WID-1:0];

    // Parameter checking
    initial begin
        std_pkg::param_check(axis_if.DATA_BYTE_WID, DATA_BYTE_WID, "axis_if.DATA_BYTE_WID");
        std_pkg::param_check($bits(axis_if.TID_T), $bits(TID_T), "axis_if.TID_T");
        std_pkg::param_check($bits(axis_if.TDEST_T), $bits(TDEST_T), "axis_if.TDEST_T");
        std_pkg::param_check($bits(axis_if.TUSER_T), $bits(TUSER_T), "axis_if.TUSER_T");
    end

    // Functions
    function automatic TKEEP_T mty_to_tkeep(input MTY_T mty);
        automatic TKEEP_T __tkeep;
        for (int i = 0; i < TKEEP_WID; i++) begin
            if (mty > TKEEP_WID-i-1) __tkeep[i] = 1'b0; 
            else                     __tkeep[i] = 1'b1;
        end
        return __tkeep;
    endfunction

    // Interfaces
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axis_if ();

    // Logic
    assign packet_if.rdy = __axis_if.tready;

    assign __axis_if.aclk = packet_if.clk;
    assign __axis_if.aresetn = !packet_if.srst;

    // Pipeline input interface for MTY to TKEEP calculation
    initial __axis_if.tvalid = 1'b0;
    always @(posedge __axis_if.aclk) begin
        if (!__axis_if.aresetn) __axis_if.tvalid <= 1'b0;
        else                    __axis_if.tvalid <= packet_if.valid && packet_if.rdy;
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
        .axi4s_in  ( __axis_if ),
        .axi4s_out ( axis_if ),
        .oflow     ( )
    );

endmodule : axi4s_from_packet_adapter
