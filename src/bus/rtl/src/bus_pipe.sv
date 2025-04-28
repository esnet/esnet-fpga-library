// Bus interface pipeline stage
//
// Includes register stages and a pipelining FIFO receiver stage
// to accommodate the required number of stages of slack in
// valid <-> ready handshaking protocol
module bus_pipe #(
    parameter type DATA_T = logic,
    parameter int  STAGES = 1, // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
    parameter bit  IGNORE_READY = 1'b0
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int  TOTAL_SLACK = 2*STAGES;

    // Parameter checking
    initial begin
        std_pkg::param_check($bits(from_tx.DATA_T), $bits(DATA_T), "from_tx.DATA_T");
        std_pkg::param_check($bits(to_rx.DATA_T),   $bits(DATA_T), "to_rx.DATA_T");
        std_pkg::param_check_gt(STAGES, 0, "STAGES");
    end

    generate
        if (STAGES > 0) begin : g__pipe
            // (Local) interfaces
            bus_intf #(.DATA_T(DATA_T)) bus_if__tx (.clk(from_tx.clk));
            bus_intf #(.DATA_T(DATA_T)) bus_if__rx (.clk(from_tx.clk));

            // Pipeline transmitter (includes single pipeline stage)
            bus_pipe_tx #(
                .DATA_T  ( DATA_T )
            ) i_bus_pipe_tx (
                .from_tx,
                .to_rx ( bus_if__tx )
            );

            // Add pipeline stages as specified
            bus_reg_multi    #(
                .DATA_T       ( DATA_T ),
                .STAGES       ( STAGES-1 ) // bus_pipe_tx includes bidirectional pipeline stages
            ) i_bus_reg_multi (
                .from_tx ( bus_if__tx ),
                .to_rx   ( bus_if__rx )
            );
    
            // Pipeline receiver (includes single pipeline stage)
            bus_pipe_rx #(
                .DATA_T       ( DATA_T ),
                .IGNORE_READY ( IGNORE_READY ),
                .TOTAL_SLACK  ( TOTAL_SLACK  )
            ) i_bus_pipe_rx (
                .from_tx ( bus_if__rx ),
                .to_rx
            );
        end : g__pipe
        else begin : g__zero_stage
            bus_intf_connector #(.DATA_T(DATA_T)) i_bus_intf_connector (.*);
        end : g__zero_stage
    endgenerate

endmodule : bus_pipe
