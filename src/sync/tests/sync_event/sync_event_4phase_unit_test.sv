`include "svunit_defines.svh"

module sync_event_4phase_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_event_4phase_ut";
    svunit_testcase svunit_ut;

    localparam RST_VALUE = 1'bx;
    localparam sync_pkg::handshake_mode_t MODE = sync_pkg::HANDSHAKE_MODE_4PHASE;

    //===================================
    // DUT
    //===================================
    logic clk_in;
    logic rst_in;
    logic rdy_in;
    logic evt_in;

    logic clk_out;
    logic rst_out;
    logic evt_out;

    sync_event #(
        .MODE   ( sync_pkg::HANDSHAKE_MODE_4PHASE )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    time clk_in_period = $urandom_range(3,12)*1ns;
    time clk_out_period = $urandom_range(3,12)*1ns;

    `SVUNIT_CLK_GEN(clk_in, clk_in_period);
    `SVUNIT_CLK_GEN(clk_out, clk_out_period);

    clocking cb_in @(posedge clk_in);
        output rst_in, evt_in;
        input rdy_in;
    endclocking

    clocking cb_out @(posedge clk_out);
        output rst_out;
        input evt_out;
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

        cb_in.evt_in <= 1'b0;

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
            cb_in.evt_in <= 1'b1;
            fork begin
                fork
                    begin
                        wait_for_sync();
                    end
                    begin
                        forever begin
                            // No events should be forwarded, due to input reset assertion
                            @(cb_out);
                            unexpected_output |= cb_out.evt_out;
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
            cb_in.evt_in <= 1'b1;
            fork begin
                fork
                    begin
                        wait_for_sync();
                    end
                    begin
                        forever begin
                            // No events should be forwarded, due to output reset assertion
                            @(cb_out);
                            unexpected_output |= cb_out.evt_out;
                        end
                    end
                join_any
                disable fork;
            end join
            `FAIL_IF(unexpected_output);
        `SVTEST_END

        `SVTEST(pass_event)
            bit received = 0;

            @(cb_in);
            cb_in.evt_in <= 1'b1;
            @(cb_in);
            cb_in.evt_in <= 1'b0;

            fork begin
                fork
                    begin
                        wait_for_sync();
                        @(cb_out);
                    end
                    begin
                        @(cb_out iff cb_out.evt_out);
                        received = 1;
                    end
                join_any
                disable fork;
            end join
            `FAIL_UNLESS(received);

        `SVTEST_END

        `SVTEST(backpressure)
            int exp_evt_cnt = 0;
            int got_evt_cnt = 0;

            fork begin
                fork
                    begin
                        @(cb_in);
                        cb_in.evt_in <= 1'b1;
                        repeat (10000) begin
                            @(cb_in);
                            if (cb_in.rdy_in) exp_evt_cnt++;
                        end
                        cb_in.evt_in <= 1'b0;
                        wait_for_sync();
                        @(cb_out);
                    end
                    begin
                        forever begin
                            @(cb_out);
                            if (cb_out.evt_out) got_evt_cnt++;
                        end
                    end
                join_any
                disable fork;
            end join

            `FAIL_UNLESS_EQUAL(got_evt_cnt, exp_evt_cnt);

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
    endtask

endmodule
