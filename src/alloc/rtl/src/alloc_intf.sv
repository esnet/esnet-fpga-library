interface alloc_intf #(
    parameter int  BUFFER_SIZE = 1,
    parameter type PTR_T = logic,
    parameter type META_T = logic
) (
    input wire logic clk,
    input wire logic srst
);

    // Parameters
    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);
    localparam type SIZE_T = logic[SIZE_WID-1:0];
    
    // Signals
    wire logic  req;
    wire logic  rdy;
    wire PTR_T  ptr;
    wire PTR_T  nxt_ptr;
    wire logic  valid;
    wire logic  ack;
    wire logic  eof;
    wire SIZE_T size;
    wire META_T meta;
    wire logic  err;
    
    var  logic  sof;

    // Modports
    modport store_tx(
        input  clk,
        input  srst,
        output req,
        input  rdy,
        input  ptr,
        output nxt_ptr,
        output valid,
        input  ack,
        output eof,
        output size,
        output meta,
        output err,
        input  sof
    );

    modport store_rx(
        input  clk,
        input  srst,
        input  req,
        output rdy,
        output ptr,
        input  nxt_ptr,
        input  valid,
        output ack,
        input  eof,
        input  size,
        input  meta,
        input  err,
        input  sof
    );

    modport load_tx(
        input  clk,
        input  srst,
        output req,
        input  rdy,
        output ptr,
        input  nxt_ptr,
        input  valid,
        output ack,
        input  eof,
        input  size,
        input  meta,
        input  err,
        input  sof
    );

    modport load_rx(
        input  clk,
        input  srst,
        input  req,
        output rdy,
        input  ptr,
        output nxt_ptr,
        output valid,
        input  ack,
        output eof,
        output size,
        output meta,
        output err,
        input  sof
    );

    // Track SOF
    initial sof = 1'b1;
    always @(posedge clk) begin
        if (srst) sof <= 1'b1;
        else if (valid && ack && eof) sof <= 1'b1;
        else if (valid && ack) sof <= 1'b0;
    end

    clocking cb_store @(posedge clk);
        default input #1step output #1step;
        output req, valid, nxt_ptr, eof, size, meta, err;
        input  rdy, ptr, ack;
    endclocking

    clocking cb_load @(posedge clk);
        default input #1step output #1step;
        output req, ptr, ack;
        input  rdy, nxt_ptr, valid, eof, size, meta, err;
    endclocking

    task store_req(output PTR_T ptr);
        cb_store.req <= 1'b1;
        @(cb_store);
        wait(cb_store.rdy);
        ptr = cb_store.ptr;
        cb_store.req <= 1'b0;
    endtask

    task store(input PTR_T ptr, input logic eof=1'b0, input SIZE_T size=0, input META_T meta=0, input logic err=1'b0);
        cb_store.valid <= 1'b1;
        cb_store.nxt_ptr <= ptr;
        cb_store.eof   <= eof;
        cb_store.size  <= size;
        cb_store.meta  <= meta;
        cb_store.err   <= err;
        @(cb_store);
        wait(cb_store.ack);
        cb_store.valid <= 1'b0;
    endtask

    task load_req(input PTR_T ptr);
        cb_load.req <= 1'b1;
        cb_load.ptr <= ptr;
        @(cb_load);
        wait(cb_load.rdy);
        cb_load.req <= 1'b0;
    endtask

    task load(output PTR_T ptr, output logic eof, output SIZE_T size, output META_T meta, output logic err);
        cb_load.ack <= 1'b1;
        @(cb_load);
        wait(cb_load.valid);
        ptr = cb_load.nxt_ptr;
        eof = cb_load.eof;
        size = cb_load.size;
        meta = cb_load.meta;
        err = cb_load.err;
        cb_load.ack <= 1'b0;
    endtask

endinterface : alloc_intf
