interface std_event_intf #(
    parameter int MSG_WID = 1
) (
    input logic clk
);
    // Signals
    logic               evt;
    logic [MSG_WID-1:0] msg;

    // Modports
    modport publisher (
        output evt,
        output msg
    );

    modport subscriber (
        input evt,
        input msg
    );

`ifndef SYNTHESIS
    // Verification clocking blocks
    clocking cb @(posedge clk);
        output evt, msg;
    endclocking

    task idle();
        cb.evt <= 1'b0;
        cb.msg <= '0;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task notify(input bit[MSG_WID-1:0] _msg);
        // Launch on a clocking event so the payload remains valid for a full cycle.
        @(cb);
        cb.evt <= 1'b1;
        cb.msg <= _msg;
        @(cb);
        cb.evt <= 1'b0;
        cb.msg <= '0;
    endtask
`endif

endinterface : std_event_intf
