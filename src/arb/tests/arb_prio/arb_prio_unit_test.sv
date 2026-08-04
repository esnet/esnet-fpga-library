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
    integer sel;

    arb_prio #(
        .N ( N )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    `SVUNIT_CLK_GEN(clk, 5ns);

    default clocking cb @(posedge clk);
        default input #1step output #1;
        output srst, en, req, ack;
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

        cb.en  <= 1'b1;
        cb.req <= '0;
        cb.ack <= '0;

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
            cb.req[IF] <= 1'b1;
            wait(grant[IF]);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
        `SVTEST_END

        `SVTEST(no_hold)
            int IF = $urandom % N;
            cb.req[IF] <= 1'b1;
            cb.ack[IF] <= 1'b1;
            wait(grant[IF]);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            ##1;
            cb.req[IF] <= 1'b0;
            ##1;
            `FAIL_UNLESS_EQUAL(grant, 0);
        `SVTEST_END

        `SVTEST(hold)
            int IF = $urandom % N;
            cb.req[IF] <= 1'b1;
            wait(grant[IF]);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            ##1;
            cb.req[IF] <= 1'b0;
            ##1;
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            ##1;
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
            cb.ack[IF] <= 1'b1;
            ##2;
            `FAIL_UNLESS_EQUAL(grant, 0);
        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        cb.srst <= 1'b1;
        ##8;
        cb.srst <= 1'b0;
    endtask

endmodule
