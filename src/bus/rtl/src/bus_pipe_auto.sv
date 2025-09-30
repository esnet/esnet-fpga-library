// Bus interface 'auto' pipeline stage
//
// Also includes a pipelining FIFO receiver stage to accommodate
// up to 16 stages of slack in valid <-> ready handshaking protocol
// (includes up to 12 auto-inserted pipeline stages, which can
//  be flexibly allocated by the tool between forward and reverse
//  signaling directions).
//
(* autopipeline_module = "true" *) module bus_pipe_auto (
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
    logic srst;

    assign clk = from_tx.clk;
    assign srst = from_tx.srst;

    // Interfaces
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx (.clk, .srst);

    // Signals
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic valid;
    (* autopipeline_group = "rev" *) logic ready;
    (* autopipeline_group = "fwd", autopipeline_limit=12, autopipeline_include = "rev" *) logic [DATA_WID-1:0] data;

    // Evaluate valid <-> ready handshake at input
    assign bus_if__tx.valid = from_tx.valid && bus_if__tx.ready;
    assign bus_if__tx.data = from_tx.data;
    assign from_tx.ready = bus_if__tx.ready;

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

    // Implement Rx FIFO to accommodate specified slack
    // in valid <-> ready handshake protocol
    fifo_prefetch #(
        .DATA_WID  ( DATA_WID ),
        .PIPELINE_DEPTH ( 16 )
    ) i_fifo_prefetch (
        .clk,
        .srst,
        .wr      ( bus_if__rx.valid ),
        .wr_rdy  ( bus_if__rx.ready ),
        .wr_data ( bus_if__rx.data ),
        .oflow   ( ),
        .rd      ( to_rx.ready ),
        .rd_vld  ( to_rx.valid ),
        .rd_data ( to_rx.data )
    );

endmodule : bus_pipe_auto
