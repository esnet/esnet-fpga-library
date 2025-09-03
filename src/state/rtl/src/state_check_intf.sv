interface state_check_intf #(
    parameter type STATE_T = logic,
    parameter type MSG_T = logic
) (
    input logic clk
);
    // Signals
    logic   req;
    STATE_T state;

    logic   ack;
    logic   active;
    logic   notify;
    MSG_T   msg;

    // Modports
    modport source (
        output req,
        output state,
        input  ack,
        input  active,
        input  notify,
        input  msg
    );

    modport target (
        input  req,
        input  state,
        output ack,
        output active,
        output notify,
        output msg
    );

    clocking cb @(posedge clk);
        output state;
        input ack, active, notify, msg;
        inout req;
    endclocking

    task idle();
        cb.req <= 1'b0;
        cb.state  <= 'x;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task _send_req(input STATE_T _state);
        cb.req <= 1'b1;
        cb.state <= _state;
        @(cb);
        cb.req <= 1'b0;
        cb.state <= 'x;
    endtask

    task check(
            input STATE_T _state,
            output bit _active,
            output bit _notify,
            output MSG_T _msg
        );
        _send_req(state);
        wait(cb.ack);
        _active = cb.active;
        _notify = cb.notify;
        _msg = cb.msg;
    endtask

endinterface : state_check_intf
