// Bus pipeline Rx
//
// Implements receive end of bus interface pipeline
//
// Includes a receive FIFO to absorb transactions in flight in order
// to accommodate a specified number of cycles of slack in the
// valid <-> ready handshaking protocol.
module bus_pipe_rx #(
    parameter bit  IGNORE_READY = 1'b0,
    parameter int  TOTAL_SLACK = 16 // Number of cycles of slack supported in the valid/ready pipeline
                                    // Count contributions around entire loop, e.g. buffers inserted
                                    // in forward (valid) path as well as those inserted in reverse
                                    // (ready) path
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int DATA_WID = from_tx.DATA_WID;

    // Parameter checking
    bus_intf_parameter_check param_check (.*);

    generate
        if (IGNORE_READY) begin : g__ignore_ready
            // No need for Rx FIFO
            assign to_rx.valid = from_tx.valid;
            assign to_rx.data  = from_tx.data;
            assign from_tx.ready = 1'b1;
        end : g__ignore_ready
        else begin : g__obey_ready
            // Implement Rx FIFO to accommodate specified slack
            // in valid <-> ready handshake protocol
            fifo_prefetch #(
                .DATA_WID  ( DATA_WID ),
                .PIPELINE_DEPTH ( TOTAL_SLACK )
            ) i_fifo_prefetch (
                .clk     ( from_tx.clk ),
                .srst    ( from_tx.srst ),
                .wr      ( from_tx.valid ),
                .wr_rdy  ( from_tx.ready ),
                .wr_data ( from_tx.data ),
                .oflow   ( ),
                .rd      ( to_rx.ready ),
                .rd_vld  ( to_rx.valid ),
                .rd_data ( to_rx.data )
            );
        end : g__obey_ready
    endgenerate

endmodule : bus_pipe_rx
