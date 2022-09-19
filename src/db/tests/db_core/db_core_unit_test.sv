`include "svunit_defines.svh"

module db_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import db_verif_pkg::*;

    string name = "db_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int SIZE = 4096;
    parameter int KEY_WID = $clog2(SIZE);
    parameter int VALUE_WID = 32;
    parameter int TIMEOUT_CYCLES = 0;
    
    //===================================
    // Typedefs
    //===================================
    parameter type KEY_T = logic [KEY_WID-1:0];
    parameter type VALUE_T = logic [VALUE_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if (.clk(clk));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) app_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) app_rd_if (.clk(clk));
    
    logic db_init;
    logic db_init_done;

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_rd_if (.clk(clk));
    
    db_core #(
        .KEY_T (KEY_T),
        .VALUE_T (VALUE_T)
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Database store
    db_store_array #(
        .KEY_T ( KEY_T ),
        .VALUE_T ( VALUE_T )
    ) i_db_store_array (
        .init ( db_init ),
        .init_done ( db_init_done ),
        .*
    );
    
    db_ctrl_agent #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) agent;
    std_reset_intf reset_if (.clk(clk));

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
 
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        
        agent.idle();
        app_wr_if.idle();
        app_rd_if.idle();

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
 
    `SVTEST(set_query)
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
        // Query database from app interface
        app_rd_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END
 
    `SVTEST(update_query)
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
        app_wr_if.update(key, 1'b1, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Query database from app interface
        app_rd_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END
 
    `SVTEST(burst_update)
        localparam int BURST_CNT = 8;
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit exp_valid;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key
        void'(std::randomize(key));
        for (int i = 0; i < BURST_CNT; i++) begin
            // Add new random entry (same key)
            void'(std::randomize(exp_valid));
            void'(std::randomize(exp_value));
            app_wr_if.post_update(key, exp_valid, exp_value, timeout);
            `FAIL_IF(timeout);
        end
        // Query database and check that most recently written value is returned
        app_rd_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END


    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule
