`include "svunit_defines.svh"

module environments_unit_test;
    import svunit_pkg::svunit_testcase;
    import std_verif_pkg::*;
    import std_verif_test_pkg::*;

    string name = "environments_ut";
    svunit_testcase svunit_ut;
    //===================================
    // Components under test
    //===================================
    component workers[$];
    //===================================
    // Clock and synchronization
    //===================================
    // Cleanup runs after SVUnit marks the testcase stopped.
    bit clk = 0;
    always #5ns clk = ~clk;
    default clocking cb @(posedge clk); endclocking
    //===================================
    // Reset interfaces
    //===================================
    std_reset_intf reset_if (.clk);
    std_reset_intf #(.ACTIVE_LOW(1)) reset_low_if (.clk);
    assign reset_if.ready = !reset_if.reset;
    assign reset_low_if.ready = reset_low_if.reset;

    //===================================
    // Build / setup / teardown
    //===================================
    function void build(); svunit_ut = new(name); endfunction
    task setup(); svunit_ut.setup(); endtask
    task teardown();
        foreach (workers[i]) workers[i].stop();
        repeat (2) @(cb);
        foreach (workers[i]) workers[i].destroy();
        workers.delete();
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN
        `SVTEST(basic_reset_active_high)
            basic_env env = new();
            workers.push_back(env);
            env.reset_vif = reset_if;
            env.set_reset_timeout(4);
            `FAIL_UNLESS_EQUAL(env.get_reset_timeout(), 4);
            env.build(); env.reset_dut();
            `FAIL_UNLESS_EQUAL(reset_if.reset, 0);
            `FAIL_UNLESS_EQUAL(reset_if.ready, 1);
            env.wait_n(2);
        `SVTEST_END

        `SVTEST(basic_reset_active_low)
            basic_env#(1) env = new();
            workers.push_back(env);
            env.reset_vif = reset_low_if;
            env.build(); env.reset_dut();
            `FAIL_UNLESS_EQUAL(reset_low_if.reset, 1);
            `FAIL_UNLESS_EQUAL(reset_low_if.ready, 1);
        `SVTEST_END

        `SVTEST(wire_environment_end_to_end)
            loopback_env env = new();
            word_t item;
            string msg;
            workers.push_back(env);
            env.reset_vif = reset_if;
            env.build(); env.run();
            for (int i = 0; i < 8; i++) begin
                item = new("input", $urandom);
                env.inbox.put(item);
            end
            wait (env.scoreboard.got_matched() == 8);
            env.stop(); repeat (2) @(cb);
            `FAIL_UNLESS_EQUAL(env.driver.num_transactions(), 8);
            `FAIL_UNLESS_EQUAL(env.monitor.num_transactions(), 8);
            `FAIL_UNLESS_EQUAL(env.model.num_input_transactions(), 8);
            `FAIL_UNLESS_EQUAL(env.scoreboard.report(msg), 0);
        `SVTEST_END

        `SVTEST(controlled_environment_registers_agent)
            controlled_loopback_env env = new();
            word_t item = new("input", 32'h1234);
            string msg;
            workers.push_back(env);
            env.reset_vif = reset_if;
            env.build(); env.run();
            `FAIL_UNLESS(env.agent.is_built());
            `FAIL_UNLESS_EQUAL(env.agent.builds, 1);
            `FAIL_UNLESS_EQUAL(env.agent.resets, 1);
            `FAIL_UNLESS_EQUAL(env.agent.inits, 1);
            env.inbox.put(item);
            wait (env.scoreboard.got_matched() == 1);
            env.stop(); repeat (2) @(cb);
            `FAIL_UNLESS(env.agent.is_stopped());
            `FAIL_UNLESS_EQUAL(env.scoreboard.report(msg), 0);
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule
