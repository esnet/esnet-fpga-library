// AXI4-S pipeline
// Pipelines AXI4-S interface, in both directions (valid + ready) 
module axi4s_pipe #(
    parameter int STAGES = 1 // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
) (
    axi4s_intf.rx  axi4s_if_from_tx,
    axi4s_intf.tx  axi4s_if_to_rx
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

    bus_intf #(.DATA_T(payload_t)) bus_if__from_tx (.clk(axi4s_if_from_tx.aclk), .srst(!axi4s_if_from_tx.aresetn));
    bus_intf #(.DATA_T(payload_t)) bus_if__to_rx   (.clk(axi4s_if_from_tx.aclk), .srst(!axi4s_if_from_tx.aresetn));

    axi4s_to_bus_adapter i_axi4s_to_bus_adapter (
        .axi4s_if_from_tx,
        .bus_if_to_rx ( bus_if__from_tx )
    );

    generate
        begin : g__fwd
            bus_pipe #(STAGES) i_bus_pipe ( .bus_if_from_tx ( bus_if__from_tx ), .bus_if_to_rx ( bus_if__to_rx ));
        end : g__fwd
    endgenerate

    axi4s_from_bus_adapter i_axi4s_from_bus_adapter (
        .bus_if_from_tx ( bus_if__to_rx ),
        .axi4s_if_to_rx
    );

endmodule : axi4s_pipe
