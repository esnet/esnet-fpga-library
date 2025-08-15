// Module: packet_skid_buffer
//
// Description: Packet interface pipelining skid buffer
//
//              Implements relaxed RDY signaling, where SKID cycles of data
//              can be received *after* deassertion of packet_if.rdy.
//
//              Standard VALID/RDY handshake therefore does not apply;
//              assertion of RDY means that up to SKID valid cycles can
//              be received, where a valid cycle is assumed to happen when
//              VALID is asserted (even when RDY is deasserted).
//
//              Intended to be used within a module, where the non-standard
//              handshake can be implemented as a local timing optimization, or
//              to buffer inputs or outputs. Not recommended for inter-module
//              interfaces due to protocol compatibility concerns.
//
module packet_skid_buffer
#(
    parameter int SKID = 1  // Number of cycles that can be received on
                            // from_tx interface *after* deassertion of rdy
) (
    packet_intf.rx  from_tx,
    packet_intf.tx  to_rx,
    output logic    oflow   // An overflow of the skid buffer is possible
                            // if the transmitter does not respect the
                            // SKID cycle maximum; this output can be used
                            // to monitor for that scenario
);
    localparam int  DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID * 8;
    localparam int  MTY_WID  = $clog2(DATA_BYTE_WID);
    localparam int  META_WID = from_tx.META_WID;

    // Parameter checking
    packet_intf_parameter_check param_check (.*);

    // Typedefs
    typedef struct packed {
        logic[META_WID-1:0] meta;
        logic               err;
        logic[MTY_WID-1:0]  mty;
        logic               eop;
        logic[DATA_WID-1:0] data;
    } fifo_data_t;

    // Signals
    fifo_data_t from_tx_data;
    fifo_data_t to_rx_data;

    // Connect input packet interface to write interface of skid buffer
    assign from_tx_data.data = from_tx.data;
    assign from_tx_data.eop  = from_tx.eop;
    assign from_tx_data.mty  = from_tx.mty;
    assign from_tx_data.err  = from_tx.err;
    assign from_tx_data.meta = from_tx.meta;

    // Pipeline skid buffer
    // (catch SKID cycles of data already in flight after
    //  deassertion axi4s_in.tready)
    fifo_prefetch #(
        .DATA_WID       ( $bits(fifo_data_t) ),
        .PIPELINE_DEPTH ( SKID )
    ) i_fifo_prefetch (
        .clk      ( from_tx.clk ),
        .srst     ( from_tx.srst ),
        .wr       ( from_tx.vld ),
        .wr_rdy   ( from_tx.rdy ),
        .wr_data  ( from_tx_data ),
        .oflow    ( oflow ),
        .rd       ( to_rx.rdy ),
        .rd_vld   ( to_rx.vld ),
        .rd_data  ( to_rx_data )
    );

    // Drive output packet interface from read interface of skid buffer
    assign to_rx.data = to_rx_data.data;
    assign to_rx.eop  = to_rx_data.eop;
    assign to_rx.mty  = to_rx_data.mty;
    assign to_rx.err  = to_rx_data.err;
    assign to_rx.meta = to_rx_data.meta;

endmodule : packet_skid_buffer

