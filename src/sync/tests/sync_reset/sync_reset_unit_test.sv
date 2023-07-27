`include "svunit_defines.svh"

module sync_reset_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_reset_ut";
    svunit_testcase svunit_ut;

    //===================================
    // DUTs (multiple parameterizations)
    //===================================
    logic clk_in;
    logic rst_in;
    logic clk_out;

    // Standard config (active-low input, active-high output)
    logic rst_out;
    sync_reset #(
    ) DUT (
        .*
    );

    // Active-low input, active-low output
    logic rstn_out;
    sync_reset #(
        .OUTPUT_ACTIVE_LOW ( 1 )
    ) DUT__act_low_output (
        .rst_out ( rstn_out ),
        .*
    );

    // Active-high input, active-high output
    logic rst_out__act_high_input;
    sync_reset #(
        .INPUT_ACTIVE_HIGH ( 1 )
    ) DUT__act_high_input (
        .rst_out ( rst_out__act_high_input ),
        .*
    );

    // Active-high input, active-low output
    logic rstn_out__act_high_input;
    sync_reset #(
        .INPUT_ACTIVE_HIGH ( 1 ),
        .OUTPUT_ACTIVE_LOW ( 1 )
    ) DUT__act_high_input__act_low_output (
        .rst_out ( rstn_out__act_high_input ),
        .*
    );

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

        `SVTEST(reset)
            @(posedge clk_in) rst_in <= 1'b1;
            #1;
            // rst_in == 1 is asserted for active-high input
            // (assertion happens immediately)
            `FAIL_UNLESS_EQUAL(rst_out__act_high_input, 1'b1);
            `FAIL_UNLESS_EQUAL(rstn_out__act_high_input, 1'b0);
            // rst_in == 1 is deasserted for active-low input
            // (deassertion happens after sync and synchronously to clk_out)
            wait_for_sync();
            `FAIL_UNLESS_EQUAL(rst_out, 1'b0);
            `FAIL_UNLESS_EQUAL(rstn_out, 1'b1);

            @(posedge clk_in) rst_in <= 1'b0;
            #1;
            // rst_in == 0 is asserted for active-low input
            // (assertion happens immediately)
            `FAIL_UNLESS_EQUAL(rst_out, 1'b1);
            `FAIL_UNLESS_EQUAL(rstn_out, 1'b0);
            // rst_in == 0 is deasserted for active-high input
            // (deassertion happens after sync and synchronously to clk_out)
            `FAIL_UNLESS_EQUAL(rst_out__act_high_input, 1'b1);
            `FAIL_UNLESS_EQUAL(rstn_out__act_high_input, 1'b0);
            wait_for_sync();
            `FAIL_UNLESS_EQUAL(rst_out__act_high_input, 1'b0);
            `FAIL_UNLESS_EQUAL(rstn_out__act_high_input, 1'b1);
            
            @(posedge clk_in) rst_in <= 1'b1;
            #1;
            // rst_in == 1 is asserted for active-high input
            // (assertion happens immediately)
            `FAIL_UNLESS_EQUAL(rst_out__act_high_input, 1'b1);
            `FAIL_UNLESS_EQUAL(rstn_out__act_high_input, 1'b0);
            // rst_in == 1 is deasserted for active-low input
            // (deassertion happens after sync and synchronously to clk_out)
            `FAIL_UNLESS_EQUAL(rst_out, 1'b1);
            `FAIL_UNLESS_EQUAL(rstn_out, 1'b0);
            wait_for_sync();
            `FAIL_UNLESS_EQUAL(rst_out, 1'b0);
            `FAIL_UNLESS_EQUAL(rstn_out, 1'b1);
        `SVTEST_END

    `SVUNIT_TESTS_END

    task wait_for_sync();
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
    endtask

endmodule
