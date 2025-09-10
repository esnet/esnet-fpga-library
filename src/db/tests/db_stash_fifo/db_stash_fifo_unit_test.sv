`include "svunit_defines.svh"

module db_stash_fifo_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import db_verif_pkg::*;

    string name = "db_stash_fifo_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int SIZE = 16;
    parameter int KEY_WID = 96;
    parameter int VALUE_WID = 32;

    parameter type_t DB_TYPE = DB_TYPE_STASH;
    parameter subtype_t DB_SUBTYPE = DB_STASH_TYPE_FIFO;
    
    //===================================
    // Typedefs
    //===================================
    parameter type KEY_T = bit [KEY_WID-1:0];
    parameter type VALUE_T = bit [VALUE_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    db_info_intf #() info_if ();
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if (.clk);
    db_status_intf #() status_if (.clk, .srst);

    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) app_wr_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) app_rd_if (.clk);
    
    db_stash_fifo #(
        .SIZE (SIZE)
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    db_ctrl_agent #(KEY_T, VALUE_T) agent;
    std_reset_intf reset_if (.clk);

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
     
    // Include common tests
    `include "../common/tests.svh"
    // Include control-specific tests
    `include "../common/ctrl_tests.svh"
    // Include application-specific tests
    `include "../common/app_tests.svh"

    `SVTEST(set_get_next)
        KEY_T exp_key;
        KEY_T got_key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        // Randomize key/value
        void'(std::randomize(exp_key));
        void'(std::randomize(exp_value));
        // Add entry
        set(exp_key, exp_value);
        // Read back and check
        get(exp_key, got_valid, got_value);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Read from head of 'FIFO'
        get_next(got_valid, got_key, got_value);
        `FAIL_UNLESS(got_valid);    
        `FAIL_UNLESS_EQUAL(got_key, exp_key);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVTEST(set_pop)
        KEY_T exp_key;
        KEY_T got_key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(exp_key));
        void'(std::randomize(exp_value));
        // Add entry
        set(exp_key, exp_value);
        // Read back and check
        get(exp_key, got_valid, got_value);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Read from head of 'FIFO'
        unset_next(got_valid, got_key, got_value);
        `FAIL_UNLESS(got_valid);    
        `FAIL_UNLESS_EQUAL(got_key, exp_key);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Read from head of 'FIFO' (should be empty
        agent.get_next(got_valid, got_key, got_value, error, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(error);
    `SVTEST_END
 
    `SVTEST(set_to_full)
        KEY_T key [SIZE+1];
        KEY_T got_key;
        VALUE_T exp_value [SIZE+1];
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entries
        for (int i = 0; i < SIZE; i++) begin
            // Add new random entry
            set(key[i], exp_value[i]);
            `FAIL_UNLESS_EQUAL(status_if.fill, i+1);
        end
        // Read back and check
        for (int i = 0; i < SIZE; i++) begin
            get(key[i], got_valid, got_value);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value[i]);
        end
        // Add last entry (expect failure due to full)
        agent.set(key[SIZE], exp_value[SIZE], error, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(error);
        // Read (and dequeue) first entry
        unset_next(got_valid, got_key, got_value);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_key, key[0]);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[0]);
        // Check for not full
        `FAIL_UNLESS_EQUAL(status_if.fill, SIZE-1);
        // Try insertion again
        set(key[SIZE], exp_value[SIZE]);
        // Read back and check
        get(key[SIZE], got_valid, got_value);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[SIZE]);
        // Should be full again
        `FAIL_UNLESS_EQUAL(status_if.fill, SIZE);
        // Read (and dequeue) remaining entries
        for (int i = 1; i < SIZE+1; i++) begin
            unset_next(got_valid, got_key, got_value);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_key, key[i]);
            `FAIL_UNLESS_EQUAL(got_value, exp_value[i]);
        end
        // Should be empty now
        `FAIL_UNLESS_EQUAL(status_if.fill, 0);
        // Try to dequeue additional entry (should fail due to empty)
        agent.unset_next(got_valid, got_key, got_value, error, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(error);
        `FAIL_IF(got_valid);
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"
    // Import control-specific tasks
    `include "../common/ctrl_tasks.svh"
    // Import application tasks
    `include "../common/app_tasks.svh"

endmodule
