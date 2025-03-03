// AXI4-S to bus interface adapter
module axi4s_to_bus_adapter #(
) (
    // AXI4-S interface (from transmitter)
    axi4s_intf.rx  axi4s_if_from_tx,

    // Generic bus interface (to receiver)
    bus_intf.tx    bus_if_to_rx
);

    // Imports
    import axi4s_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = axi4s_if_from_tx.DATA_BYTE_WID;
    localparam type TKEEP_T = logic[DATA_BYTE_WID-1:0];
    localparam type TDATA_T = logic[DATA_BYTE_WID-1:0][7:0];

    localparam int  TID_WID = $bits(axi4s_if_from_tx.TID_T);
    localparam type TID_T = logic[TID_WID-1:0];

    localparam int  TDEST_WID = $bits(axi4s_if_from_tx.TDEST_T);
    localparam type TDEST_T = logic[TDEST_WID-1:0];

    localparam int  TUSER_WID = $bits(axi4s_if_from_tx.TUSER_T);
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

    // Adapt between AXI4-S and bus interfaces
    assign bus_if_to_rx.srst = !axi4s_if_from_tx.aresetn;
    assign bus_if_to_rx.valid = axi4s_if_from_tx.tvalid;
    assign axi4s_if__payload.tdata  = axi4s_if_from_tx.tdata;
    assign axi4s_if__payload.tkeep  = axi4s_if_from_tx.tkeep;
    assign axi4s_if__payload.tlast  = axi4s_if_from_tx.tlast;
    assign axi4s_if__payload.tid    = axi4s_if_from_tx.tid;
    assign axi4s_if__payload.tdest  = axi4s_if_from_tx.tdest;
    assign axi4s_if__payload.tuser  = axi4s_if_from_tx.tuser;
    assign bus_if_to_rx.data = axi4s_if__payload;
    assign axi4s_if_from_tx.tready = bus_if_to_rx.ready;

endmodule : axi4s_to_bus_adapter
