// AXI4-S pipeline
// Pipelines AXI4-S interface, in both directions (valid + ready) 
module axi4s_pipe #(
    parameter int  STAGES = 1, // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
    parameter bit  IGNORE_TREADY = 1'b0
) (
    axi4s_intf.rx  from_tx,
    axi4s_intf.tx  to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TDATA_WID = DATA_BYTE_WID*8;
    localparam int TKEEP_WID = DATA_BYTE_WID;
    localparam int TID_WID   = $bits(from_tx.TID_T);
    localparam int TDEST_WID = $bits(from_tx.TDEST_T);
    localparam int TUSER_WID = $bits(from_tx.TUSER_T);

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
        std_pkg::param_check(to_rx.DATA_BYTE_WID,  DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check($bits(to_rx.TID_T),   TID_WID,   "to_rx.TID_T");
        std_pkg::param_check($bits(to_rx.TDEST_T), TDEST_WID, "to_rx.TDEST_T");
        std_pkg::param_check($bits(to_rx.TUSER_T), TUSER_WID, "to_rx.TUSER_T");
    end

    // Signals
    logic clk;

    assign clk = from_tx.aclk;

    bus_intf #(.DATA_T(payload_t)) bus_if__from_tx (.clk);
    bus_intf #(.DATA_T(payload_t)) bus_if__to_rx   (.clk);

    axi4s_to_bus_adapter i_axi4s_to_bus_adapter (
        .axi4s_if_from_tx ( from_tx ),
        .bus_if_to_rx     ( bus_if__from_tx )
    );

    generate
        begin : g__fwd
            bus_pipe #(.DATA_T(payload_t), .STAGES(STAGES), .IGNORE_READY(IGNORE_TREADY)) i_bus_pipe ( .from_tx ( bus_if__from_tx ), .to_rx ( bus_if__to_rx ));
        end : g__fwd
    endgenerate

    axi4s_from_bus_adapter i_axi4s_from_bus_adapter (
        .bus_if_from_tx ( bus_if__to_rx ),
        .axi4s_if_to_rx ( to_rx )
    );

endmodule : axi4s_pipe
