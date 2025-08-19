// Bus interface pipeline stage
//
// Includes register stages and a pipelining FIFO receiver stage
// to accommodate the required number of stages of slack in
// valid <-> ready handshaking protocol
module bus_pipe #(
    parameter int  STAGES = 1, // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
    parameter bit  IGNORE_READY = 1'b0
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int  TOTAL_SLACK = 2*STAGES;
    localparam int  DATA_WID = from_tx.DATA_WID;

    // Parameter checking
    bus_intf_parameter_check param_check (.*);
    initial begin
        std_pkg::param_check_gt(STAGES, 0, "STAGES");
    end

    generate
        if (STAGES > 0) begin : g__pipe
            // (Local) interfaces
            bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx (.clk(from_tx.clk));
            bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx (.clk(from_tx.clk));

            // Pipeline transmitter
            bus_pipe_tx i_bus_pipe_tx (
                .from_tx,
                .to_rx ( bus_if__tx )
            );

            // Add pipeline stages as specified
            bus_reg_multi    #(
                .STAGES       ( STAGES )
            ) i_bus_reg_multi (
                .from_tx ( bus_if__tx ),
                .to_rx   ( bus_if__rx )
            );
    
            // Pipeline receiver (includes single pipeline stage)
            bus_pipe_rx #(
                .IGNORE_READY ( IGNORE_READY ),
                .TOTAL_SLACK  ( TOTAL_SLACK  )
            ) i_bus_pipe_rx (
                .from_tx ( bus_if__rx ),
                .to_rx
            );
        end : g__pipe
        else begin : g__zero_stage
            bus_intf_connector i_bus_intf_connector (.*);
        end : g__zero_stage
    endgenerate

endmodule : bus_pipe
