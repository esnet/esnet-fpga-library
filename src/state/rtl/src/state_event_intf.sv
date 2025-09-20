interface state_event_intf #(
    parameter int ID_WID = 1,
    parameter int MSG_WID = 1
) (
    input logic clk
);
    // Signals
    logic               evt;
    logic [ID_WID-1:0]  id;
    logic [MSG_WID-1:0] msg;

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

    task notify(input bit [ID_WID-1:0] _id, input bit [MSG_WID-1:0] _msg);
        cb.evt <= 1'b1;
        cb.id  <= _id;
        cb.msg <= _msg;
        @(cb);
        cb.msg <= 1'b0;
        cb.msg <= '0;
    endtask

endinterface : state_event_intf
