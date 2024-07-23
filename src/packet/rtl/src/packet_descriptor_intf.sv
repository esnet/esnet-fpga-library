interface packet_descriptor_intf #(
    parameter type ADDR_T = logic,
    parameter type META_T = logic,
    parameter type SIZE_T = logic[15:0]
) (
    input wire logic clk,
    input wire logic srst = 1'b0
);
    import packet_pkg::*;

    // Signals
    wire logic        valid;
    wire logic        rdy;
    wire ADDR_T       addr;
    wire SIZE_T       size;
    wire META_T       meta;
    
    // Modports
    modport tx(
        input  clk,
        input  srst,
        output valid,
        input  rdy,
        output addr,
        output size,
        output meta
    );

    modport rx(
        input  clk,
        input  srst,
        input  valid,
        output rdy,
        input  addr,
        input  size,
        input  meta
    );

    clocking cb_tx @(posedge clk);
        default input #1step output #1step;
        output valid, addr, size, meta;
        input rdy;
    endclocking

    clocking cb_rx @(posedge clk);
        default input #1step output #1step;
        input valid, addr, size, meta;
        output rdy;
    endclocking

    task idle_tx();
        cb_tx.valid <= 1'b0;
        cb_tx.addr <= 'x;
        cb_tx.size <= 'x;
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
            input ADDR_T   _addr,
            input SIZE_T   _size,
            input META_T   _meta = '0
        );
        cb_tx.valid  <= 1'b1;
        cb_tx.addr   <= _addr;
        cb_tx.size   <= _size;
        cb_tx.meta   <= _meta;
        @(cb_tx);
        wait (cb_tx.rdy);
        cb_tx.valid  <= 1'b0;
    endtask

    task receive(
            output ADDR_T   _addr,
            output SIZE_T   _size,
            output META_T   _meta
        );
        cb_rx.rdy <= 1'b1;
        @(cb_rx);
        wait(cb_rx.valid);
        cb_rx.rdy <= 1'b0;
        _addr   = cb_rx.addr;
        _size   = cb_rx.size;
        _meta   = cb_rx.meta;
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

// Packet descriptor interface (back-to-back) connector helper module
module packet_descriptor_intf_connector (
    packet_descriptor_intf.rx from_tx,
    packet_descriptor_intf.tx to_rx
);
    // Connect signals (tx -> rx)
    assign to_rx.valid  = from_tx.valid;
    assign to_rx.addr   = from_tx.addr;
    assign to_rx.size   = from_tx.size;
    assign to_rx.meta   = from_tx.meta;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_descriptor_intf_connector
