// AXI4-S pipeline
// Pipelines AXI4-S interface, in both directions (valid + ready) 
module axi4s_pipe #(
    parameter int  STAGES = 1 // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
) (
    input logic    srst = 1'b0,
    axi4s_intf.rx  from_tx,
    axi4s_intf.tx  to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TDATA_WID = DATA_BYTE_WID*8;
    localparam int TKEEP_WID = DATA_BYTE_WID;
    localparam int TID_WID   = from_tx.TID_WID;
    localparam int TDEST_WID = from_tx.TDEST_WID;
    localparam int TUSER_WID = from_tx.TUSER_WID;

    // Payload struct (opaque to underlying bus_intf infrastructure)
    typedef struct packed {
        logic [TUSER_WID-1:0] tuser;
        logic [TDEST_WID-1:0] tdest;
        logic [TID_WID-1:0]   tid;
        logic                 tlast;
        logic [TKEEP_WID-1:0] tkeep;
        logic [TDATA_WID-1:0] tdata;
    } payload_t;
    localparam int PAYLOAD_WID = $bits(payload_t);

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_BYTE_WID, to_rx.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(from_tx.TID_WID,       to_rx.TID_WID,       "TID_WID");
        std_pkg::param_check(from_tx.TDEST_WID,     to_rx.TDEST_WID,     "TDEST_WID");
        std_pkg::param_check(from_tx.TUSER_WID,     to_rx.TUSER_WID,     "TUSER_WID");
    end

    // Signals
    logic clk;

    assign clk = from_tx.aclk;

    bus_intf #(.DATA_WID(PAYLOAD_WID)) bus_if__from_tx (.clk);
    bus_intf #(.DATA_WID(PAYLOAD_WID)) bus_if__to_rx   (.clk);

    axi4s_to_bus_adapter i_axi4s_to_bus_adapter (
        .axi4s_if_from_tx ( from_tx ),
        .bus_if_to_rx     ( bus_if__from_tx )
    );

    bus_pipe #(.STAGES(STAGES)) i_bus_pipe (.srst, .from_tx (bus_if__from_tx), .to_rx (bus_if__to_rx));

    axi4s_from_bus_adapter i_axi4s_from_bus_adapter (
        .bus_if_from_tx ( bus_if__to_rx ),
        .axi4s_if_to_rx ( to_rx )
    );

endmodule : axi4s_pipe
