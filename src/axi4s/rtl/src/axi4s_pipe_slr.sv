// AXI4-S SLR crossing component
(* keep_hierarchy = "yes" *) module axi4s_pipe_slr #(
    parameter bit IGNORE_TREADY = 1'b0,
    parameter int PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
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

    bus_intf #(.DATA_T(payload_t)) bus_if__from_tx (.clk(axi4s_if_from_tx.aclk));
    bus_intf #(.DATA_T(payload_t)) bus_if__to_rx   (.clk(axi4s_if_from_tx.aclk));

    axi4s_to_bus_adapter i_axi4s_to_bus_adapter (
        .axi4s_if_from_tx,
        .bus_if_to_rx ( bus_if__from_tx )
    );

    generate
        begin : g__fwd
            bus_pipe_slr #(IGNORE_TREADY, PRE_PIPE_STAGES, POST_PIPE_STAGES) i_bus_pipe_slr ( .bus_if_from_tx ( bus_if__from_tx ), .bus_if_to_rx ( bus_if__to_rx ));
        end : g__fwd
    endgenerate

    axi4s_from_bus_adapter i_axi4s_from_bus_adapter (
        .bus_if_from_tx ( bus_if__to_rx ),
        .axi4s_if_to_rx
    );

endmodule : axi4s_pipe_slr
