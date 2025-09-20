// Packet interface from bus interface adapter
module packet_from_bus_adapter (
    // Generic bus interface (from transmitter)
    bus_intf.rx     bus_if_from_tx,

    // Packet interface (to receiver)
    packet_intf.tx  packet_if_to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = packet_if_to_rx.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int META_WID = packet_if_to_rx.META_WID;

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
        std_pkg::param_check(bus_if_from_tx.DATA_WID, $bits(payload_t), "bus_if_from_tx.DATA_WID");
    end

    // Signals
    payload_t payload;
    logic     valid;
    logic     ready;

    // Terminate bus interface
    assign valid = bus_if_from_tx.valid;
    assign payload = bus_if_from_tx.data;
    assign bus_if_from_tx.ready = ready;

    // Drive packet interface
    assign packet_if_to_rx.vld  = valid;
    assign packet_if_to_rx.data = payload.data;
    assign packet_if_to_rx.eop  = payload.eop;
    assign packet_if_to_rx.mty  = payload.mty;
    assign packet_if_to_rx.err  = payload.err;
    assign packet_if_to_rx.meta = payload.meta;
    assign ready = packet_if_to_rx.rdy;

endmodule : packet_from_bus_adapter
