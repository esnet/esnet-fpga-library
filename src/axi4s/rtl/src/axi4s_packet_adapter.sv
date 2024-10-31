// Module: axi4s_from_packet_adapter
//
// Description: Adapts a 'generic' packet interface (packet_intf) to an AXI-S interface.
module axi4s_from_packet_adapter #(
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit,
    parameter bit  NETWORK_BYTE_ORDER = 1
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
    localparam int TKEEP_WID = axis_if.DATA_BYTE_WID;
    localparam type TKEEP_T = logic[TKEEP_WID-1:0];
    localparam int MTY_WID = packet_if.MTY_WID;
    localparam type MTY_T = logic[MTY_WID-1:0];

    function automatic TKEEP_T mty_to_tkeep(input MTY_T mty);
        automatic TKEEP_T __tkeep;
        for (int i = 0; i < TKEEP_WID; i++) begin
            if (mty > TKEEP_WID-i-1) __tkeep[i] = 1'b0; 
            else                     __tkeep[i] = 1'b1;
        end
        if (NETWORK_BYTE_ORDER) return {<<{__tkeep}};
        else return __tkeep;
    endfunction

    assign axis_if.aclk = packet_if.clk;
    assign axis_if.aresetn = !packet_if.srst;

    assign axis_if.tvalid = packet_if.valid;
    assign axis_if.tdata = NETWORK_BYTE_ORDER ? packet_if.data : {>>8{packet_if.data}};
    assign axis_if.tkeep = packet_if.eop ? mty_to_tkeep(packet_if.mty) : '1;
    assign axis_if.tlast = packet_if.eop;
    assign axis_if.tid = tid;
    assign axis_if.tdest = tdest;
    assign axis_if.tuser = tuser;
  
    assign packet_if.rdy = axis_if.tready;

endmodule : axi4s_from_packet_adapter

// Module: axi4s_to_packet_adapter
//
// Description: Adapts an AXI-S interface to a 'generic' packet interface (packet_intf).
module axi4s_to_packet_adapter #(
    parameter type META_T = bit,
    parameter bit  NETWORK_BYTE_ORDER = 1
) (
    // AXI-S data interface
    axi4s_intf.rx  axis_if,
    // Packet data interface
    packet_intf.tx packet_if,
    // Packet metadata
    input logic    err,
    input META_T   meta
);
    localparam int TKEEP_WID = axis_if.DATA_BYTE_WID;
    localparam type TKEEP_T = logic[TKEEP_WID-1:0];
    localparam int MTY_WID = packet_if.MTY_WID;
    localparam type MTY_T = logic[MTY_WID-1:0];

    function automatic MTY_T tkeep_to_mty(input TKEEP_T tkeep);
        automatic MTY_T __mty;
        __mty = '0;
        for (int i = 0; i < TKEEP_WID; i++) begin
            if (!tkeep[i]) __mty++;
        end
        return __mty;
    endfunction

    assign packet_if.valid = axis_if.tvalid;
    assign packet_if.data = NETWORK_BYTE_ORDER ? axis_if.tdata : {>>8{axis_if.tdata}};
    assign packet_if.eop = axis_if.tlast;
    assign packet_if.mty = axis_if.tlast ? tkeep_to_mty(axis_if.tkeep) : 0;
    assign packet_if.err = err;
    assign packet_if.meta = meta;

    assign axis_if.tready = packet_if.rdy;

endmodule : axi4s_to_packet_adapter
