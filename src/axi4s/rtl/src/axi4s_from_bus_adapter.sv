// AXI4-S from bus interface adapter
module axi4s_from_bus_adapter #(
    parameter int DATA_BYTE_WID = 1,
    parameter int TID_WID = 1,
    parameter int TDEST_WID = 1,
    parameter int TUSER_WID = 1
) (
    // Generic bus interface (from transmitter)
    bus_intf.rx    bus_if_from_tx,

    // AXI4-S interface (to receiver)
    axi4s_intf.tx  axi4s_if_to_rx
);
    // Parameters
    localparam int TDATA_WID = DATA_BYTE_WID*8;
    localparam int TKEEP_WID = DATA_BYTE_WID;

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

    // Drive AXI-S interface
    assign axi4s_if_to_rx.tvalid = valid;
    assign axi4s_if_to_rx.tdata = payload.tdata;
    assign axi4s_if_to_rx.tkeep = payload.tkeep;
    assign axi4s_if_to_rx.tlast = payload.tlast;
    assign axi4s_if_to_rx.tid   = payload.tid;
    assign axi4s_if_to_rx.tdest = payload.tdest;
    assign axi4s_if_to_rx.tuser = payload.tuser;
    assign ready = axi4s_if_to_rx.tready;

endmodule : axi4s_from_bus_adapter
