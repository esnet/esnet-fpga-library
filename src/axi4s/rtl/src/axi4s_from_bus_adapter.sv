// AXI4-S from bus interface adapter
module axi4s_from_bus_adapter #(
) (
    // Generic bus interface (from transmitter)
    bus_intf.rx    bus_if_from_tx,

    // AXI4-S interface (to receiver)
    axi4s_intf.tx  axi4s_if_to_rx
);

    // Imports
    import axi4s_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = axi4s_if_to_rx.DATA_BYTE_WID;
    localparam type TKEEP_T = logic[DATA_BYTE_WID-1:0];
    localparam type TDATA_T = logic[DATA_BYTE_WID-1:0][7:0];

    localparam int  TID_WID = $bits(axi4s_if_to_rx.TID_T);
    localparam type TID_T = logic[TID_WID-1:0];

    localparam int  TDEST_WID = $bits(axi4s_if_to_rx.TDEST_T);
    localparam type TDEST_T = logic[TDEST_WID-1:0];

    localparam int  TUSER_WID = $bits(axi4s_if_to_rx.TUSER_T);
    localparam type TUSER_T = logic[TUSER_WID-1:0];

    // Payload struct
    typedef struct packed {
        TUSER_T     tuser;
        TDEST_T     tdest;
        TID_T       tid;
        logic       tlast;
        TKEEP_T     tkeep;
        TDATA_T     tdata;
    } payload_t;

    payload_t axi4s_if__payload;

    // Adapt between bus and AXI4-S interfaces
    assign axi4s_if_to_rx.aclk = bus_if_from_tx.clk;
    assign axi4s_if_to_rx.aresetn = !bus_if_from_tx.srst;
    assign axi4s_if_to_rx.tvalid = bus_if_from_tx.valid;
    assign axi4s_if__payload = bus_if_from_tx.data;
    assign axi4s_if_to_rx.tdata = axi4s_if__payload.tdata;
    assign axi4s_if_to_rx.tkeep = axi4s_if__payload.tkeep;
    assign axi4s_if_to_rx.tlast = axi4s_if__payload.tlast;
    assign axi4s_if_to_rx.tid   = axi4s_if__payload.tid;
    assign axi4s_if_to_rx.tdest = axi4s_if__payload.tdest;
    assign axi4s_if_to_rx.tuser = axi4s_if__payload.tuser;
    assign bus_if_from_tx.ready = axi4s_if_to_rx.tready;

endmodule : axi4s_from_bus_adapter
