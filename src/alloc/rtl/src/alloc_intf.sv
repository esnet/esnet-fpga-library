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
        output req, vld, nxt_ptr, eof, size, meta, err;
        input  rdy, ptr, ack;
    endclocking

    clocking cb_load @(posedge clk);
        output req, ptr, ack;
        input  rdy, nxt_ptr, vld, eof, size, meta, err;
    endclocking

    task store_req(output bit [PTR_WID-1:0] ptr);
        cb_store.req <= 1'b1;
        @(cb_store);
        wait(cb_store.rdy);
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
        wait(cb_store.ack);
        cb_store.vld <= 1'b0;
    endtask

    task load_req(input bit [PTR_WID-1:0] ptr);
        cb_load.req <= 1'b1;
        cb_load.ptr <= ptr;
        @(cb_load);
        wait(cb_load.rdy);
        cb_load.req <= 1'b0;
    endtask

    task load(output bit [PTR_WID-1:0] ptr, output bit eof, output bit [SIZE_WID-1:0] size, output bit [META_WID-1:0] meta, output bit err);
        cb_load.ack <= 1'b1;
        @(cb_load);
        wait(cb_load.vld);
        ptr = cb_load.nxt_ptr;
        eof = cb_load.eof;
        size = cb_load.size;
        meta = cb_load.meta;
        err = cb_load.err;
        cb_load.ack <= 1'b0;
    endtask

endinterface : alloc_intf
