// Packet 'auto' pipeline stage
//
// Adds up to 15 stages of pipelining on the packet interface;
// includes a fixed 2-stage pipeline in each of the forward (valid)
// and reverse (rdy) directions, and up to 11 auto-inserted pipeline
// stages, which can be flexibly allocated by the tool between forward
// and reverse directions.
module packet_pipe_auto #(
    parameter bit  IGNORE_RDY = 1'b0
) (
    packet_intf.rx  from_tx,
    packet_intf.tx  to_rx
);
    // Parameters
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int META_WID = $bits(from_tx.META_T);

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
        std_pkg::param_check(DATA_BYTE_WID, to_rx.DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check($bits(to_rx.META_T), META_WID, "to_rx.META_T");
    end

    // Signals
    logic clk;
    assign clk = from_tx.clk;

    bus_intf #(.DATA_T(payload_t)) bus_if__from_tx (.clk);
    bus_intf #(.DATA_T(payload_t)) bus_if__to_rx   (.clk);

    packet_to_bus_adapter i_packet_to_bus_adapter (
        .packet_if_from_tx ( from_tx ),
        .bus_if_to_rx      ( bus_if__from_tx )
    );

    generate
        begin : g__fwd
            bus_pipe_auto #(.DATA_T(payload_t), .IGNORE_READY(IGNORE_RDY)) i_bus_pipe_auto ( .from_tx ( bus_if__from_tx ), .to_rx ( bus_if__to_rx ));
        end : g__fwd
    endgenerate

    packet_from_bus_adapter i_packet_from_bus_adapter (
        .bus_if_from_tx  ( bus_if__to_rx ),
        .packet_if_to_rx ( to_rx )
    );

endmodule : packet_pipe_auto
