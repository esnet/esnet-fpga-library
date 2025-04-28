// AXI4-S to bus interface adapter
module axi4s_to_bus_adapter (
    // AXI4-S interface (from transmitter)
    axi4s_intf.rx  axi4s_if_from_tx,

    // Generic bus interface (to receiver)
    bus_intf.tx    bus_if_to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = axi4s_if_from_tx.DATA_BYTE_WID;
    localparam int TDATA_WID = DATA_BYTE_WID*8;
    localparam int TKEEP_WID = DATA_BYTE_WID;
    localparam int TID_WID   = $bits(axi4s_if_from_tx.TID_T);
    localparam int TDEST_WID = $bits(axi4s_if_from_tx.TDEST_T);
    localparam int TUSER_WID = $bits(axi4s_if_from_tx.TUSER_T);

    // Payload struct (opaque to underlying bus_intf infrastructure)
    typedef struct packed {
        logic [TUSER_WID-1:0] tuser;
        logic [TDEST_WID-1:0] tdest;
        logic [TID_WID-1:0]   tid;
        logic                 tlast;
        logic [TKEEP_WID-1:0] tkeep;
        logic [TDATA_WID-1:0] tdata;
    } payload_t;

    // Parameter checking
    initial begin
        std_pkg::param_check($bits(bus_if_to_rx.DATA_T), $bits(payload_t), "bus_if_to_rx.DATA_T");
    end

    // Signals
    payload_t payload;
    logic     srst;
    logic     valid;
    logic     ready;

    // Terminate AXI-S interface
    assign srst  = !axi4s_if_from_tx.aresetn;
    assign valid = axi4s_if_from_tx.tvalid;
    assign payload.tdata  = axi4s_if_from_tx.tdata;
    assign payload.tkeep  = axi4s_if_from_tx.tkeep;
    assign payload.tlast  = axi4s_if_from_tx.tlast;
    assign payload.tid    = axi4s_if_from_tx.tid;
    assign payload.tdest  = axi4s_if_from_tx.tdest;
    assign payload.tuser  = axi4s_if_from_tx.tuser;
    assign axi4s_if_from_tx.tready  = ready;

    // Drive bus interface
    assign bus_if_to_rx.srst  = srst;
    assign bus_if_to_rx.valid = valid;
    assign bus_if_to_rx.data  = payload;
    assign ready = bus_if_to_rx.ready;

endmodule : axi4s_to_bus_adapter
