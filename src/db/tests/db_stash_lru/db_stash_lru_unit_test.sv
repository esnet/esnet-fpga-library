`include "svunit_defines.svh"

module db_stash_lru_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import db_verif_pkg::*;

    string name = "db_stash_lru_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int SIZE = 16;
    parameter int KEY_WID = 96;
    parameter int VALUE_WID = 32;
    
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

    db_info_intf #() info_if ();
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if (.clk(clk));
    db_status_intf #() status_if (.clk(clk), .srst(srst));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) app_wr_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) app_rd_if (.clk(clk));
    
    db_stash_lru #(
        .KEY_T (KEY_T),
        .VALUE_T (VALUE_T),
        .SIZE (SIZE)
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
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
    
    `SVTEST(reset)
    `SVTEST_END

    `SVTEST(ctrl_reset)
        bit error, timeout;
        agent.clear_all(error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(info)
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        int got_size;
        // Get info and check against expected
        agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_STASH);

        agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, db_pkg::DB_STASH_TYPE_LRU);

        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, SIZE);
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
            agent.set(key[i], exp_value[i], error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS_EQUAL(status_if.fill, i+1);
        end
        // Read back and check
        for (int i = 0; i < SIZE; i++) begin
            agent.get(key[i], got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value[i]);
        end
        // Add another entry (should cause first entry to expire)
        agent.set(key[SIZE], exp_value[SIZE], error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(status_if.fill, SIZE);
        // Read back first entry (should fail)
        agent.get(key[0], got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        // Read back other entries
        for (int i = 1; i < SIZE-1; i++) begin
            agent.get(key[i], got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value[i]);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule
