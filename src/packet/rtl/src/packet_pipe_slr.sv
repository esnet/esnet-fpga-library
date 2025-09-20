// Packet SLR crossing component
(* keep_hierarchy = "yes" *) module packet_pipe_slr #(
    parameter bit  IGNORE_RDY = 1'b0,
    parameter int  PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int  POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    packet_intf.rx  from_tx,
    packet_intf.tx  to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int META_WID = from_tx.META_WID;

    // Parameter checking
    packet_intf_parameter_check param_check (.*);

    // Payload struct (opaque to underlying bus_intf infrastructure)
    typedef struct packed {
        logic [META_WID-1:0] meta;
        logic                err;
        logic [MTY_WID-1:0]  mty;
        logic                eop;
        logic [DATA_WID-1:0] data;
    } payload_t;
    localparam int PAYLOAD_WID = $bits(payload_t);

    // Signals
    logic clk;
    assign clk = from_tx.clk;

    bus_intf #(.DATA_WID(PAYLOAD_WID)) bus_if__from_tx (.clk);
    bus_intf #(.DATA_WID(PAYLOAD_WID)) bus_if__to_rx   (.clk);

    packet_to_bus_adapter i_packet_to_bus_adapter (
        .packet_if_from_tx ( from_tx ),
        .bus_if_to_rx      ( bus_if__from_tx )
    );

    generate
        begin : g__fwd
            bus_pipe_slr #(
                .IGNORE_READY(IGNORE_RDY), .PRE_PIPE_STAGES(PRE_PIPE_STAGES), .POST_PIPE_STAGES(POST_PIPE_STAGES) 
            ) i_bus_pipe_slr ( .from_tx ( bus_if__from_tx ), .to_rx ( bus_if__to_rx ));
        end : g__fwd
    endgenerate

    packet_from_bus_adapter i_packet_from_bus_adapter (
        .bus_if_from_tx  ( bus_if__to_rx ),
        .packet_if_to_rx ( to_rx )
    );

endmodule : packet_pipe_slr
