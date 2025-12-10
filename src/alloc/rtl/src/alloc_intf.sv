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


// Allocator load interface (back-to-back) connector helper module
module alloc_intf_load_mux #(
    parameter int N = 2,
    // Derived parameters (don't override)
    parameter int SEL_WID = $clog2(N)
) (
    input  logic               clk,
    input  logic               srst,
    alloc_intf.load_rx         from_tx [N],
    alloc_intf.load_tx         to_rx,
    input  logic [SEL_WID-1:0] sel,
    output logic [SEL_WID-1:0] sel_out
);
    // Parameters
    localparam int N_POW2 = 2**SEL_WID;
    localparam int BUFFER_SIZE = to_rx.BUFFER_SIZE;
    localparam int PTR_WID = to_rx.PTR_WID;
    localparam int META_WID = to_rx.META_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx[0].BUFFER_SIZE, BUFFER_SIZE, "BUFFER_SIZE");
        std_pkg::param_check(from_tx[0].PTR_WID,     PTR_WID,     "PTR_WID");
        std_pkg::param_check(from_tx[0].META_WID,    META_WID,    "META_WID");
        std_pkg::param_check_gt(N, 2, "N");
    end

    // Signals
    logic               from_tx_req  [N_POW2];
    logic [PTR_WID-1:0] from_tx_ptr  [N_POW2];
    logic               from_tx_ack  [N_POW2];

    logic               sel_out_vld;

    generate
        for (genvar g_input = 0; g_input < N; g_input++) begin : g__input
            assign from_tx_req[g_input] = from_tx[g_input].req;
            assign from_tx_ptr[g_input] = from_tx[g_input].ptr;
            assign from_tx_ack[g_input] = from_tx[g_input].ack;
            assign from_tx[g_input].rdy = (sel == g_input) ? to_rx.rdy : 1'b0;

            assign from_tx[g_input].nxt_ptr = to_rx.nxt_ptr;
            assign from_tx[g_input].eof     = to_rx.eof;
            assign from_tx[g_input].size    = to_rx.size;
            assign from_tx[g_input].meta    = to_rx.meta;
            assign from_tx[g_input].err     = to_rx.err;
            assign from_tx[g_input].vld = (sel == g_input) ? to_rx.vld : 1'b0;
        end : g__input
        for (genvar g_input = N; g_input < N_POW2; g_input++) begin : g__input_tieoff
            assign from_tx_req[g_input] = 1'b0;
            assign from_tx_ptr[g_input] = '0;
            assign from_tx_ack[g_input] = 1'b0;
        end : g__input_tieoff
    endgenerate
    // Mux logic
    assign to_rx.req = from_tx_req[sel];
    assign to_rx.ptr = from_tx_ptr[sel];

    fifo_ctxt        #(
        .DATA_WID     ( SEL_WID ),
        .DEPTH        ( N*2 ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__packet (
        .clk,
        .srst,
        .wr_rdy   ( ),
        .wr       ( to_rx.req && to_rx.rdy ),
        .wr_data  ( sel ),
        .rd       ( to_rx.vld && to_rx.ack ),
        .rd_vld   ( sel_out_vld ),
        .rd_data  ( sel_out ),
        .oflow    ( ),
        .uflow    ( )
    );

    assign to_rx.ack = from_tx_ack[sel_out];

endmodule

