`include "svunit_defines.svh"
import arb_pkg::*;

module arb_rr_unit_test #(parameter arb_rr_mode_t MODE = RR);
    import svunit_pkg::svunit_testcase;

    localparam string mode_string = MODE == RR ? "RR_mode" :
                                    MODE == WCRR ? "WCRR_mode" : "undefined";

    string name = $sformatf("arb_rr__%s__ut", mode_string);
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
    logic [$clog2(N)-1:0] sel;

    arb_rr #(
        .MODE ( MODE ),
        .N    ( N )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    `SVUNIT_CLK_GEN(clk, 5ns);

    int IF;

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
            IF = $urandom % N;
            req[IF] = 1'b1;
            #1 while (!grant[IF]) @(negedge clk);
            `FAIL_UNLESS_EQUAL(grant, 1 << IF);
            `FAIL_UNLESS_EQUAL(sel, IF);
        `SVTEST_END

        `SVTEST(no_hold)
            repeat (10) begin
              IF = $urandom % N;
              req[IF] = 1'b1;
              ack[IF] = 1'b1;
              check_grant_no_hold();
            end
        `SVTEST_END

        `SVTEST(hold)
            repeat (10) begin
              IF = $urandom % N;
              req[IF] = 1'b1;
              check_grant_hold();
            end
        `SVTEST_END

        `SVTEST(concurrent_requests_hold)
            IF = 1;
            repeat (10) begin
              req = $urandom;
              while (req != '0) begin
                 if (req[IF] == 1'b1) check_grant_hold();
                 IF = (IF + 1) % N;
              end
            end
        `SVTEST_END

        `SVTEST(concurrent_requests_no_hold)
            IF = 1;
            repeat (10) begin
              req = $urandom;
              ack = '1;
              while (req != '0) begin
                 if (req[IF] == 1'b1) check_grant_no_hold();
                 IF = (IF + 1) % N;
              end
            end
        `SVTEST_END

        `SVTEST(persistent_requests_no_hold)
            IF = 1;
            req = '1;
            ack = '1;
            @(posedge clk); // wait for 'state' transition from RESET -> GRANT.

            repeat (10) begin
               for (int i = 0; i < N; i++) begin
                  #1;
                  `FAIL_UNLESS_EQUAL(grant, 1 << IF);
                  `FAIL_UNLESS_EQUAL(sel, IF);
                  @(posedge clk);
                  #1;
                  `FAIL_UNLESS_EQUAL(grant[IF], 0);
                  IF = (IF + 1) % N;
               end
            end
        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        srst <= 1'b1;
        repeat (8) @(posedge clk);
        srst <= 1'b0;
    endtask

    task check_grant_no_hold();
       #1 while (!grant[IF]) @(negedge clk);
       `FAIL_UNLESS_EQUAL(grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(sel, IF);
       @(posedge clk);
       req[IF] = 1'b0;
       #1;
       `FAIL_UNLESS_EQUAL(grant[IF], 0);
    endtask

    task check_grant_hold();
       #1 while (!grant[IF]) @(negedge clk);
       `FAIL_UNLESS_EQUAL(grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(sel, IF);
       @(posedge clk);
       req[IF] = 1'b0;
       #1;
       `FAIL_UNLESS_EQUAL(grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(sel, IF);
       @(posedge clk);
       ack[IF] = 1'b1;
       #1;
       `FAIL_UNLESS_EQUAL(grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(sel, IF);
       @(posedge clk);
       #1;
       `FAIL_UNLESS_EQUAL(grant[IF], 0);
       ack[IF] = 1'b0;
    endtask

endmodule


// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific arb_rr MODE in a way
//  that maintains SVUnit compatibility
`define ARB_RR_UNIT_TEST(MODE)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  arb_rr_unit_test #(MODE) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask


module rr_mode_unit_test;
`ARB_RR_UNIT_TEST(RR)
endmodule

module wcrr_mode_unit_test;
`ARB_RR_UNIT_TEST(WCRR)
endmodule
