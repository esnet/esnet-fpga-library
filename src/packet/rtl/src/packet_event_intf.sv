interface packet_event_intf (
    input logic clk
);
    import packet_pkg::*;

    // Signals
    wire logic       evt;
    wire logic[31:0] size;
    wire status_t    status;
    
    // Modports
    modport publisher(
        input  clk,
        output evt,
        output size,
        output status
    );

    modport subscriber(
        input  clk,
        input  evt,
        input  size,
        input  status
    );

    clocking cb_tx @(posedge clk);
        default input #1step output #1step;
        output evt, size, status;
    endclocking

    clocking cb_rx @(posedge clk);
        default input #1step output #1step;
        input evt, size, status;
    endclocking

    task idle_tx();
        cb_tx.evt <= 1'b0;
        cb_tx.size <= 'x;
        cb_tx.status <= STATUS_UNDEFINED;
    endtask

    task idle_rx();
        // Nothing to do
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb_tx);
    endtask

    task notify(
            input int     _size,
            input status_t _status
        );
        cb_tx.evt <= 1'b1;
        cb_tx.size <= _size;
        cb_tx.status <= _status;
        @(cb_tx);
        cb_tx.evt <= 1'b0;
        cb_tx.size <= 'x;
        cb_tx.status <= 'x;
    endtask

endinterface : packet_event_intf
