interface alloc_intf #(
    parameter int BUFFER_SIZE = 1,
    parameter int PTR_WID = 1,
    parameter int META_WID = 1
) (
    input logic clk
);

    // Parameters
    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);
    
    // Signals
    logic                 req;
    logic                 rdy;
    logic [PTR_WID-1:0]   ptr;
    logic [PTR_WID-1:0]   nxt_ptr;
    logic                 vld;
    logic                 ack;
    logic                 eof;
    logic [SIZE_WID-1:0]  size;
    logic [META_WID-1:0]  meta;
    logic                 err;

    // Modports
    modport store_tx(
        input  clk,
        output req,
        input  rdy,
        input  ptr,
        output nxt_ptr,
        output vld,
        input  ack,
        output eof,
        output size,
        output meta,
        output err
    );

    modport store_rx(
        input  clk,
        input  req,
        output rdy,
        output ptr,
        input  nxt_ptr,
        input  vld,
        output ack,
        input  eof,
        input  size,
        input  meta,
        input  err
    );

    modport load_tx(
        input  clk,
        output req,
        input  rdy,
        output ptr,
        input  nxt_ptr,
        input  vld,
        output ack,
        input  eof,
        input  size,
        input  meta,
        input  err
    );

    modport load_rx(
        input  clk,
        input  req,
        output rdy,
        input  ptr,
        output nxt_ptr,
        output vld,
        input  ack,
        output eof,
        output size,
        output meta,
        output err
    );

    clocking cb_store @(posedge clk);
        output nxt_ptr, eof, size, meta, err;
        input  rdy, ptr, ack;
        inout  vld, req;
    endclocking

    clocking cb_load @(posedge clk);
        output ptr;
        input  rdy, nxt_ptr, vld, eof, size, meta, err;
        inout  req, ack;
    endclocking

    task store_req(output bit [PTR_WID-1:0] ptr);
        cb_store.req <= 1'b1;
        @(cb_store);
        wait(cb_store.req && cb_store.rdy);
        ptr = cb_store.ptr;
        cb_store.req <= 1'b0;
    endtask

    task store(input bit [PTR_WID-1:0] ptr, input bit eof=1'b0, input bit [SIZE_WID-1:0] size=0, input bit [META_WID-1:0] meta=0, input bit err=1'b0);
        cb_store.vld <= 1'b1;
        cb_store.nxt_ptr <= ptr;
        cb_store.eof   <= eof;
        cb_store.size  <= size;
        cb_store.meta  <= meta;
        cb_store.err   <= err;
        @(cb_store);
        wait(cb_store.vld && cb_store.ack);
        cb_store.vld <= 1'b0;
    endtask

    task load_req(input bit [PTR_WID-1:0] ptr);
        cb_load.req <= 1'b1;
        cb_load.ptr <= ptr;
        @(cb_load);
        wait(cb_load.req && cb_load.rdy);
        cb_load.req <= 1'b0;
    endtask

    task load(output bit [PTR_WID-1:0] ptr, output bit eof, output bit [SIZE_WID-1:0] size, output bit [META_WID-1:0] meta, output bit err);
        cb_load.ack <= 1'b1;
        @(cb_load);
        wait(cb_load.vld && cb_load.ack);
        ptr = cb_load.nxt_ptr;
        eof = cb_load.eof;
        size = cb_load.size;
        meta = cb_load.meta;
        err = cb_load.err;
        cb_load.ack <= 1'b0;
    endtask

endinterface : alloc_intf


// Allocator load interface (back-to-back) connector helper module
module alloc_intf_load_connector (
    alloc_intf.load_rx from_tx,
    alloc_intf.load_tx to_rx
);
    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.BUFFER_SIZE, to_rx.BUFFER_SIZE, "BUFFER_SIZE");
        std_pkg::param_check(from_tx.PTR_WID,     to_rx.PTR_WID,     "PTR_WID");
        std_pkg::param_check(from_tx.META_WID,    to_rx.META_WID,    "META_WID");
    end

    // Connect signals (tx -> rx)
    assign to_rx.req = from_tx.req;
    assign to_rx.ptr = from_tx.ptr;
    assign to_rx.ack = from_tx.ack;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;
    assign from_tx.nxt_ptr = to_rx.nxt_ptr;
    assign from_tx.vld = to_rx.vld;
    assign from_tx.eof = to_rx.eof;
    assign from_tx.size = to_rx.size;
    assign from_tx.meta = to_rx.meta;
    assign from_tx.err = to_rx.err;
endmodule


// Allocator store interface (back-to-back) connector helper module
module alloc_intf_store_connector (
    alloc_intf.store_rx from_tx,
    alloc_intf.store_tx to_rx
);
    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.BUFFER_SIZE, to_rx.BUFFER_SIZE, "BUFFER_SIZE");
        std_pkg::param_check(from_tx.PTR_WID,     to_rx.PTR_WID,     "PTR_WID");
        std_pkg::param_check(from_tx.META_WID,    to_rx.META_WID,    "META_WID");
    end

    // Connect signals (tx -> rx)
    assign to_rx.req = from_tx.req;
    assign to_rx.nxt_ptr = from_tx.nxt_ptr;
    assign to_rx.vld = from_tx.vld;
    assign to_rx.eof = from_tx.eof;
    assign to_rx.size = from_tx.size;
    assign to_rx.meta = from_tx.meta;
    assign to_rx.err = from_tx.err;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;
    assign from_tx.ptr = to_rx.ptr;
    assign from_tx.ack = to_rx.ack;
endmodule
