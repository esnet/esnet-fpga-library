interface state_event_intf #(
    parameter type ID_T = logic,
    parameter type MSG_T = logic
) (
    input logic clk
);
    // Signals
    logic  evt;
    ID_T   id;
    MSG_T  msg;

    // Modports
    modport publisher (
        output evt,
        output id,
        output msg
    );

    modport subscriber (
        input evt,
        input id,
        input msg
    );

    clocking cb @(posedge clk);
        output evt, id, msg;
    endclocking

    task idle();
        cb.evt <= 1'b0;
        cb.id  <=   'x;
        cb.msg <=   'x;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task notify(input ID_T _id, input MSG_T _msg);
        cb.evt <= 1'b1;
        cb.id  <= _id;
        cb.msg <= _msg;
        @(cb);
        cb.msg <= 1'b0;
        cb.msg <= '0;
    endtask

endinterface : state_event_intf
