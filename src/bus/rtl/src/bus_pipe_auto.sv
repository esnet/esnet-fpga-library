// Bus interface 'auto' pipeline stage
//
// Also includes a pipelining FIFO receiver stage to accommodate
// up to 16 stages of slack in valid <-> ready handshaking protocol
// (includes up to 12 auto-inserted pipeline stages, which can
//  be flexibly allocated by the tool between forward and reverse
//  signaling directions).
//
(* autopipeline_module = "true" *) module bus_pipe_auto #(
    parameter type DATA_T = logic,
    parameter bit  IGNORE_READY = 1'b0
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameter checking
    initial begin
        std_pkg::param_check($bits(from_tx.DATA_T), $bits(DATA_T), "from_tx.DATA_T");
        std_pkg::param_check($bits(to_rx.DATA_T),   $bits(DATA_T), "to_rx.DATA_T");
    end

    // Signals
    logic clk;
    assign clk = from_tx.clk;

    // Interfaces
    bus_intf #(.DATA_T(DATA_T)) bus_if__tx (.clk);
    bus_intf #(.DATA_T(DATA_T)) bus_if__rx (.clk);

    // Signals
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic srst;
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic valid;
    (* autopipeline_group = "rev" *) logic ready;
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) DATA_T data;

    // Pipeline transmitter
    bus_pipe_tx #(
        .DATA_T  ( DATA_T )
    ) i_bus_pipe_tx (
        .from_tx,
        .to_rx ( bus_if__tx )
    );

    // Auto-pipelined nets must be driven from register
    // (bus_pipe_tx drives forward signals from registers)
    initial ready = 1'b0;
    always @(posedge clk) begin
        ready <= bus_if__rx.ready;
    end

    // Auto-pipelined nets must have fanout == 1
    // (bus_pipe_tx receives reverse signals into registers)
    initial begin
        srst = 1'b1;
        valid = 1'b0;
    end
    always @(posedge clk) begin
        srst  <= bus_if__tx.srst;
        valid <= bus_if__tx.valid;
        data  <= bus_if__tx.data;
    end

    assign bus_if__rx.srst = srst;
    assign bus_if__rx.valid = valid;
    assign bus_if__rx.data = data;
    assign bus_if__tx.ready = ready;

    // Pipeline receiver
    bus_pipe_rx #(
        .DATA_T       ( DATA_T ),
        .IGNORE_READY ( IGNORE_READY ),
        .TOTAL_SLACK  ( 16 )
    ) i_bus_pipe_rx (
        .from_tx ( bus_if__rx ),
        .to_rx
    );

endmodule : bus_pipe_auto
