`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module std_block_cdc_unit_test;
    import svunit_pkg::svunit_testcase;
    string name = "std_block_cdc_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Independent clocks and stimulus
    //===================================
    logic ctrl_clk, blk_clk;
    `SVUNIT_CLK_GEN(ctrl_clk, 5ns);
    `SVUNIT_CLK_GEN(blk_clk, 7ns);
    logic ctrl_reset_in = 0, ctrl_enable_in = 0;
    logic blk_reset_mon_in = 0, blk_enable_mon_in = 0, blk_ready_mon_in = 0;
    logic [7:0] blk_state_mon_in = 0;
    wire blk_reset_out, blk_enable_out;
    wire ctrl_reset_mon_out, ctrl_enable_mon_out, ctrl_ready_mon_out;
    wire [7:0] ctrl_state_mon_out;

    //===================================
    // DUTs and domain-specific clocking
    //===================================
    std_block_control DUT_control (.*);
    std_block_monitor DUT_monitor (.*);
    clocking ctrl_cb @(negedge ctrl_clk);
        output ctrl_reset_in, ctrl_enable_in;
        input ctrl_reset_mon_out, ctrl_enable_mon_out;
        input ctrl_ready_mon_out, ctrl_state_mon_out;
    endclocking
    clocking blk_cb @(negedge blk_clk);
        output blk_reset_mon_in, blk_enable_mon_in, blk_ready_mon_in;
        output blk_state_mon_in;
        input blk_reset_out, blk_enable_out;
    endclocking

    //===================================
    // Bounded checks for stable cross-domain values
    //===================================
    task automatic check_control(input bit reset, input bit enable);
        bit matched = 0;
        ctrl_cb.ctrl_reset_in <= reset;
        ctrl_cb.ctrl_enable_in <= enable;
        repeat (64) begin
            @(blk_cb);
            if (blk_cb.blk_reset_out === reset && blk_cb.blk_enable_out === enable) begin
                matched = 1;
                break;
            end
        end
        `FAIL_UNLESS_LOG(matched, "Control levels did not cross to the block domain");
        // Keep the source stable until the synchronizer acknowledgement returns.
        repeat (16) @(ctrl_cb);
    endtask

    task automatic check_monitor(input bit reset, input bit enable,
                                 input bit ready, input bit [7:0] state);
        bit matched = 0;
        blk_cb.blk_reset_mon_in <= reset;
        blk_cb.blk_enable_mon_in <= enable;
        blk_cb.blk_ready_mon_in <= ready;
        blk_cb.blk_state_mon_in <= state;
        repeat (64) begin
            @(ctrl_cb);
            if (ctrl_cb.ctrl_reset_mon_out === reset && ctrl_cb.ctrl_enable_mon_out === enable
                && ctrl_cb.ctrl_ready_mon_out === ready && ctrl_cb.ctrl_state_mon_out === state) begin
                matched = 1;
                break;
            end
        end
        `FAIL_UNLESS_LOG(matched, "Monitor values did not cross to the control domain");
        repeat (16) @(blk_cb);
    endtask

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction
    task setup();
        svunit_ut.setup();
        @(ctrl_cb);
        check_control(0, 0);
        @(blk_cb);
        check_monitor(0, 0, 0, 0);
    endtask
    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN
        `SVTEST(control_levels)
            check_control(1, 0);
            check_control(1, 1);
            check_control(0, 1);
            check_control(0, 0);
        `SVTEST_END
        `SVTEST(status_and_state)
            check_monitor(1, 0, 0, 8'hA5);
            check_monitor(0, 1, 1, 8'h5A);
            check_monitor(0, 0, 1, 8'hFF);
            check_monitor(0, 0, 0, 0);
        `SVTEST_END
        `SVTEST(stable_random_values)
            repeat (16) begin
                check_control(1'($urandom), 1'($urandom));
                check_monitor(1'($urandom), 1'($urandom), 1'($urandom), 8'($urandom));
            end
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule : std_block_cdc_unit_test
