`include "svunit_defines.svh"

module lifecycle_unit_test;
    import svunit_pkg::svunit_testcase;
    import std_verif_pkg::*;
    import std_verif_test_pkg::*;

    string name = "lifecycle_ut";
    svunit_testcase svunit_ut;
    //===================================
    // Clock and synchronization
    //===================================
    // Cleanup runs after SVUnit marks the testcase stopped.
    bit clk = 0;
    always #5ns clk = ~clk;
    default clocking cb @(posedge clk); endclocking
    //===================================
    // Component under test
    //===================================
    counting_agent root;

    //===================================
    // Build / setup / teardown
    //===================================
    function void build(); svunit_ut = new(name); endfunction
    task setup();
        svunit_ut.setup();
        root = new("root");
    endtask
    task teardown();
        if (!root.is_defunct()) begin
            root.stop();
            repeat (2) @(cb);
            root.destroy();
        end
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN
        `SVTEST(hierarchy_lifecycle)
            counting_agent child = new("child");
            root.register_subcomponent(child);
            root.build();
            `FAIL_UNLESS(root.is_built());
            `FAIL_UNLESS(child.is_built());
            `FAIL_UNLESS_EQUAL(root.builds, 1);
            `FAIL_UNLESS_EQUAL(child.builds, 1);
            root.set_debug_level(1);
            `FAIL_UNLESS_EQUAL(child.get_debug_level(), 1);
            root.set_debug_level(0);
            root.idle();
            root.init();
            root.reset();
            `FAIL_UNLESS_EQUAL(child.idles, 1);
            `FAIL_UNLESS_EQUAL(child.inits, 1);
            `FAIL_UNLESS_EQUAL(child.resets, 1);
            root.destroy();
            `FAIL_UNLESS(root.is_defunct());
            `FAIL_UNLESS(child.is_defunct());
        `SVTEST_END

        `SVTEST(run_stop_and_restart)
            root.build();
            root.run();
            root.inbox.put(1);
            wait (root.handled == 1);
            `FAIL_UNLESS(root.is_running());
            root.stop();
            repeat (2) @(cb);
            root.inbox.put(2);
            repeat (2) @(cb);
            `FAIL_UNLESS(root.is_stopped());
            `FAIL_UNLESS_EQUAL(root.handled, 1);
            `FAIL_UNLESS_EQUAL(root.inbox.num(), 1);
            root.run();
            wait (root.handled == 2);
            `FAIL_UNLESS_EQUAL(root.inbox.num(), 0);
        `SVTEST_END

        `SVTEST(manual_start)
            root.disable_autostart();
            root.run();
            root.inbox.put(7);
            repeat (2) @(cb);
            `FAIL_UNLESS(root.is_stopped());
            `FAIL_UNLESS_EQUAL(root.handled, 0);
            root.start();
            wait (root.handled == 1);
            `FAIL_UNLESS(root.is_running());
        `SVTEST_END

        `SVTEST(stop_cancels_pending_start)
            root.disable_autostart();
            root.run();
            repeat (2) @(cb);
            root.stop();
            root.start();
            root.inbox.put(1);
            repeat (2) @(cb);
            `FAIL_UNLESS_EQUAL(root.handled, 0);
            root.enable_autostart();
            root.run();
            wait (root.handled == 1);
            `FAIL_UNLESS_EQUAL(root.run_entries, 1);
        `SVTEST_END

        `SVTEST(immediate_restart_has_one_worker)
            root.run();
            root.stop();
            root.run();
            root.inbox.put(1);
            repeat (2) @(cb);
            `FAIL_UNLESS_EQUAL(root.handled, 1);
            `FAIL_UNLESS_EQUAL(root.run_entries, 1);
        `SVTEST_END

        `SVTEST(finalize_on_stop)
            root.finalize();
            root.stop();
            `FAIL_UNLESS(root.is_defunct());
        `SVTEST_END

        `SVTEST(lock_excludes_second_owner)
            bit acquired = 0;
            bit acquired_early;
            root.lock();
            fork
                begin root.lock(); acquired = 1; root.unlock(); end
                begin
                    repeat (2) @(cb);
                    acquired_early = acquired;
                    root.unlock();
                end
            join
            `FAIL_IF(acquired_early);
            `FAIL_UNLESS(acquired);
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule
