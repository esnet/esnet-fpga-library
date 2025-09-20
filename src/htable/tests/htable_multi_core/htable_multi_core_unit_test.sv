`include "svunit_defines.svh"

module htable_multi_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import htable_pkg::*;
    import db_verif_pkg::*;

    string name = "htable_multi_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int KEY_WID = 93;
    parameter int VALUE_WID = 64;
    parameter int HASH_WID = 10;
    parameter int SIZE = 2**HASH_WID;
    parameter int TIMEOUT_CYCLES = 0;

    parameter htable_multi_insert_mode_t INSERT_MODE = HTABLE_MULTI_INSERT_MODE_BROADCAST;

    parameter int NUM_TABLES = 3;
    parameter int TABLE_SIZE[NUM_TABLES] = '{default: SIZE};
    
    //===================================
    // Typedefs
    //===================================
    parameter type KEY_T = logic [KEY_WID-1:0];
    parameter type VALUE_T = logic [VALUE_WID-1:0];
    parameter type HASH_T = logic [HASH_WID-1:0];
    parameter type ENTRY_T = struct packed {KEY_T key; VALUE_T value;};
    parameter int  ENTRY_WID = $bits(ENTRY_T);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) lookup_if (.clk);
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) update_if (.clk);

    KEY_T   lookup_key;
    hash_t  lookup_hash [NUM_TABLES];
    
    KEY_T   update_key;
    hash_t  update_hash [NUM_TABLES];

    db_info_intf info_if ();
    
    db_ctrl_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_ctrl_if [NUM_TABLES] (.clk);

    logic tbl_init [NUM_TABLES];
    logic tbl_init_done [NUM_TABLES];

    db_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_wr_if [NUM_TABLES] (.clk);
    db_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_rd_if [NUM_TABLES] (.clk);
    
    htable_multi_core #(
        .KEY_WID (KEY_WID),
        .VALUE_WID (VALUE_WID),
        .NUM_TABLES (NUM_TABLES),
        .TABLE_SIZE (TABLE_SIZE),
        .INSERT_MODE (INSERT_MODE)
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Implement hash function
    always_comb begin
        for (int i = 0; i < NUM_TABLES; i++) begin
            lookup_hash[i] = hash(lookup_key);
            update_hash[i] = hash(update_key);
        end
    end

    // Database store
    generate
        for (genvar i = 0; i < NUM_TABLES; i++) begin
            db_store_array #(
                .KEY_WID (HASH_WID),
                .VALUE_WID (ENTRY_WID)
            ) i_db_store_array (
                .clk ( clk ),
                .srst ( srst ),
                .init ( tbl_init [i] ),
                .init_done ( tbl_init_done [i] ),
                .db_wr_if ( tbl_wr_if[i] ),
                .db_rd_if ( tbl_rd_if[i] )
            );
        end
    endgenerate
    
    db_ctrl_agent #(hash_t, ENTRY_T) agent [NUM_TABLES];
    std_reset_intf reset_if (.clk);

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    virtual db_ctrl_intf#($bits(hash_t), ENTRY_WID) ctrl_vif [NUM_TABLES];

    function automatic connect_ctrl_ifs(virtual db_ctrl_intf#($bits(hash_t), ENTRY_WID) ctrl_if [NUM_TABLES]);
        for (int i = 0; i < NUM_TABLES; i++) begin
            agent[i].attach_ctrl_if(ctrl_if[i]);
        end
    endfunction

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        for (int i = 0; i < NUM_TABLES; i++) begin
            agent[i] = new($sformatf("db_agent[%0d]", i), SIZE);
        end

        connect_ctrl_ifs(tbl_ctrl_if);

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        
        for (int i = 0; i < NUM_TABLES; i++) begin
            agent[i].idle();
        end
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
    
    `SVTEST(hard_reset)
    `SVTEST_END

    `SVTEST(ctrl_reset)
        bit error, timeout;

        agent[0].clear_all(error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(set_get)
        KEY_T key;
        ENTRY_T exp_entry;
        ENTRY_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        for (int i = 0; i < NUM_TABLES; i++) begin
            // Randomize key/value
            void'(std::randomize(key));
            void'(std::randomize(exp_entry));
            // Add entry
            agent[i].set(key, exp_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Read back and check
            for (int j = 0; j < NUM_TABLES; j++) begin
                agent[j].get(key, got_valid, got_entry, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                if (j == i) begin
                    `FAIL_UNLESS(got_valid);
                    `FAIL_UNLESS_EQUAL(got_entry, exp_entry);
                end else begin
                    `FAIL_IF(got_valid);
                end
            end
            // Unset entry to avoid 'collisions' in test
            agent[i].unset(key, got_valid, got_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_entry, exp_entry);
        end
    `SVTEST_END

    `SVTEST(unset)
        KEY_T key;
        VALUE_T exp_entry;
        VALUE_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        for (int i = 0; i < NUM_TABLES; i++) begin
            // Randomize key/value
            void'(std::randomize(key));
            void'(std::randomize(exp_entry));
            // Add entry
            agent[i].set(key, exp_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Read back and check
            for (int j = 0; j < NUM_TABLES; j++) begin
                agent[j].get(key, got_valid, got_entry, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                if (j == i) begin
                    `FAIL_UNLESS(got_valid);
                    `FAIL_UNLESS_EQUAL(got_entry, exp_entry);
                end else begin
                    `FAIL_IF(got_valid);
                end
            end
            // Unset entry to avoid 'collisions' in test
            agent[i].unset(key, got_valid, got_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_entry, exp_entry);
            // Read back and check
            agent[i].get(key, got_valid, got_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_IF(got_valid);
            `FAIL_UNLESS_EQUAL(got_entry, 0);
        end
    `SVTEST_END

    `SVTEST(replace)
        KEY_T key;
        VALUE_T exp_entry[2];
        VALUE_T got_entry;
        bit got_valid;
        bit error;
        bit timeout;
        for (int i = 0; i < NUM_TABLES; i++) begin
            // Randomize key/value
            void'(std::randomize(key));
            void'(std::randomize(exp_entry));
            // Add entry
            agent[i].set(key, exp_entry[0], error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Read back and check
            for (int j = 0; j < NUM_TABLES; j++) begin
                agent[j].get(key, got_valid, got_entry, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                if (j == i) begin
                    `FAIL_UNLESS(got_valid);
                    `FAIL_UNLESS_EQUAL(got_entry, exp_entry[0]);
                end else begin
                    `FAIL_IF(got_valid);
                end
            end
            // Replace entry (and check previous value)
            agent[i].replace(key, exp_entry[1], got_valid, got_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_entry, exp_entry[0]);
             // Read back and check
            for (int j = 0; j < NUM_TABLES; j++) begin
                agent[j].get(key, got_valid, got_entry, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                if (j == i) begin
                    `FAIL_UNLESS(got_valid);
                    `FAIL_UNLESS_EQUAL(got_entry, exp_entry[1]);
                end else begin
                    `FAIL_IF(got_valid);
                end
            end
            // Unset entry to avoid 'collisions' in test
            agent[i].unset(key, got_valid, got_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_entry, exp_entry[1]);
        end
    `SVTEST_END

    `SVTEST(set_query)
        KEY_T key;
        KEY_T got_key;
        ENTRY_T exp_entry;
        ENTRY_T got_entry;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        for (int i = 0; i < NUM_TABLES; i++) begin
            // Randomize key/value
            void'(std::randomize(key));
            void'(std::randomize(exp_value));
            exp_entry = {key, exp_value};
            // Query (expect miss)
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_IF(got_valid);
            // Add entry
            agent[i].set(hash(key), exp_entry, error, timeout);
            // Query (expect hit)
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value);
            // Unset entry
            agent[i].unset(hash(key), got_valid, got_entry, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_entry, exp_entry);
            // Query (expect miss)
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_IF(got_valid);
        end
    `SVTEST_END
    
    `SVTEST(update_get)
        KEY_T key;
        HASH_T __hash;
        ENTRY_T got_entry;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        bit found;
        for (int i = 0; i < NUM_TABLES; i++) begin
            // Randomize key/value
            void'(std::randomize(key));
            void'(std::randomize(exp_value));
            // Add entry
            update_if.update(key, 1'b1, exp_value, error, timeout);
            if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin
                `FAIL_UNLESS(timeout);
            end else begin
                `FAIL_IF(error);
                `FAIL_IF(timeout);
            end
            found = 0;
            for (int j = 0; j < NUM_TABLES; j++) begin
                // Query database from control interface
                agent[j].get(hash(key), got_valid, got_entry, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin
                    `FAIL_IF(got_valid);
                    found = 1;
                end else if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_ROUND_ROBIN) begin
                    if (got_valid) begin
                        // Should find in one location only
                        `FAIL_IF(found);
                        // Record found entry
                        found = 1;
                        `FAIL_UNLESS_EQUAL(got_entry, {key, exp_value});
                    end
                end else if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_BROADCAST) begin
                    `FAIL_UNLESS(got_valid);
                    `FAIL_UNLESS_EQUAL(got_entry, {key, exp_value});
                    found = 1;
                end
            end
            `FAIL_UNLESS(found);
        end
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
        if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin
            `FAIL_UNLESS(timeout);
        end else begin
            `FAIL_IF(error);
            `FAIL_IF(timeout);
        end
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin
            `FAIL_IF(got_valid);
        end else begin
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value);
        end
    `SVTEST_END
 
    `SVTEST(burst_update)
        localparam int BURST_CNT = 8;
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key
        void'(std::randomize(key));
        // Send burst of updates
        for (int i = 0; i < BURST_CNT; i++) begin
            // Add new random entry (same key)
            void'(std::randomize(exp_value));
            update_if.post_update(key, 1'b1, exp_value, timeout);
            if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin
                `FAIL_UNLESS(timeout);
            end else begin
                `FAIL_IF(timeout);
            end
        end
        // Query database and check that most recently written value is returned
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        if (INSERT_MODE == HTABLE_MULTI_INSERT_MODE_NONE) begin
            `FAIL_IF(got_valid);
        end else begin
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

    function automatic HASH_T hash(input KEY_T key);
        return key[KEY_WID-1-:HASH_WID];
    endfunction

endmodule
