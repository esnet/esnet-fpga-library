`include "svunit_defines.svh"

module sync_level_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_level_ut";
    svunit_testcase svunit_ut;

    localparam RST_VALUE = 1'b0;

    //===================================
    // DUT
    //===================================
    logic clk_in;
    logic rst_in;
    logic lvl_in;
    logic rdy_in;

    logic clk_out;
    logic rst_out;
    logic lvl_out;

    sync_level #(
        .RST_VALUE ( RST_VALUE )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    time clk_in_period = $urandom_range(3,12)*1ns;
    time clk_out_period = $urandom_range(3,12)*1ns;

    `SVUNIT_CLK_GEN(clk_in, clk_in_period);
    `SVUNIT_CLK_GEN(clk_out, clk_out_period);

    wire mon_lvl_in = lvl_in;

    clocking cb_in @(posedge clk_in);
        output rst_in, lvl_in;
        input rdy_in, mon_lvl_in;
    endclocking

    clocking cb_out @(posedge clk_out);
        output rst_out;
        input lvl_out;
    endclocking

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        cb_in.lvl_in <= RST_VALUE;

        reset();

    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();

    endtask


    //===================================
    // All tests are defined between the
    // SVUNIT_TESTS_BEGIN/END macros
    //
    // Each individual test must be
    // defined between `SVTEST(_NAME_)
    // `SVTEST_END
    //
    // i.e.
    //   `SVTEST(mytest)
    //     <test code>
    //   `SVTEST_END
    //===================================
    // Isolate each worker fork so cleanup cannot affect other test processes.
    // Check results after cleanup, including failure paths.
    `SVUNIT_TESTS_BEGIN

        `SVTEST(rst_in_value)
            bit unexpected_output = 0;
            cb_in.rst_in <= 1'b1;
            cb_in.lvl_in <= 1'b1;
            fork begin
                fork
                    begin
                        wait_for_sync();
                    end
                    begin
                        forever begin
                            @(cb_out);
                            unexpected_output |= (cb_out.lvl_out !== RST_VALUE);
                        end
                    end
                join_any
                disable fork;
            end join
            `FAIL_IF(unexpected_output);
        `SVTEST_END

        `SVTEST(rst_out_value)
            bit unexpected_output = 0;
            cb_out.rst_out <= 1'b1;
            cb_in.lvl_in <= 1'b1;
            fork begin
                fork
                    begin
                        wait_for_sync();
                    end
                    begin
                        forever begin
                            @(cb_out);
                            unexpected_output |= (cb_out.lvl_out !== RST_VALUE);
                        end
                    end
                join_any
                disable fork;
            end join
            `FAIL_IF(unexpected_output);
        `SVTEST_END

        `SVTEST(pass_0)
            @(cb_in);
            cb_in.lvl_in <= 1'b0;
            wait_for_handshake();
            `FAIL_UNLESS_EQUAL(cb_out.lvl_out, 1'b0);
        `SVTEST_END

        `SVTEST(pass_1)
            @(cb_in);
            cb_in.lvl_in <= 1'b1;
            wait_for_handshake();
            `FAIL_UNLESS_EQUAL(cb_out.lvl_out, 1'b1);
        `SVTEST_END

        `SVTEST(backpressure)
            int exp_evt_cnt = 0;
            int got_evt_cnt = 0;
            logic _lvl_in;
            logic _lvl_out;

            fork begin
                fork
                    begin
                        cb_in.lvl_in <= 1'b0;
                        _lvl_in = 1'b0;
                        wait_for_handshake();
                        repeat (10000) begin
                            cb_in.lvl_in <= !cb_in.mon_lvl_in;
                            @(cb_in);
                            if (cb_in.rdy_in) begin
                                if (cb_in.mon_lvl_in !== _lvl_in) exp_evt_cnt++; // Count expected number of input transitions
                                _lvl_in = cb_in.mon_lvl_in;
                            end
                        end
                        cb_in.lvl_in <= _lvl_in;
                        wait_for_sync();
                        @(cb_out);
                    end
                    begin
                        wait_for_sync();
                        _lvl_out = cb_out.lvl_out;
                        forever begin
                            @(cb_out);
                            if (cb_out.lvl_out !== _lvl_out ) got_evt_cnt++; // Count actual number of output transitions
                            _lvl_out = cb_out.lvl_out;
                        end
                    end
                join_any
                disable fork;
            end join
            `FAIL_UNLESS_LOG(got_evt_cnt == exp_evt_cnt,
                $sformatf("Transition count mismatch. Exp: %0d, Got: %0d.",
                          exp_evt_cnt, got_evt_cnt));

        `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task reset();
        fork
            begin
                cb_in.rst_in <= 1'b1;
                repeat (8) @(cb_in);
                cb_in.rst_in <= 1'b0;
                @(cb_in);
            end
            begin
                cb_out.rst_out <= 1'b1;
                repeat (8) @(cb_out);
                cb_out.rst_out <= 1'b0;
                @(cb_out);
            end
        join
    endtask

    task wait_for_sync();
        @(cb_in);
        @(cb_in);
        repeat (sync_pkg::RETIMING_STAGES+1) @(cb_out);
        @(cb_out);
        @(cb_out);
    endtask

    task wait_for_ack();
        @(cb_out);
        repeat (sync_pkg::RETIMING_STAGES+1) @(cb_in);
        @(cb_in);
        @(cb_in);
    endtask

    task wait_for_handshake();
        wait_for_sync();
        wait_for_ack();
    endtask

endmodule
