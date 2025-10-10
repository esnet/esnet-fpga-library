// Bus interface 'auto' pipeline stage
//
// Also includes a pipelining FIFO receiver stage to accommodate
// up to 16 stages of slack in valid <-> ready handshaking protocol
// (includes up to 12 auto-inserted pipeline stages, which can
//  be flexibly allocated by the tool between forward and reverse
//  signaling directions).
//
(* autopipeline_module = "true" *) module bus_pipe_auto (
    input logic   srst,
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int DATA_WID = from_tx.DATA_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
    end

    // Clock/reset
    logic clk;

    assign clk = from_tx.clk;

    // Interfaces
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx (.clk);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx (.clk);

    // Signals
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic valid;
    (* autopipeline_group = "rev" *) logic ready;
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic [DATA_WID-1:0] data;

    // Pipeline transmitter
    bus_pipe_tx i_bus_pipe_tx (
        .from_tx,
        .to_rx   ( bus_if__tx )
    );

    // Auto-pipelined nets must be driven from register
    initial ready = 1'b0;
    always @(posedge clk) begin
        ready <= bus_if__rx.ready;
    end

    // Auto-pipelined nets must have fanout == 1
    initial valid = 1'b0;
    always @(posedge clk) begin
        valid <= bus_if__tx.valid;
        data  <= bus_if__tx.data;
    end

    assign bus_if__rx.valid = valid;
    assign bus_if__rx.data = data;
    assign bus_if__tx.ready = ready;

    // Pipeline receiver
    bus_pipe_rx #(
        .TOTAL_SLACK ( 16 )
    ) i_bus_pipe_rx (
        .srst,
        .from_tx ( bus_if__rx ),
        .to_rx
    );

endmodule : bus_pipe_auto
