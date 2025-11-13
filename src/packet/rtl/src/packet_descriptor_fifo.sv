module packet_descriptor_fifo #(
    parameter int DEPTH = 32,
    parameter bit ASYNC = 0
) (
    packet_descriptor_intf.rx from_tx,
    input logic               from_tx_srst,

    packet_descriptor_intf.tx to_rx,
    input logic               to_rx_srst
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int ADDR_WID     = from_tx.ADDR_WID;
    localparam int META_WID     = from_tx.META_WID;
    localparam int MAX_PKT_SIZE = from_tx.MAX_PKT_SIZE;
    localparam int SIZE_WID     = $clog2(MAX_PKT_SIZE+1);

    // -----------------------------
    // Parameter check
    // -----------------------------
    initial begin
        std_pkg::param_check(to_rx.ADDR_WID, from_tx.ADDR_WID, "to_rx.ADDR_WID");
        std_pkg::param_check(to_rx.META_WID, from_tx.META_WID, "to_rx.META_WID");
        std_pkg::param_check_gt(to_rx.MAX_PKT_SIZE, from_tx.MAX_PKT_SIZE, "to_rx.MAX_PKT_SIZE");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef struct packed {
        logic[ADDR_WID-1:0] addr;
        logic[SIZE_WID-1:0] size;
        logic[META_WID-1:0] meta;
        logic               err;
    } desc_t;

    // -----------------------------
    // Signals
    // -----------------------------
    desc_t desc_in;
    desc_t desc_out;

    // -----------------------------
    // Interfaces
    // -----------------------------
    fifo_mon_intf wr_mon_if__unused (.clk(from_tx.clk));
    fifo_mon_intf rd_mon_if__unused (.clk(from_tx.clk));

    // -----------------------------
    // FIFO
    // -----------------------------
    assign desc_in.addr = from_tx.addr;
    assign desc_in.size = from_tx.size;
    assign desc_in.meta = from_tx.meta;
    assign desc_in.err  = from_tx.err;

    fifo_core    #(
        .DATA_WID ( $bits(desc_t) ),
        .DEPTH    ( DEPTH ),
        .ASYNC    ( ASYNC ),
        .FWFT     ( 1 )
    ) i_fifo_core  (
        .wr_clk    ( from_tx.clk ),
        .wr_srst   ( from_tx_srst ),
        .wr_rdy    ( from_tx.rdy ),
        .wr        ( from_tx.vld ),
        .wr_data   ( desc_in ),
        .wr_count  ( ),
        .wr_full   ( ),
        .wr_oflow  ( ),
        .rd_clk    ( to_rx.clk ),
        .rd_srst   ( to_rx_srst ),
        .rd        ( to_rx.rdy ),
        .rd_ack    ( to_rx.vld ),
        .rd_data   ( desc_out ),
        .rd_count  ( ),
        .rd_empty  ( ),
        .rd_uflow  ( ),
        .wr_mon_if ( wr_mon_if__unused ),
        .rd_mon_if ( rd_mon_if__unused )
    );

    assign to_rx.addr = desc_out.addr;
    assign to_rx.size = desc_out.size;
    assign to_rx.meta = desc_out.meta;
    assign to_rx.err  = desc_out.err;

endmodule : packet_descriptor_fifo
