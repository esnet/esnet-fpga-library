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

endinterface : state_event_intf
