`include "svunit_defines.svh"

module math_unit_test;
    import svunit_pkg::svunit_testcase;
    import math_pkg::*;

    string name = "math_ut";
    svunit_testcase svunit_ut;

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
      /* Place Setup Code Here */

    endtask


    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
      svunit_ut.teardown();
      /* Place Teardown Code Here */

    endtask


    //===================================
    // Tests
    //===================================

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

    `SVTEST(min)
        localparam int CONST_PARAM = MIN(8, 4);
        int B = $urandom_range(2, 1000);
        int A = $urandom_range(1, B);
        // Param check
        `FAIL_UNLESS_EQUAL(
            CONST_PARAM, 4
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            MIN(A, B), A
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            MIN(B, A), A
        );
        // -/+
        `FAIL_UNLESS_EQUAL(
            MIN(-A, B), -A
        );
        // +/-
        `FAIL_UNLESS_EQUAL(
            MIN(A, -B), -B 
        );
        // -/-
        `FAIL_UNLESS_EQUAL(
            MIN(-A, -B), -B
        );
        // +/0
        `FAIL_UNLESS_EQUAL(
            MIN(A, 0), 0
        );
        // -/0
        `FAIL_UNLESS_EQUAL(
            MIN(-A, 0), -A
        );
    `SVTEST_END

    `SVTEST(max)
        localparam int CONST_PARAM = MAX(8, 4);
        int B = $urandom_range(2, 1000);
        int A = $urandom_range(1, B);
        // Param check
        `FAIL_UNLESS_EQUAL(
            CONST_PARAM, 8
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            MAX(A, B), B
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            MAX(B, A), B
        );
        // -/+
        `FAIL_UNLESS_EQUAL(
            MAX(-A, B), B
        );
        // +/-
        `FAIL_UNLESS_EQUAL(
            MAX(A, -B), A
        );
        // -/-
        `FAIL_UNLESS_EQUAL(
            MAX(-A, -B), -A
        );
        // +/0
        `FAIL_UNLESS_EQUAL(
            MAX(A, 0), A
        );
        // -/0
        `FAIL_UNLESS_EQUAL(
            MAX(-A, 0), 0
        );
    `SVTEST_END

    `SVTEST(abs)
        localparam int CONST_PARAM = ABS(-8);
        int A = $urandom_range(1, 1000);
        // Param check
        `FAIL_UNLESS_EQUAL(
            CONST_PARAM, 8
        );
        // +
        `FAIL_UNLESS_EQUAL(
            ABS(A), A
        );
        // -
        `FAIL_UNLESS_EQUAL(
            ABS(-A), A
        );
        // 0
        `FAIL_UNLESS_EQUAL(
            ABS(0), 0
        );
    `SVTEST_END

    `SVTEST(gcd)
        localparam int CONST_PARAM = GCD(8,4);
        // Param check
        `FAIL_UNLESS_EQUAL(
            CONST_PARAM, 4
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            GCD(60, 24), 12
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            GCD(24, 60), 12
        );
        // +/-
        `FAIL_UNLESS_EQUAL(
            GCD(-72, 27), 9
        );
        // -/-
        `FAIL_UNLESS_EQUAL(
            GCD(-72, -27), 9
        );
        // +/0
        `FAIL_UNLESS_EQUAL(
            GCD(99, 0), 99
        );
    `SVTEST_END

    `SVTEST(lcm)
        localparam int CONST_PARAM = LCM(8,4);
        // Param check
        `FAIL_UNLESS_EQUAL(
            CONST_PARAM, 8
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            LCM(60, 24), 120
        );
        // +/+
        `FAIL_UNLESS_EQUAL(
            LCM(24, 60), 120
        );
        // +/-
        `FAIL_UNLESS_EQUAL(
            LCM(-72, 27), -216
        );
        // -/+
        `FAIL_UNLESS_EQUAL(
            LCM(72, -27), -216
        );
        // -/-
        `FAIL_UNLESS_EQUAL(
            LCM(-72, -27), 216
        );
        // +/0
        `FAIL_UNLESS_EQUAL(
            LCM(99, 0), 0
        );
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
