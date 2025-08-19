interface bus_intf #(
    parameter int DATA_WID = 1
) (
    input logic clk,
    input logic srst = 1'b0
);

    // Parameter validation
    initial begin
        std_pkg::param_check_gt(DATA_WID, 1, "DATA_WID");
    end

    // Signals
    logic                valid;
    logic                ready;
    logic [DATA_WID-1:0] data;

    // Modports
    modport tx (
        input  clk,
        input  srst,
        output valid,
        input  ready,
        output data
    );

    modport rx (
        input  clk,
        input  srst,
        input  valid,
        output ready,
        input  data
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        inout valid, ready, data;
    endclocking

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task idle_tx();
        cb.valid <= 1'b0;
        cb.data <= '0;
    endtask

    task idle_rx();
        cb.ready <= 1'b0;
    endtask

    task wait_ready();
        wait (cb.ready);
    endtask

    // Send
    // - indicate data to send regardless of readiness
    // - transaction is completed when both valid and
    //   ready are asserted on a particular cycle
    task send(input bit[DATA_WID-1:0] _data);
        cb.valid <= 1'b1;
        cb.data <= _data;
        @(cb);
        wait (cb.valid && cb.ready);
        cb.valid <= 1'b0;
    endtask

    // Push
    // - send data to interface, ignoring ready indication
    // - transaction is completed on cycle that valid is
    //   asserted, regardless of ready value
    task push(input bit[DATA_WID-1:0] _data);
        cb.valid <= 1'b1;
        cb.data <= _data;
        @(cb);
        wait (cb.valid);
        cb.valid <= 1'b0;
    endtask

    // Push when ready
    // - Push data to interface, but only after interface signals
    //   readiness to receive it
    // - transaction is completed on cycle that valid is asserted
    task push_when_ready(input bit[DATA_WID-1:0] _data);
        wait(ready);
        push(_data);
    endtask

    // Receive
    // - indicate readiness to receive data regardless
    //   of valid indication from sender
    // - transaction is completed when both valid and
    //   ready are asserted on a particular cycle
    task receive(output bit[DATA_WID-1:0] _data);
        cb.ready <= 1'b1;
        @(cb);
        wait (cb.valid && cb.ready);
        cb.ready <= 1'b0;
        _data = cb.data;
    endtask

    // Pull
    // - receive data from interface, ingnoring valid indication
    // - transaction is completed on cycle that ready is
    //   asserted, regardless of valid value
    task pull(output bit[DATA_WID-1:0] _data);
        cb.ready <= 1'b1;
        @(cb);
        wait (cb.ready);
        cb.ready <= 1'b0;
        _data = cb.data;
    endtask

    // Ack
    // - receive data from interface by sending ready (ack) in
    //   response to valid indication
    // - transaction is completed on cycle that ready is
    //   asserted
    task ack(output bit[DATA_WID-1:0] _data);
        wait(valid);
        pull(_data);
    endtask

    // Fetch
    // - 'fetch' data from interface using 'ready' signal
    // - data is considered valid on cycle following fetch request,
    //   regardless of 'valid' value
    task fetch(output bit[DATA_WID-1:0] _data);
        cb.ready <= 1'b1;
        @(cb);
        wait (cb.ready);
        cb.ready <= 1'b0;
        @(cb);
        _data = cb.data;
    endtask

    // Fetch + Valid
    // - 'fetch' data from interface using 'ready' signal
    // - data is considered valid when 'valid' signal is asserted
    task fetch_val(output bit[DATA_WID-1:0] _data);
        cb.ready <= 1'b1;
        @(cb);
        wait (cb.ready);
        cb.ready <= 1'b0;
        wait (cb.valid);
        _data = cb.data;
        @(cb);
    endtask

    // Ack + Fetch
    // - 'fetch' data from interface using 'ready' signal, but only
    //   after data readiness is signaled via 'valid' signal
    // - data is considered valid on cycle following fetch request
    task ack_fetch(output bit[DATA_WID-1:0] _data);
        wait(valid);
        fetch(_data);
    endtask

endinterface : bus_intf


module bus_intf_parameter_check (
    bus_intf.rx from_tx,
    bus_intf.tx to_rx
);
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
    end
endmodule


module bus_intf_connector (
    bus_intf.rx from_tx,
    bus_intf.tx to_rx
);
    bus_intf_parameter_check param_check (.*);

    // Connect Tx to Rx signals
    assign to_rx.valid = from_tx.valid;
    assign to_rx.data = from_tx.data;

    // Connect Rx to Tx signals
    assign from_tx.ready = to_rx.ready;

endmodule : bus_intf_connector
