`include "svunit_defines.svh"

module sync_level_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_level_ut";
    svunit_testcase svunit_ut;

    localparam RST_VALUE = 1'bx;

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

        lvl_in = RST_VALUE;

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
            lvl_in = 1'b1;
            fork
                begin
                    wait_for_sync();
                end
                begin
                    forever begin
                        @(posedge clk_out);
                        `FAIL_UNLESS_EQUAL(lvl_out, RST_VALUE);
                    end
                end
            join_any
        `SVTEST_END

        `SVTEST(rst_out_value)
            rst_out = 1'b1;
            lvl_in = 1'b1;
            fork
                begin
                    wait_for_sync();
                end
                begin
                    forever begin
                        @(posedge clk_out);
                        `FAIL_UNLESS_EQUAL(lvl_out, RST_VALUE);
                    end
                end
            join_any
        `SVTEST_END

        `SVTEST(pass_0)

            @(posedge clk_in);
            lvl_in = 1'b0;

            wait_for_handshake();

            fork
                begin
                    wait_for_sync();
                    @(posedge clk_out);
                    `FAIL_IF(1);
                end
                begin
                    wait(lvl_out == 1'b0);
                end
            join_any

        `SVTEST_END

        `SVTEST(pass_1)

            @(posedge clk_in);
            lvl_in = 1'b1;
            
            wait_for_handshake();

            fork
                begin
                    wait_for_sync();
                    @(posedge clk_out);
                    `FAIL_IF(1);
                end
                begin
                    wait(lvl_out == 1'b1);
                end
            join_any

        `SVTEST_END

        `SVTEST(backpressure)
            int exp_evt_cnt = 0;
            int got_evt_cnt = 0;
            logic _lvl_in;
            logic _lvl_out;

            fork
                begin
                    lvl_in <= 1'b0;
                    _lvl_in = 1'b0;
                    wait_for_handshake();
                    repeat (10000) begin
                        lvl_in <= !lvl_in;
                        @(posedge clk_in);
                        if (rdy_in) begin
                            if (lvl_in !== _lvl_in) begin
                                // Count expected number of input transitions
                                exp_evt_cnt++;
                                _lvl_in = lvl_in;
                            end
                        end
                    end
                    wait_for_sync();
                    @(posedge clk_out);
                end
                begin
                    wait_for_handshake();
                    _lvl_out = lvl_out;
                    forever begin
                        @(posedge clk_out);
                        if (lvl_out !== _lvl_out ) begin
                            // Count actual number of output transitions
                            got_evt_cnt++;
                        end
                        _lvl_out = lvl_out;
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
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_out);
        @(posedge clk_out);
    endtask

    task wait_for_ack();
        @(posedge clk_out);
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_out);
        @(posedge clk_out);
    endtask

    task wait_for_handshake();
        wait_for_sync();
        wait_for_ack();
    endtask

endmodule
