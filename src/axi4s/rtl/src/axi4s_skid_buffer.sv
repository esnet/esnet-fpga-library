// AXI-S pipelining skid buffer
//
// NOTE: uses relaxed TREADY signaling, where SKID cycles of data
//       can be received *after* deassertion of from_tx.tready.
//       
//       Standard TVALID/TREADY handshake therefore does not apply;
//       assertion of TREADY means that up to SKID valid cycles can
//       be received, where a valid cycle is assumed to happen when
//       TVALID is asserted (even when TREADY is deasserted).
//
//       Intended to be used within a module, where the non-standard
//       handshake can be implemented as a local timing optimization, or
//       to buffer inputs or outputs. Not recommended for inter-module
//       interfaces due to protocol compatibility concerns.
//
module axi4s_skid_buffer #(
    parameter int SKID = 1  // Number of cycles that can be received on
                            // from_tx *after* deassertion of tready
) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx,
    output logic  oflow     // An overflow of the skid buffer is possible
                            // if the transmitter does not respect the
                            // SKID cycle maximum; this output can be used
                            // to monitor for that scenario
);
    // Parameters
    localparam int  DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int  TDATA_WID = DATA_BYTE_WID * 8;
    localparam int  TID_WID = from_tx.TID_WID;
    localparam int  TDEST_WID = from_tx.TDEST_WID;
    localparam int  TUSER_WID = from_tx.TUSER_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_BYTE_WID, to_rx.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(from_tx.TID_WID,       to_rx.TID_WID,       "TID_WID");
        std_pkg::param_check(from_tx.TDEST_WID,     to_rx.TDEST_WID,     "TDEST_WID");
        std_pkg::param_check(from_tx.TUSER_WID,     to_rx.TUSER_WID,     "TUSER_WID");
    end

    // Typedefs
    typedef struct packed {
        logic[TUSER_WID-1:0]     tuser;
        logic[TDEST_WID-1:0]     tdest;
        logic[TID_WID-1:0]       tid;
        logic                    tlast;
        logic[DATA_BYTE_WID-1:0] tkeep;
        logic[TDATA_WID-1:0]     tdata;
    } fifo_data_t;

    // Signals
    fifo_data_t axi4s_in_data;
    fifo_data_t axi4s_out_data;

    // Connect AXI-S input interface to write interface of skid buffer
    assign axi4s_in_data.tdata = from_tx.tdata;
    assign axi4s_in_data.tkeep = from_tx.tkeep;
    assign axi4s_in_data.tlast = from_tx.tlast;
    assign axi4s_in_data.tid   = from_tx.tid;
    assign axi4s_in_data.tdest = from_tx.tdest;
    assign axi4s_in_data.tuser = from_tx.tuser;

    // Pipeline skid buffer
    // (catch SKID cycles of data already in flight after
    //  deassertion from_tx.tready)
    fifo_prefetch #(
        .DATA_WID        ( $bits(fifo_data_t) ),
        .PIPELINE_DEPTH  ( SKID )
    ) i_fifo_prefetch (
        .clk      ( from_tx.aclk ),
        .srst     ( !from_tx.aresetn ),
        .wr       ( from_tx.tvalid ),
        .wr_rdy   ( from_tx.tready ),
        .wr_data  ( axi4s_in_data ),
        .oflow    ( oflow ),
        .rd       ( to_rx.tready ),
        .rd_vld   ( to_rx.tvalid ),
        .rd_data  ( axi4s_out_data )
    );

    // Drive AXI-S output interface from read interface of skid buffer
    assign to_rx.tdata = axi4s_out_data.tdata;
    assign to_rx.tkeep = axi4s_out_data.tkeep;
    assign to_rx.tlast = axi4s_out_data.tlast;
    assign to_rx.tid   = axi4s_out_data.tid;
    assign to_rx.tdest = axi4s_out_data.tdest;
    assign to_rx.tuser = axi4s_out_data.tuser;

endmodule : axi4s_skid_buffer
