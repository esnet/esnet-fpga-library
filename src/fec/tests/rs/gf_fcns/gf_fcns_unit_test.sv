`include "svunit_defines.svh"

module gf_fcns_unit_test;
    import svunit_pkg::svunit_testcase;
    import fec_pkg::*;

    string name = "gf_fcns_ut";
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

    logic [SYM_SIZE-1:0] a, b, y, z;

    enum {MUL, DIV, ADD} dut_sel;

    always_comb begin
        case (dut_sel)
            MUL: begin y = GF_MUL_LUT[a][b]; z = gf_mul(a, b); end
            DIV: begin y = GF_DIV_LUT[a][b]; z = gf_div(a, b); end
            ADD: begin y = GF_ADD_LUT[a][b]; z = gf_add(a, b); end
        endcase
    end

    task gf_fcn_test();
        for (int i=0; i<GF_ORDER; i++) begin
            for (int j=0; j<GF_ORDER; j++) begin
                a = i; b = j;

                #1ns //$display("%d  %d  %d  %d", a, b, y, z);
                `FAIL_UNLESS_EQUAL( y, z );
            end
        end

    endtask


    `SVUNIT_TESTS_BEGIN

        `SVTEST(gf_mul_test)
            dut_sel = MUL; gf_fcn_test();
        `SVTEST_END

        `SVTEST(gf_div_test)
            dut_sel = DIV; gf_fcn_test();
        `SVTEST_END

        `SVTEST(gf_add_test)
            dut_sel = ADD; gf_fcn_test();
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
