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
    parameter int KEY_WID = 16;
    parameter int VALUE_WID = 31;
    parameter int TIMEOUT_CYCLES = 100;

    parameter type_t DB_TYPE = DB_TYPE_UNSPECIFIED;
    parameter subtype_t DB_SUBTYPE = 'hDB;
    
    //===================================
    // Typedefs
    //===================================
    parameter type KEY_T = bit[KEY_WID-1:0];
    parameter type VALUE_T = bit[VALUE_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if (.clk(clk));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) rd_if (.clk(clk));
    
    logic init;
    logic init_done;

    db_peripheral #(
        .TIMEOUT_CYCLES ( TIMEOUT_CYCLES )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    db_ctrl_agent #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) agent;
    std_reset_intf reset_if (.clk(clk));

    db_info_intf #() info_if ();
    assign info_if._type = DB_TYPE;
    assign info_if.subtype = DB_SUBTYPE;
    assign info_if.size = SIZE;

    // Database store
    db_store_array #(
        .KEY_T ( KEY_T ),
        .VALUE_T ( VALUE_T ),
        .SIM__RAM_MODEL ( 1 )
    ) i_db_store_array (
        .db_wr_if ( wr_if ),
        .db_rd_if ( rd_if ),
        .*
    );

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        agent = new("db_agent", SIZE);
        agent.ctrl_vif = ctrl_if;
        agent.info_vif = info_if;
 
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        
        agent.idle();

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
    
    // Include common tests
    `include "../common/tests.svh"
    // Include control-specific tests
    `include "../common/ctrl_tests.svh"

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"
    // Import control-specific tasks
    `include "../common/ctrl_tasks.svh"

endmodule
