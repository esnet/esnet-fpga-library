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

    default clocking cb @(posedge clk);
        output srst, en, req, ack;
        input grant, sel;
    endclocking

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

        cb.en <= 1'b1;
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
            IF = $urandom % N;
            cb.req[IF] <= 1'b1;
            wait_for_grant();
        `SVTEST_END

        `SVTEST(no_hold)
            repeat (10) begin
              IF = $urandom % N;
              cb.req[IF] <= 1'b1;
              cb.ack[IF] <= 1'b1;
              check_grant_no_hold();
            end
        `SVTEST_END

        `SVTEST(hold)
            repeat (10) begin
              IF = $urandom % N;
              cb.req[IF] <= 1'b1;
              check_grant_hold();
            end
        `SVTEST_END

        `SVTEST(concurrent_requests_hold)
            logic [N-1:0] pending;
            IF = 1;
            repeat (10) begin
              pending = $urandom;
              cb.req <= pending;
              while (pending != '0) begin
                 if (pending[IF]) begin
                    check_grant_hold();
                    pending[IF] = 1'b0;
                 end
                 IF = (IF + 1) % N;
              end
            end
        `SVTEST_END

        `SVTEST(concurrent_requests_no_hold)
            logic [N-1:0] pending;
            IF = 1;
            repeat (10) begin
              pending = $urandom;
              cb.req <= pending;
              cb.ack <= '1;
              while (pending != '0) begin
                 if (pending[IF]) begin
                    check_grant_no_hold();
                    pending[IF] = 1'b0;
                 end
                 IF = (IF + 1) % N;
              end
            end
        `SVTEST_END

        `SVTEST(persistent_requests_no_hold)
            IF = 1;
            cb.req <= '1;
            cb.ack <= '1;
            // Wait for the first sampled transfer after reset.
            while (cb.grant == '0) @(cb);

            repeat (10) begin
               for (int i = 0; i < N; i++) begin
                  `FAIL_UNLESS_EQUAL(cb.grant, 1 << IF);
                  `FAIL_UNLESS_EQUAL(cb.sel, IF);
                  @(cb);
                  `FAIL_UNLESS_EQUAL(cb.grant[IF], 0);
                  IF = (IF + 1) % N;
               end
            end
        `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task reset();
        cb.srst <= 1'b1;
        repeat (8) @(cb);
        cb.srst <= 1'b0;
    endtask

    task wait_for_grant();
       // Reuse a grant sampled on this edge, allowing back-to-back clients.
       // Otherwise wait until the requested client is selected.
       while (!cb.grant[IF]) @(cb);
       `FAIL_UNLESS_EQUAL(cb.grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(cb.sel, IF);
    endtask

    task check_grant_no_hold();
       wait_for_grant();
       cb.req[IF] <= 1'b0;
       @(cb);
       `FAIL_UNLESS_EQUAL(cb.grant[IF], 0);
    endtask

    task check_grant_hold();
       wait_for_grant();
       cb.req[IF] <= 1'b0;
       @(cb);
       `FAIL_UNLESS_EQUAL(cb.grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(cb.sel, IF);
       @(cb);
       cb.ack[IF] <= 1'b1;
       @(cb);
       // The held grant is still present on the acknowledgement edge.
       `FAIL_UNLESS_EQUAL(cb.grant, 1 << IF);
       `FAIL_UNLESS_EQUAL(cb.sel, IF);
       @(cb);
       `FAIL_UNLESS_EQUAL(cb.grant[IF], 0);
       cb.ack[IF] <= 1'b0;
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
  function void __register_tests();\
    test.__register_tests();\
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
