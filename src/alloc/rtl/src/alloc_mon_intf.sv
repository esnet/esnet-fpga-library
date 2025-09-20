// Allocator monitor interface
interface alloc_mon_intf (
    input logic clk
);

    // Signals
    logic        alloc;
    logic        alloc_fail;
    logic        alloc_err;
    logic        dealloc;
    logic        dealloc_fail;
    logic        dealloc_err;
    logic [31:0] ptr;

    modport rx(
        input  clk,
        input  alloc,
        input  alloc_fail,
        input  alloc_err,
        input  dealloc,
        input  dealloc_fail,
        input  dealloc_err,
        input  ptr
    );

    modport tx(
        input  clk,
        output alloc,
        output alloc_fail,
        output alloc_err,
        output dealloc,
        output dealloc_fail,
        output dealloc_err,
        output ptr
    );
endinterface : alloc_mon_intf

(* autopipeline_module = "true" *) module alloc_mon_pipe_auto (
    alloc_mon_intf.rx from_tx,
    alloc_mon_intf.tx to_rx
);
    (* autopipeline_limit=8 *) logic alloc;
    (* autopipeline_limit=8 *) logic alloc_fail;
    (* autopipeline_limit=8 *) logic dealloc;
    (* autopipeline_limit=8 *) logic dealloc_fail;
    (* autopipeline_limit=8, autopipeline_group="err" *) logic alloc_err;
    (* autopipeline_limit=8, autopipeline_group="err" *) logic dealloc_err;
    (* autopipeline_limit=8, autopipeline_group="err" *) logic[31:0] ptr;

    logic alloc_p;
    logic alloc_fail_p;
    logic dealloc_p;
    logic dealloc_fail_p;
    logic alloc_err_p;
    logic dealloc_err_p;
    logic[31:0] ptr_p;

    // Auto-pipelined nets must be driven from register
    always_ff @(posedge from_tx.clk) begin
        alloc        <= from_tx.alloc;
        alloc_fail   <= from_tx.alloc_fail;
        alloc_err    <= from_tx.alloc_err;
        dealloc      <= from_tx.dealloc;
        dealloc_fail <= from_tx.dealloc_fail;
        dealloc_err  <= from_tx.dealloc_err;
        ptr          <= from_tx.ptr;
    end

    // Auto-pipelined nets must have fanout == 1
    always_ff @(posedge from_tx.clk) begin
        alloc_p        <= alloc;
        alloc_fail_p   <= alloc_fail;
        alloc_err_p    <= alloc_err;
        dealloc_p      <= dealloc;
        dealloc_fail_p <= dealloc_fail;
        dealloc_err_p  <= dealloc_err;
        ptr_p          <= ptr;
    end

    assign to_rx.alloc        = alloc_p;
    assign to_rx.alloc_fail   = alloc_fail_p;
    assign to_rx.alloc_err    = alloc_err_p;
    assign to_rx.dealloc      = dealloc_p;
    assign to_rx.dealloc_fail = dealloc_fail_p;
    assign to_rx.dealloc_err  = dealloc_err_p;
    assign to_rx.ptr          = ptr_p;

endmodule : alloc_mon_pipe_auto
