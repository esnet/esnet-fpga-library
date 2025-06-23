// Packet to bus interface adapter
module packet_to_bus_adapter (
    // Packet interface (from transmitter)
    packet_intf.rx  packet_if_from_tx,

    // Generic bus interface (to receiver)
    bus_intf.tx     bus_if_to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = packet_if_from_tx.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int META_WID = $bits(packet_if_from_tx.META_T);

    // Payload struct (opaque to underlying bus_intf infrastructure)
    typedef struct packed {
        logic [META_WID-1:0] meta;
        logic                err;
        logic [MTY_WID-1:0]  mty;
        logic                eop;
        logic [DATA_WID-1:0] data;
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

    // Terminate packet interface
    assign srst  = packet_if_from_tx.srst;
    assign valid = packet_if_from_tx.valid;
    assign payload.data = packet_if_from_tx.data;
    assign payload.eop  = packet_if_from_tx.eop;
    assign payload.mty  = packet_if_from_tx.mty;
    assign payload.err  = packet_if_from_tx.err;
    assign payload.meta = packet_if_from_tx.meta;
    assign packet_if_from_tx.rdy  = ready;

    // Drive bus interface
    assign bus_if_to_rx.srst  = srst;
    assign bus_if_to_rx.valid = valid;
    assign bus_if_to_rx.data  = payload;
    assign ready = bus_if_to_rx.ready;

endmodule : packet_to_bus_adapter
