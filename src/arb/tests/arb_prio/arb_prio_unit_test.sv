`include "svunit_defines.svh"

module arb_prio_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "arb_prio_ut";
    svunit_testcase svunit_ut;

    localparam int N = 4;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;
    logic en;
    logic [N-1:0] req;
    logic [N-1:0] grant;
    logic [N-1:0] ack;
    int sel;

    arb_prio #(
        .N ( N )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    `SVUNIT_CLK_GEN(clk, 5ns);

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

        en = 1'b1;

        req = '0;
        ack = '0;

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

        `SVTEST(_grant)
            int IF = $urandom % N;
            req[IF] = 1'b1;
            wait(grant[IF]);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
        `SVTEST_END

        `SVTEST(no_hold)
            int IF = $urandom % N;
            req[IF] = 1'b1;
            ack[IF] = 1'b1;
            wait(grant[IF]);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            @(posedge clk);
            req[IF] = 1'b0;
            @(negedge clk);
            `FAIL_UNLESS_EQUAL(grant, 0);
        `SVTEST_END

        `SVTEST(hold)
            int IF = $urandom % N;
            req[IF] = 1'b1;
            wait(grant[IF]);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            @(posedge clk);
            req[IF] = 1'b0;
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            @(posedge clk);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            ack[IF] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            `FAIL_UNLESS_EQUAL(grant, 0);
        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        srst <= 1'b1;
        repeat (8) @(posedge clk);
        srst <= 1'b0;
    endtask

endmodule
