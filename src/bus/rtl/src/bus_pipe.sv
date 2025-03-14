// Bus interface pipeline stage
//
// Includes register stages and a pipelining FIFO receiver stage
// to accommodate the required number of stages of slack in
// valid <-> ready handshaking protocol
module bus_pipe #(
    parameter int STAGES = 1, // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
    parameter bit IGNORE_READY = 1'b0
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    // Parameters
    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    generate
        if (STAGES > 0) begin : g__pipe
            // (Local) interfaces
            bus_intf #(.DATA_T(DATA_T)) bus_if__tx (.clk(bus_if_from_tx.clk));
            bus_intf #(.DATA_T(DATA_T)) bus_if__rx (.clk(bus_if_from_tx.clk));

            // Pipeline transmitter (includes single pipeline stage)
            bus_pipe_tx #(IGNORE_READY) i_bus_pipe_tx (
                .bus_if_from_tx,
                .bus_if_to_rx ( bus_if__tx )
            );

            // Add pipeline stages as specified
            bus_reg_multi    #(
                .STAGES       ( STAGES ),
                .IGNORE_READY ( IGNORE_READY )
            ) i_bus_reg_multi (
                .bus_if_from_tx ( bus_if__tx ),
                .bus_if_to_rx   ( bus_if__rx )
            );
    
            // Pipeline receiver (includes single pipeline stage)
            bus_pipe_rx #(
                .IGNORE_READY ( IGNORE_READY ),
                .TOTAL_SLACK  ( 2*STAGES ) // Accommodates 'STAGES' cycles of latency in
                                           // both forward and reverse directions
            ) i_bus_pipe_rx (
                .bus_if_from_tx ( bus_if__rx ),
                .bus_if_to_rx
            );
        end : g__pipe
        else begin : g__zero_stage
            bus_intf_connector i_bus_intf_connector (.*);
        end : g__zero_stage
    endgenerate

endmodule : bus_pipe
