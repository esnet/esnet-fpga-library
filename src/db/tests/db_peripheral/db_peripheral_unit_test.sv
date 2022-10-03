`include "svunit_defines.svh"

module db_peripheral_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import db_verif_pkg::*;

    string name = "db_peripheral_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int SIZE = 8;
    parameter int TIMEOUT_CYCLES = 0;
    
    //===================================
    // Typedefs
    //===================================
    typedef logic [5:0]  key_t;
    typedef logic [31:0] value_t;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    db_ctrl_intf #(.KEY_T(key_t), .VALUE_T(value_t)) ctrl_if (.clk(clk));

    db_intf #(.KEY_T(key_t), .VALUE_T(value_t)) wr_if (.clk(clk));
    db_intf #(.KEY_T(key_t), .VALUE_T(value_t)) rd_if (.clk(clk));
    
    logic init;
    logic init_done;

    db_peripheral #(
        .TIMEOUT_CYCLES ( TIMEOUT_CYCLES )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    db_ctrl_agent #(.KEY_T(key_t), .VALUE_T(value_t)) agent;
    std_reset_intf reset_if (.clk(clk));

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    always_ff @(posedge clk) init_done <= ~srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        agent = new("db_agent", SIZE);
        agent.ctrl_vif = ctrl_if;
 
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        
        agent.idle();

        reset_if.pulse(8);
    
    endtask


    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
      svunit_ut.teardown();
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
    
    `SVTEST(compile)
    `SVTEST_END

    `SVTEST(reset)
        bit error, timeout;
        agent.clear_all(error, timeout);
        `FAIL_UNLESS(error === 1'b0);
        `FAIL_UNLESS(timeout === 1'b0);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
