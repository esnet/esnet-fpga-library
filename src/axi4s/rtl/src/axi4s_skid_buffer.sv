// AXI-S pipelining skid buffer
//
// NOTE: uses relaxed TREADY signaling, where SKID cycles of data
//       can be received *after* deassertion of axi4s_in.tready.
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
                            // axi4s_in *after* deassertion of tready
) (
    axi4s_intf.rx axi4s_in,
    axi4s_intf.tx axi4s_out,
    output logic  oflow     // An overflow of the skid buffer is possible
                            // if the transmitter does not respect the
                            // SKID cycle maximum; this output can be used
                            // to monitor for that scenario
);
    // Parameters
    localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
    localparam int  TDATA_WID = DATA_BYTE_WID * 8;
    localparam int  TID_WID = $bits(axi4s_in.TID_T);
    localparam int  TDEST_WID = $bits(axi4s_in.TDEST_T);
    localparam int  TUSER_WID = $bits(axi4s_in.TUSER_T);

    // Parameter checking
    initial begin
        std_pkg::param_check(axi4s_out.DATA_BYTE_WID, DATA_BYTE_WID, "axi4s_out.DATA_BYTE_WID");
        std_pkg::param_check($bits(axi4s_out.TID_T), TID_WID, "axi4s_out.TID_T");
        std_pkg::param_check($bits(axi4s_out.TDEST_T), TDEST_WID, "axi4s_out.TDEST_T");
        std_pkg::param_check($bits(axi4s_out.TUSER_T), TUSER_WID, "axi4s_out.TUSER_T");
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
    assign axi4s_in_data.tdata = axi4s_in.tdata;
    assign axi4s_in_data.tkeep = axi4s_in.tkeep;
    assign axi4s_in_data.tlast = axi4s_in.tlast;
    assign axi4s_in_data.tid   = axi4s_in.tid;
    assign axi4s_in_data.tdest = axi4s_in.tdest;
    assign axi4s_in_data.tuser = axi4s_in.tuser;

    // Pipeline skid buffer
    // (catch SKID cycles of data already in flight after
    //  deassertion axi4s_in.tready)
    fifo_prefetch #(
        .DATA_T          ( fifo_data_t ),
        .PIPELINE_DEPTH  ( SKID )
    ) i_fifo_prefetch (
        .clk      ( axi4s_in.aclk ),
        .srst     ( !axi4s_in.aresetn ),
        .wr       ( axi4s_in.tvalid ),
        .wr_rdy   ( axi4s_in.tready ),
        .wr_data  ( axi4s_in_data ),
        .oflow    ( oflow ),
        .rd       ( axi4s_out.tready ),
        .rd_vld   ( axi4s_out.tvalid ),
        .rd_data  ( axi4s_out_data )
    );

    // Drive AXI-S output interface from read interface of skid buffer
    assign axi4s_out.aclk = axi4s_in.aclk;
    assign axi4s_out.aresetn = axi4s_in.aresetn;

    assign axi4s_out.tdata = axi4s_out_data.tdata;
    assign axi4s_out.tkeep = axi4s_out_data.tkeep;
    assign axi4s_out.tlast = axi4s_out_data.tlast;
    assign axi4s_out.tid   = axi4s_out_data.tid;
    assign axi4s_out.tdest = axi4s_out_data.tdest;
    assign axi4s_out.tuser = axi4s_out_data.tuser;

endmodule : axi4s_skid_buffer
