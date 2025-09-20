interface packet_descriptor_intf #(
    parameter int ADDR_WID = 1,
    parameter int META_WID = 1,
    parameter int MAX_PKT_SIZE = 16383
) (
    input logic clk,
    input logic srst = 1'b0
);
    // Parameters
    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    // Signals
    logic                vld;
    logic                rdy;
    logic [ADDR_WID-1:0] addr;
    logic [SIZE_WID-1:0] size;
    logic                err;
    logic [META_WID-1:0] meta;
    
    // Modports
    modport tx(
        input  clk,
        input  srst,
        output vld,
        input  rdy,
        output addr,
        output size,
        output err,
        output meta
    );

    modport rx(
        input  clk,
        input  srst,
        input  vld,
        output rdy,
        input  addr,
        input  size,
        input  err,
        input  meta
    );

    clocking cb_tx @(posedge clk);
        output vld, addr, size, err, meta;
        input rdy;
    endclocking

    clocking cb_rx @(posedge clk);
        input vld, addr, size, err, meta;
        output rdy;
    endclocking

    task idle_tx();
        cb_tx.vld <= 1'b0;
        cb_tx.addr <= 'x;
        cb_tx.size <= 'x;
        cb_tx.err  <= 1'bx;
        cb_tx.meta <= 'x;
    endtask

    task idle_rx();
        cb_rx.rdy <= 1'b0;
    endtask

    task flush();
        cb_rx.rdy <= 1'b1;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb_tx);
    endtask

    task send(
            input bit [ADDR_WID-1:0] _addr,
            input int                _size,
            input bit [META_WID-1:0] _meta = '0,
            input bit                _err = 1'b0
        );
        cb_tx.vld  <= 1'b1;
        cb_tx.addr <= _addr;
        cb_tx.size <= _size[SIZE_WID-1:0];
        cb_tx.err  <= _err;
        cb_tx.meta <= _meta;
        @(cb_tx);
        wait (cb_tx.rdy);
        cb_tx.vld  <= 1'b0;
    endtask

    task receive(
            output bit [ADDR_WID-1:0] _addr,
            output int                _size,
            output bit [META_WID-1:0] _meta,
            output bit                _err
        );
        cb_rx.rdy <= 1'b1;
        @(cb_rx);
        wait(cb_rx.vld);
        cb_rx.rdy <= 1'b0;
        _addr = cb_rx.addr;
        _size = cb_rx.size;
        _meta = cb_rx.meta;
        _err  = cb_rx.err;
    endtask

    task wait_ready(
            output bit _timeout,
            input  int TIMEOUT=0
        );
        fork
            begin
                fork
                    begin
                        wait(cb_tx.rdy);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

endinterface : packet_descriptor_intf

// Helper module to check that parameterization of a 2-port component is consistent on rx/tx ports
module packet_descriptor_intf_parameter_check (
    packet_descriptor_intf from_tx,
    packet_descriptor_intf to_rx
);
    initial begin
        std_pkg::param_check(to_rx.ADDR_WID, from_tx.ADDR_WID, "to_rx.ADDR_WID");
        std_pkg::param_check(to_rx.META_WID, from_tx.META_WID, "to_rx.META_WID");
        std_pkg::param_check_gt(to_rx.MAX_PKT_SIZE, from_tx.MAX_PKT_SIZE, "to_rx.MAX_PKT_SIZE");
    end
endmodule

// Packet descriptor interface (back-to-back) connector helper module
module packet_descriptor_intf_connector (
    packet_descriptor_intf.rx from_tx,
    packet_descriptor_intf.tx to_rx
);
    // Parameter checking
    packet_descriptor_intf_parameter_check param_check (.*);

    // Connect signals (tx -> rx)
    assign to_rx.vld  = from_tx.vld;
    assign to_rx.addr = from_tx.addr;
    assign to_rx.size = from_tx.size;
    assign to_rx.err  = from_tx.err;
    assign to_rx.meta = from_tx.meta;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_descriptor_intf_connector
