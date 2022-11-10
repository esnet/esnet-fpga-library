`include "svunit_defines.svh"

module htable_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import htable_pkg::*;
    import db_verif_pkg::*;

    string name = "htable_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int KEY_WID = 96;
    parameter int VALUE_WID = 32;
    parameter int HASH_WID = 8;
    parameter int SIZE = 2**HASH_WID;
    parameter int TIMEOUT_CYCLES = 0;
    
    //===================================
    // Typedefs
    //===================================
    parameter type KEY_T = logic [KEY_WID-1:0];
    parameter type VALUE_T = logic [VALUE_WID-1:0];
    parameter type HASH_T = logic [HASH_WID-1:0];
    parameter type ENTRY_T = struct packed {KEY_T key; VALUE_T value;};

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) update_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) lookup_if (.clk(clk));

    KEY_T   lookup_key;
    hash_t  lookup_hash;
    
    KEY_T   update_key;
    hash_t  update_hash;

    db_info_intf info_if ();

    db_ctrl_intf #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_ctrl_if (.clk(clk));

    logic tbl_init;
    logic tbl_init_done;

    db_intf #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_wr_if (.clk(clk));
    db_intf #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_rd_if (.clk(clk));
    
    htable_core #(
        .KEY_T (KEY_T),
        .VALUE_T (VALUE_T),
        .SIZE (SIZE)
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Implement hash function
    always_comb begin
        lookup_hash = hash(lookup_key);
        update_hash = hash(update_key);
    end

    // Database store
    db_store_array #(
        .KEY_T (HASH_T),
        .VALUE_T (ENTRY_T)
    ) i_db_store_array (
        .clk ( clk ),
        .srst ( srst ),
        .init ( tbl_init ),
        .init_done ( tbl_init_done ),
        .db_wr_if ( tbl_wr_if ),
        .db_rd_if ( tbl_rd_if )
    );
    
    db_ctrl_agent #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) agent;
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

        agent = new("db_ctrl_agent", SIZE);
        agent.attach_info_if(info_if);
        agent.attach_ctrl_if(tbl_ctrl_if);
 
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        
        agent.idle();
        update_if.idle();
        lookup_if.idle();

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

    `SVTEST(info)
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        int got_size;
        // Get info and check against expected
        agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_HTABLE);

        agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, htable_pkg::HTABLE_TYPE_SINGLE);

        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, SIZE);
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
        ENTRY_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        agent.set(hash(key), {key, exp_value}, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Read back and check
        agent.get(hash(key), got_valid, got_entry, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_entry.key, key);
        `FAIL_UNLESS_EQUAL(got_entry.value, exp_value);
    `SVTEST_END

    `SVTEST(unset)
        KEY_T key;
        VALUE_T exp_value;
        ENTRY_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        agent.set(hash(key), {key, exp_value}, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Clear entry (and check previous value)
        agent.unset(hash(key), got_valid, got_entry, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_entry.key, key);
        `FAIL_UNLESS_EQUAL(got_entry.value, exp_value);
        // Read back and check that entry is cleared
        agent.get(hash(key), got_valid, got_entry, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        `FAIL_UNLESS_EQUAL(got_entry.key, '0);
        `FAIL_UNLESS_EQUAL(got_entry.value, '0);

    `SVTEST_END

    `SVTEST(replace)
        KEY_T key;
        VALUE_T exp_value [2];
        ENTRY_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value[0]));
        void'(std::randomize(exp_value[1]));
        // Add entry
        agent.set(hash(key), {key, exp_value[0]}, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Replace entry (and check previous value)
        agent.replace(hash(key), {key, exp_value[1]}, got_valid, got_entry, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_entry.key, key);
        `FAIL_UNLESS_EQUAL(got_entry.value, exp_value[0]);
        // Read back and check that entry is cleared
        agent.get(hash(key), got_valid, got_entry, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_entry.key, key);
        `FAIL_UNLESS_EQUAL(got_entry.value, exp_value[1]);

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
        agent.set(hash(key), {key, exp_value}, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVTEST(update_get)
        KEY_T key;
        VALUE_T exp_value;
        ENTRY_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        update_if.update(key, 1'b1, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Query database from control interface
        agent.get(hash(key), got_valid, got_entry, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_entry.key, key);
        `FAIL_UNLESS_EQUAL(got_entry.value, exp_value);
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
        update_if.update(key, 1'b1, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
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
            void'(std::randomize(exp_value));
            update_if.post_update(key, 1'b1, exp_value, timeout);
            `FAIL_IF(timeout);
        end
        // Query database and check that most recently written value is returned
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

    function automatic hash_t hash(input KEY_T key);
        return key[KEY_WID-1-:HASH_WID];
    endfunction

endmodule
