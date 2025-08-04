module packet_descriptor_fifo
    import packet_pkg::*;
#(
    parameter int DEPTH = 32,
    parameter bit ASYNC = 0
) (
    packet_descriptor_intf.rx from_tx,
    packet_descriptor_intf.tx to_rx
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int ADDR_WID = $bits(from_tx.ADDR_T);
    localparam int SIZE_WID = $bits(from_tx.SIZE_T);
    localparam int META_WID = $bits(from_tx.META_T);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check($bits(to_rx.ADDR_T), ADDR_WID, "ADDR_T");
        std_pkg::param_check($bits(to_rx.SIZE_T), SIZE_WID, "SIZE_T");
        std_pkg::param_check($bits(to_rx.META_T), META_WID, "META_T");
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

    fifo_core #(
        .DATA_T ( desc_t ),
        .DEPTH  ( DEPTH ),
        .ASYNC  ( ASYNC ),
        .FWFT   ( 1 )
    ) i_fifo_core  (
        .wr_clk    ( from_tx.clk ),
        .wr_srst   ( from_tx.srst ),
        .wr_rdy    ( from_tx.rdy ),
        .wr        ( from_tx.valid ),
        .wr_data   ( desc_in ),
        .wr_count  ( ),
        .wr_full   ( ),
        .wr_oflow  ( ),
        .rd_clk    ( to_rx.clk ),
        .rd_srst   ( to_rx.srst ),
        .rd        ( to_rx.rdy ),
        .rd_ack    ( to_rx.valid ),
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
