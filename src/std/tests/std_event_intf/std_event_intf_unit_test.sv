`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module std_event_intf_unit_test;
    import svunit_pkg::svunit_testcase;
    string name = "std_event_intf_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Clock and event interfaces
    //===================================
    logic clk;
    `SVUNIT_CLK_GEN(clk, 5ns);
    std_event_intf #(.MSG_WID(13)) event_if (.clk);
    std_event_intf bit_if (.clk);
    wire evt = event_if.evt;
    wire [12:0] msg = event_if.msg;
    wire bit_evt = bit_if.evt;
    wire bit_msg = bit_if.msg;
    clocking cb @(negedge clk);
        input evt, msg, bit_evt, bit_msg;
    endclocking

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction
    task setup();
        svunit_ut.setup();
        event_if.idle();
        bit_if.idle();
        repeat (2) @(cb);
    endtask
    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Notification checking
    //===================================
    task automatic check_notify(input bit [12:0] payload);
        fork
            event_if.notify(payload);
            begin
                @(cb);
                `FAIL_UNLESS(cb.evt);
                `FAIL_UNLESS_EQUAL(cb.msg, payload);
                @(cb);
                `FAIL_IF(cb.evt);
                `FAIL_UNLESS_EQUAL(cb.msg, 13'b0);
            end
        join
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN
        `SVTEST(notification_pulse)
            check_notify(13'h15A5);
            repeat (3) begin
                @(cb);
                `FAIL_IF(cb.evt);
            end
        `SVTEST_END
        `SVTEST(repeated_notifications)
            repeat (16) check_notify(13'($urandom));
        `SVTEST_END
        `SVTEST(default_message_width)
            fork
                bit_if.notify(1);
                begin
                    @(cb);
                    `FAIL_UNLESS(cb.bit_evt && cb.bit_msg);
                    @(cb);
                    `FAIL_IF(cb.bit_evt || cb.bit_msg);
                end
            join
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule : std_event_intf_unit_test
