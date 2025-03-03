// Bus interface 'auto' pipeline stage
//
// Also includes a pipelining FIFO receiver stage to accommodate
// up to 16 stages of slack in valid <-> ready handshaking protocol
// (includes up to 12 auto-inserted pipeline stages, which can
//  be flexibly allocated by the tool between forward and reverse
//  signaling directions).
//
(* autopipeline_module = "true" *) module bus_pipe_auto #(
    parameter bit IGNORE_READY = 1'b0
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    // Parameters
    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    // Interfaces
    bus_intf #(.DATA_T(DATA_T)) bus_if__tx (.clk(bus_if_from_tx.clk));
    bus_intf #(.DATA_T(DATA_T)) bus_if__rx (.clk(bus_if_from_tx.clk));

    // Signals
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic srst;
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic valid;
    (* autopipeline_group = "rev" *) logic ready;
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) DATA_T data;

    logic srst_p;
    logic valid_p;
    logic ready_p;
    DATA_T data_p;

    // Pipeline transmitter
    bus_pipe_tx #(IGNORE_READY) i_bus_pipe_tx (
        .bus_if_from_tx,
        .bus_if_to_rx ( bus_if__tx )
    );

    // Auto-pipelined nets must be driven from register
    always_ff @(posedge bus_if_from_tx.clk) begin
        srst <= bus_if_from_tx.srst;
        valid <= bus_if__tx.valid;
        data <= bus_if_from_tx.data;
    end

    always_ff @(posedge bus_if_from_tx.clk) begin
        ready <= bus_if__rx.ready;
    end

    // Auto-pipelined nets must have fanout == 1
    always_ff @(posedge bus_if_from_tx.clk) begin
        srst_p  <= srst;
        valid_p <= valid;
        data_p  <= data;
    end

    always_ff @(posedge bus_if_from_tx.clk) begin
        ready_p <= ready;
    end

    assign bus_if__rx.srst = srst_p;
    assign bus_if__rx.valid = valid_p;
    assign bus_if__rx.data = data_p;
    assign bus_if__tx.ready = ready_p;

    // Pipeline receiver
    bus_pipe_rx #(
        .IGNORE_READY ( IGNORE_READY ),
        .TOTAL_SLACK  ( 16 )
    ) i_bus_pipe_rx (
        .bus_if_from_tx ( bus_if__rx ),
        .bus_if_to_rx
    );

endmodule : bus_pipe_auto
