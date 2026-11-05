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

endinterface : state_check_intf
