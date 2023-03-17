interface std_event_intf #(
    parameter type MSG_T = logic
) (
    input logic clk
);
    // Signals
    logic  evt;
    MSG_T  msg;

    // Modports
    modport publisher (
        output evt,
        output msg
    );

    modport subscriber (
        input evt,
        input msg
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        output evt, msg;
    endclocking

    task idle();
        cb.evt <= 1'b0;
        cb.msg <= '0;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task notify(input MSG_T _msg);
        cb.evt <= 1'b1;
        cb.msg <= _msg;
        @(cb);
        cb.msg <= 1'b0;
        cb.msg <= '0;
    endtask

endinterface : std_event_intf
