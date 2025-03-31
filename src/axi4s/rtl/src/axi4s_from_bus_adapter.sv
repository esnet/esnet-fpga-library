// AXI4-S from bus interface adapter
module axi4s_from_bus_adapter (
    // Generic bus interface (from transmitter)
    bus_intf.rx    bus_if_from_tx,

    // AXI4-S interface (to receiver)
    axi4s_intf.tx  axi4s_if_to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = axi4s_if_to_rx.DATA_BYTE_WID;
    localparam int TDATA_WID = DATA_BYTE_WID*8;
    localparam int TKEEP_WID = DATA_BYTE_WID;
    localparam int TID_WID   = $bits(axi4s_if_to_rx.TID_T);
    localparam int TDEST_WID = $bits(axi4s_if_to_rx.TDEST_T);
    localparam int TUSER_WID = $bits(axi4s_if_to_rx.TUSER_T);

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
        std_pkg::param_check($bits(bus_if_from_tx.DATA_T), $bits(payload_t), "bus_if_from_tx.DATA_T");
    end

    // Signals
    logic     clk;
    payload_t payload;
    logic     srst;
    logic     valid;
    logic     ready;

    // Terminate bus interface
    assign clk = bus_if_from_tx.clk;
    assign srst = bus_if_from_tx.srst;
    assign valid = bus_if_from_tx.valid;
    assign payload = bus_if_from_tx.data;
    assign bus_if_from_tx.ready = ready;

    // Drive AXI-S interface
    assign axi4s_if_to_rx.aclk = clk;
    assign axi4s_if_to_rx.aresetn = !srst;
    assign axi4s_if_to_rx.tvalid = valid;
    assign axi4s_if_to_rx.tdata = payload.tdata;
    assign axi4s_if_to_rx.tkeep = payload.tkeep;
    assign axi4s_if_to_rx.tlast = payload.tlast;
    assign axi4s_if_to_rx.tid   = payload.tid;
    assign axi4s_if_to_rx.tdest = payload.tdest;
    assign axi4s_if_to_rx.tuser = payload.tuser;
    assign ready = axi4s_if_to_rx.tready;

endmodule : axi4s_from_bus_adapter
