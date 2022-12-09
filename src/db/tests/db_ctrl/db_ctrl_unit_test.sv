`include "svunit_defines.svh"

module db_ctrl_unit_test
#(
    parameter type KEY_T = logic[11:0],
    parameter type VALUE_T = logic[31:0],
    parameter string DUT_NAME = "db_ctrl_intf"
) (
    output logic clk,
    output logic srst,
    db_ctrl_intf.controller db_ctrl_if_to_DUT,
    db_ctrl_intf.peripheral db_ctrl_if_from_DUT
);
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import db_verif_pkg::*;

    string name = {DUT_NAME, "_ut"};
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int TIMEOUT_CYCLES = 0;
    localparam int SIZE = 2**$bits(KEY_T);
   
    //===================================
    // Testbench
    //===================================
    // Agent
    db_ctrl_agent #(KEY_T, VALUE_T) agent;

    // Reset
    std_reset_intf reset_if (.clk(clk));

    // DB peripheral (peripheral + storage)
    // (in absence of verification model just implement
    //  using basic peripheral with array storage)

    logic init;
    logic init_done;

    db_intf #(KEY_T, VALUE_T) db_wr_if (.clk(clk));
    db_intf #(KEY_T, VALUE_T) db_rd_if (.clk(clk));

    // Peripheral
    db_peripheral #(
        .TIMEOUT_CYCLES ( TIMEOUT_CYCLES )
    ) i_db_peripheral (
        .clk       ( clk ),
        .srst      ( srst ),
        .ctrl_if   ( db_ctrl_if_from_DUT ),
        .init      ( init ),
        .init_done ( init_done ),
        .wr_if     ( db_wr_if ),
        .rd_if     ( db_rd_if )
    );

    // Database store
    db_store_array #(
        .KEY_T     ( KEY_T ),
        .VALUE_T   ( VALUE_T )
    ) i_db_store_array (
        .clk       ( clk ),
        .srst      ( srst ),
        .init      ( init ),
        .init_done ( init_done ),
        .db_wr_if  ( db_wr_if ),
        .db_rd_if  ( db_rd_if )
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
        agent.ctrl_vif = db_ctrl_if_to_DUT;
        agent.set_op_timeout(64);
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
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
    
    `SVTEST(reset)
    `SVTEST_END

    `SVTEST(ctrl_reset)
        bit error, timeout;
        agent.clear_all(error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(set_get)
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        agent.set(key, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Read back and check
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVTEST(unset)
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        agent.set(key, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Clear entry (and check previous value)
        agent.unset(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Read back and check that entry is cleared
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, 0);

    `SVTEST_END

    `SVTEST(replace)
        KEY_T key;
        VALUE_T exp_value [2];
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value[0]));
        void'(std::randomize(exp_value[1]));
        // Add entry
        agent.set(key, exp_value[0], error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Replace entry (and check previous value)
        agent.replace(key, exp_value[1], got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[0]);
        // Read back and check that entry is cleared
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[1]);

    `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : db_ctrl_unit_test

// DUT: db_ctrl_intf
module db_ctrl_intf_unit_test;

    localparam type KEY_T = logic[11:0];
    localparam type VALUE_T = logic[31:0];

    import svunit_pkg::svunit_testcase;
    svunit_testcase svunit_ut;

    logic clk;
    logic srst;
    db_ctrl_intf #(KEY_T, VALUE_T) DUT (.clk(clk));

    db_ctrl_unit_test #(
        .KEY_T    ( KEY_T ),
        .VALUE_T  ( VALUE_T ),
        .DUT_NAME ( "db_ctrl_intf" )
    ) test (
        .clk                 ( clk ),
        .srst                ( srst ),
        .db_ctrl_if_to_DUT   ( DUT ),
        .db_ctrl_if_from_DUT ( DUT )
    );

    function void build();
        test.build();
        svunit_ut = test.svunit_ut;
    endfunction
    task run();
        test.run();
    endtask

endmodule : db_ctrl_intf_unit_test

// DUT: db_ctrl_intf_connector
module db_ctrl_intf_connector_unit_test;

    localparam type KEY_T = logic[11:0];
    localparam type VALUE_T = logic[31:0];

    import svunit_pkg::svunit_testcase;
    svunit_testcase svunit_ut;

    logic clk;
    logic srst;
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_to_DUT (.clk(clk));
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_from_DUT (.clk(clk));

    db_ctrl_unit_test #(
        .KEY_T    ( KEY_T ),
        .VALUE_T  ( VALUE_T ),
        .DUT_NAME ( "db_ctrl_intf_connector" )
    ) test (.*);

    db_ctrl_intf_connector DUT (
        .ctrl_if_from_controller ( db_ctrl_if_to_DUT ),
        .ctrl_if_to_peripheral   ( db_ctrl_if_from_DUT )
    );

    function void build();
        test.build();
        svunit_ut = test.svunit_ut;
    endfunction
    task run();
        test.run();
    endtask

endmodule : db_ctrl_intf_connector_unit_test
