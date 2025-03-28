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
    localparam int  MTY_WID  = from_tx.MTY_WID;
    localparam int  META_WID = $bits(from_tx.META_T);

    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];
    localparam type META_T = logic[META_WID-1:0];
    localparam type MTY_T  = logic[MTY_WID-1:0];

    // Parameter checking
    initial begin
        std_pkg::param_check(to_rx.DATA_BYTE_WID, DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check($bits(to_rx.META_T), META_WID, "to_rx.META_T");
    end

    // Typedefs
    typedef struct packed {
        META_T  meta;
        logic   err;
        MTY_T   mty;
        logic   eop;
        DATA_T  data;
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
    fifo_small_prefetch #(
        .DATA_T          ( fifo_data_t ),
        .PIPELINE_DEPTH  ( SKID )
    ) i_fifo_prefetch (
        .clk      ( from_tx.clk ),
        .srst     ( from_tx.srst ),
        .wr       ( from_tx.valid ),
        .wr_rdy   ( from_tx.rdy ),
        .wr_data  ( from_tx_data ),
        .oflow    ( oflow ),
        .rd       ( to_rx.rdy ),
        .rd_rdy   ( to_rx.valid ),
        .rd_data  ( to_rx_data )
    );

    // Drive output packet interface from read interface of skid buffer
    assign to_rx.data = to_rx_data.data;
    assign to_rx.eop  = to_rx_data.eop;
    assign to_rx.mty  = to_rx_data.mty;
    assign to_rx.err  = to_rx_data.err;
    assign to_rx.meta = to_rx_data.meta;

endmodule : packet_skid_buffer

