// Bus pipeline Rx
//
// Implements receive end of bus interface pipeline
//
// Includes a receive FIFO to absorb transactions in flight in order
// to accommodate a specified number of cycles of slack in the
// valid <-> ready handshaking protocol.
module bus_pipe_rx #(
    parameter bit IGNORE_READY = 1'b0,
    parameter int TOTAL_SLACK = 16 // Number of cycles of slack supported in the valid/ready pipeline
                                   // Count contributions around entire loop, e.g. buffers inserted
                                   // in forward (valid) path as well as those inserted in reverse
                                   // (ready) path
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);

    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    assign bus_if_to_rx.srst = bus_if_from_tx.srst;

    generate
        if (IGNORE_READY) begin : g__ignore_ready
            // No need for Rx FIFO
            assign bus_if_to_rx.valid = bus_if_from_tx.valid;
            assign bus_if_to_rx.data  = bus_if_from_tx.data;
            assign bus_if_from_tx.ready = 1'b1;
        end : g__ignore_ready
        else begin : g__obey_ready
            // Implement Rx FIFO to accommodate specified slack
            // in valid <-> ready handshake protocol
            fifo_small_prefetch #(
                .DATA_T         ( DATA_T ),
                .PIPELINE_DEPTH ( TOTAL_SLACK )
            ) i_fifo_small_prefetch (
                .clk     ( bus_if_from_tx.clk ),
                .srst    ( bus_if_from_tx.srst ),
                .wr      ( bus_if_from_tx.valid ),
                .wr_rdy  ( bus_if_from_tx.ready ),
                .wr_data ( bus_if_from_tx.data ),
                .oflow   ( ),
                .rd      ( bus_if_to_rx.ready ),
                .rd_rdy  ( bus_if_to_rx.valid ),
                .rd_data ( bus_if_to_rx.data )
            );
        end : g__obey_ready
    endgenerate

endmodule : bus_pipe_rx
