interface state_check_intf #(
    parameter int STATE_WID = 1,
    parameter int MSG_WID = 1
) (
    input logic clk
);
    // Signals
    logic                 req;
    logic [STATE_WID-1:0] state;

    logic                 ack;
    logic                 active;
    logic                 notify;
    logic [MSG_WID-1:0]   msg;

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

    task _send_req(input bit [STATE_WID-1:0] _state);
        cb.req <= 1'b1;
        cb.state <= _state;
        @(cb);
        cb.req <= 1'b0;
        cb.state <= 'x;
    endtask

    task check(
            input bit [STATE_WID-1:0] _state,
            output bit                _active,
            output bit                _notify,
            output bit [MSG_WID-1:0] _msg
        );
        _send_req(state);
        wait(cb.ack);
        _active = cb.active;
        _notify = cb.notify;
        _msg = cb.msg;
    endtask

endinterface : state_check_intf
