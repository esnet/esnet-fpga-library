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

        evt_in = 1'b0;

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
    `SVUNIT_TESTS_BEGIN

        `SVTEST(rst_in_value)
            rst_in = 1'b1;
            evt_in = 1'b1;
            fork
                begin
                    wait_for_sync();
                end
                begin
                    forever begin
                        // No events should be forwarded, due to input reset assertion
                        @(posedge clk_out);
                        `FAIL_IF(evt_out);
                    end
                end
            join_any
        `SVTEST_END

        `SVTEST(rst_out_value)
            rst_out = 1'b1;
            evt_in = 1'b1;
            fork
                begin
                    wait_for_sync();
                end
                begin
                    forever begin
                        // No events should be forwarded, due to output reset assertion
                        @(posedge clk_out);
                        `FAIL_IF(evt_out);
                    end
                end
            join_any
        `SVTEST_END

        `SVTEST(pass_event)

            @(posedge clk_in);
            evt_in = 1'b1;
            @(posedge clk_in);
            evt_in = 1'b0;

            fork
                begin
                    wait_for_sync();
                    @(posedge clk_out);
                    `FAIL_IF(1);
                end
                begin
                    wait(evt_out);
                end
            join_any

        `SVTEST_END

        `SVTEST(backpressure)
            int exp_evt_cnt = 0;
            int got_evt_cnt = 0;

            fork
                begin
                    @(posedge clk_in);
                    evt_in <= 1'b1;
                    repeat (10000) begin
                        @(posedge clk_in);
                        if (rdy_in) exp_evt_cnt++;
                    end
                    evt_in <= 1'b0;
                    wait_for_sync();
                    @(posedge clk_out);
                end
                begin
                    forever begin
                        @(posedge clk_out);
                        if (evt_out) got_evt_cnt++;
                    end
                end
            join_any

            `FAIL_UNLESS_EQUAL(got_evt_cnt, exp_evt_cnt);

        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        fork
            begin
                rst_in <= 1'b1;
                repeat (8) @(posedge clk_in);
                rst_in <= 1'b0;
                @(posedge clk_in);
            end
            begin
                rst_out <= 1'b1;
                repeat (8) @(posedge clk_out);
                rst_out <= 1'b0;
                @(posedge clk_out);
            end
        join
    endtask

    task wait_for_sync();
        @(posedge clk_in);
        @(posedge clk_in);
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_out);
        @(posedge clk_out);
    endtask

endmodule
