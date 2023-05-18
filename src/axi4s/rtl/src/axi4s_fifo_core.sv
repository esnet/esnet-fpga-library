// -----------------------------------------------------------------------------
// Word-based AXI-S FIFO core
// - base component for synchronous/asynchronous implementations of a
//   word-based (i.e. not packet-aware) FIFO with AXI-S write/read
//   interfaces
// -----------------------------------------------------------------------------

module axi4s_fifo_core
#(
    parameter int DEPTH = 32,
    parameter bit ASYNC = 0,
    parameter fifo_pkg::opt_mode_t FIFO_OPT_MODE = fifo_pkg::OPT_MODE_TIMING

) (
    axi4s_intf.rx       axi4s_in,
    axi4s_intf.tx_async axi4s_out
);

    //----------------------------------------------
    // Parameters
    //----------------------------------------------
    localparam int DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;

    localparam type TDATA_T = logic [DATA_BYTE_WID-1:0][7:0];
    localparam type TKEEP_T = logic [DATA_BYTE_WID-1:0];
    localparam type TID_T   = axi4s_in.TID_T;
    localparam type TDEST_T = axi4s_in.TDEST_T;
    localparam type TUSER_T = axi4s_in.TUSER_T;

    //----------------------------------------------
    // Typedefs
    //----------------------------------------------
    typedef struct packed {
        TDATA_T tdata;
        TKEEP_T tkeep;
        logic   tlast;
        TID_T   tid;
        TDEST_T tdest;
        TUSER_T tuser;
    } axi4s_data_t;

    //----------------------------------------------
    // Signals
    //----------------------------------------------
    axi4s_data_t axi4s_in_data;
    axi4s_data_t axi4s_out_data;

    //----------------------------------------------
    // Signals
    //----------------------------------------------
    axi4l_intf axil_if__unused ();

    //----------------------------------------------
    // Map AXI-S interface to/from FIFO data interface
    //----------------------------------------------
    assign axi4s_in_data.tdata = axi4s_in.tdata;
    assign axi4s_in_data.tkeep = axi4s_in.tkeep;
    assign axi4s_in_data.tlast = axi4s_in.tlast;
    assign axi4s_in_data.tid   = axi4s_in.tid;
    assign axi4s_in_data.tdest = axi4s_in.tdest;
    assign axi4s_in_data.tuser = axi4s_in.tuser;

    assign axi4s_out.tdata = axi4s_out_data.tdata;
    assign axi4s_out.tkeep = axi4s_out_data.tkeep;
    assign axi4s_out.tlast = axi4s_out_data.tlast;
    assign axi4s_out.tid   = axi4s_out_data.tid;
    assign axi4s_out.tdest = axi4s_out_data.tdest;
    assign axi4s_out.tuser = axi4s_out_data.tuser;

    //----------------------------------------------
    // FIFO instance
    //----------------------------------------------
    fifo_core       #(
        .DATA_T      ( axi4s_data_t ),
        .DEPTH       ( DEPTH ),
        .ASYNC       ( ASYNC ),
        .FWFT        ( 1 ),
        .WR_OPT_MODE ( FIFO_OPT_MODE ),
        .RD_OPT_MODE ( FIFO_OPT_MODE )
    ) i_fifo_core    (
        .wr_clk      ( axi4s_in.aclk ),
        .wr_srst     ( !axi4s_in.aresetn ),
        .wr_rdy      ( axi4s_in.tready ),
        .wr          ( axi4s_in.tvalid ),
        .wr_data     ( axi4s_in_data ),
        .wr_count    ( ),
        .wr_full     ( ),
        .wr_oflow    ( ),
        .rd_clk      ( axi4s_out.aclk ),
        .rd_srst     ( !axi4s_out.aresetn ),
        .rd          ( axi4s_out.tready ),
        .rd_ack      ( axi4s_out.tvalid ),
        .rd_data     ( axi4s_out_data ),
        .rd_count    ( ),
        .rd_empty    ( ),
        .rd_uflow    ( ),
        .axil_if     ( axil_if__unused )
    );

endmodule : axi4s_fifo_core
