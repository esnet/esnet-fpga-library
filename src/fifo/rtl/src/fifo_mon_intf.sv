interface fifo_mon_intf (
    input wire logic clk
);

    // Signals
    logic        reset;
    logic        full;
    logic        empty;
    logic        oflow;
    logic        uflow;
    logic [31:0] count;
    logic [31:0] ptr;

    modport rx(
        input  clk,
        input  reset,
        input  full,
        input  empty,
        input  uflow,
        input  oflow,
        input  count,
        input  ptr
    );

    modport tx(
        input  clk,
        output reset,
        output full,
        output empty,
        output oflow,
        output uflow,
        output count,
        output ptr
    );
endinterface : fifo_mon_intf

(* autopipeline_module = "true" *) module fifo_mon_pipe_auto (
    fifo_mon_intf.rx from_tx,
    fifo_mon_intf.tx to_rx
);
    (* autopipeline_limit=8 *) logic reset;
    (* autopipeline_limit=8 *) logic full;
    (* autopipeline_limit=8 *) logic empty;
    (* autopipeline_limit=8 *) logic oflow;
    (* autopipeline_limit=8 *) logic uflow;
    (* autopipeline_limit=8 *) logic [31:0] count;
    (* autopipeline_limit=8 *) logic [31:0] ptr;
    
    logic reset_p;
    logic full_p;
    logic empty_p;
    logic oflow_p;
    logic uflow_p;
    logic [31:0] count_p;
    logic [31:0] ptr_p;

    // Auto-pipelined nets must be driven from register
    always_ff @(posedge from_tx.clk) begin
        reset <= from_tx.reset;
        full  <= from_tx.full;
        empty <= from_tx.empty;
        oflow <= from_tx.oflow;
        uflow <= from_tx.uflow;
        count <= from_tx.count;
        ptr   <= from_tx.ptr;
    end

    // Auto-pipelined nets must have fanout == 1
    always_ff @(posedge from_tx.clk) begin
        reset_p <= reset;
        full_p  <= full;
        empty_p <= empty;
        oflow_p <= oflow;
        uflow_p <= uflow;
        count_p <= count;
        ptr_p   <= ptr;
    end

    assign to_rx.reset = reset;
    assign to_rx.full  = full;
    assign to_rx.empty = empty;
    assign to_rx.oflow = oflow;
    assign to_rx.uflow = uflow;
    assign to_rx.count = count;
    assign to_rx.ptr   = ptr;

endmodule : fifo_mon_pipe_auto
