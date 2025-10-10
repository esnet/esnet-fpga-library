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
    axi4s_intf.rx from_tx,
    input logic   from_tx_srst,
    axi4s_intf.tx to_rx,
    input logic   to_rx_srst
);

    //----------------------------------------------
    // Parameters
    //----------------------------------------------
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TDATA_WID = DATA_BYTE_WID*8;
    localparam int TKEEP_WID = DATA_BYTE_WID;
    localparam int TID_WID   = from_tx.TID_WID;
    localparam int TDEST_WID = from_tx.TDEST_WID;
    localparam int TUSER_WID = from_tx.TUSER_WID;

    //----------------------------------------------
    // Parameter checking
    //----------------------------------------------
    initial begin
        std_pkg::param_check(from_tx.DATA_BYTE_WID, to_rx.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(from_tx.TID_WID,       to_rx.TID_WID,       "TID_WID");
        std_pkg::param_check(from_tx.TDEST_WID,     to_rx.TDEST_WID,     "TDEST_WID");
        std_pkg::param_check(from_tx.TUSER_WID,     to_rx.TUSER_WID,     "TUSER_WID");
    end

    //----------------------------------------------
    // Typedefs
    //----------------------------------------------
    typedef struct packed {
        logic [TDATA_WID-1:0] tdata;
        logic [TKEEP_WID-1:0] tkeep;
        logic                 tlast;
        logic [TID_WID-1:0]   tid;
        logic [TDEST_WID-1:0] tdest;
        logic [TUSER_WID-1:0] tuser;
    } axi4s_data_t;

    //----------------------------------------------
    // Signals
    //----------------------------------------------
    axi4s_data_t axi4s_in_data;
    axi4s_data_t axi4s_out_data;

    //----------------------------------------------
    // Interfaces
    //----------------------------------------------
    fifo_mon_intf wr_mon_if__unused (.clk(from_tx.aclk));
    fifo_mon_intf rd_mon_if__unused (.clk(to_rx.aclk));

    //----------------------------------------------
    // Map AXI-S interface to/from FIFO data interface
    //----------------------------------------------
    assign axi4s_in_data.tdata = from_tx.tdata;
    assign axi4s_in_data.tkeep = from_tx.tkeep;
    assign axi4s_in_data.tlast = from_tx.tlast;
    assign axi4s_in_data.tid   = from_tx.tid;
    assign axi4s_in_data.tdest = from_tx.tdest;
    assign axi4s_in_data.tuser = from_tx.tuser;

    assign to_rx.tdata = axi4s_out_data.tdata;
    assign to_rx.tkeep = axi4s_out_data.tkeep;
    assign to_rx.tlast = axi4s_out_data.tlast;
    assign to_rx.tid   = axi4s_out_data.tid;
    assign to_rx.tdest = axi4s_out_data.tdest;
    assign to_rx.tuser = axi4s_out_data.tuser;

    //----------------------------------------------
    // FIFO instance
    //----------------------------------------------
    fifo_core       #(
        .DATA_WID    ( $bits(axi4s_data_t) ),
        .DEPTH       ( DEPTH ),
        .ASYNC       ( ASYNC ),
        .FWFT        ( 1 ),
        .WR_OPT_MODE ( FIFO_OPT_MODE ),
        .RD_OPT_MODE ( FIFO_OPT_MODE )
    ) i_fifo_core    (
        .wr_clk      ( from_tx.aclk ),
        .wr_srst     ( from_tx_srst ),
        .wr_rdy      ( from_tx.tready ),
        .wr          ( from_tx.tvalid ),
        .wr_data     ( axi4s_in_data ),
        .wr_count    ( ),
        .wr_full     ( ),
        .wr_oflow    ( ),
        .rd_clk      ( to_rx.aclk ),
        .rd_srst     ( to_rx_srst ),
        .rd          ( to_rx.tready ),
        .rd_ack      ( to_rx.tvalid ),
        .rd_data     ( axi4s_out_data ),
        .rd_count    ( ),
        .rd_empty    ( ),
        .rd_uflow    ( ),
        .wr_mon_if   ( wr_mon_if__unused ),
        .rd_mon_if   ( rd_mon_if__unused )
    );

endmodule : axi4s_fifo_core
