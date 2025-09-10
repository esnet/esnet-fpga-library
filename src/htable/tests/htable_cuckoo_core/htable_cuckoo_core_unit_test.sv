`include "svunit_defines.svh"

module htable_cuckoo_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import htable_pkg::*;
    import axi4l_verif_pkg::*;
    import db_verif_pkg::*;
    import htable_verif_pkg::*;

    string name = "htable_cuckoo_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int KEY_WID = 96;
    parameter int VALUE_WID = 32;
    parameter int HASH_WID = 13;
    parameter int TIMEOUT_CYCLES = 0;
    parameter int HASH_LATENCY = 0;

    parameter int NUM_TABLES = 3;
    parameter int TABLE_SIZE[NUM_TABLES] = '{default: 8192};

    const int SIZE = TABLE_SIZE.sum();

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

    logic en;

    logic init_done;

    axi4l_intf #() axil_if ();

    db_info_intf info_if ();
    db_status_intf status_if (.clk, .srst);
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if (.clk);

    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) lookup_if (.clk);

    KEY_T   lookup_key;
    hash_t  lookup_hash [NUM_TABLES];

    KEY_T   ctrl_key  [NUM_TABLES];
    hash_t  ctrl_hash [NUM_TABLES];

    logic tbl_init [NUM_TABLES];
    logic tbl_init_done [NUM_TABLES];

    db_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_wr_if [NUM_TABLES] (.clk);
    db_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_rd_if [NUM_TABLES] (.clk);

    htable_cuckoo_core #(
        .KEY_WID (KEY_WID),
        .VALUE_WID (VALUE_WID),
        .NUM_TABLES (NUM_TABLES),
        .TABLE_SIZE (TABLE_SIZE),
        .HASH_LATENCY (HASH_LATENCY)
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Implement hash function
    always_comb begin
        for (int i = 0; i < NUM_TABLES; i++) begin
            lookup_hash[i] = hash(lookup_key, i);
            ctrl_hash[i] = hash(ctrl_key[i], i);
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

    axi4l_reg_agent axil_reg_agent;
    htable_cuckoo_reg_agent reg_agent;
    db_ctrl_agent #(KEY_T, VALUE_T) agent;
    std_reset_intf reset_if (.clk);

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign AXI-L clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign axil_if.aresetn = !srst;
    assign reset_if.ready = init_done;

    assign en = 1'b1;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;

        reg_agent = new("cuckoo_reg_agent", axil_reg_agent);

        agent = new("db_ctrl_agent", SIZE);
        agent.attach(ctrl_if, status_if, info_if);
        agent.set_op_timeout(0);

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        axil_reg_agent.idle();
        agent.idle();
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
    stats_t exp_stats;

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

    `SVTEST(info)
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        int got_size;
        // Get info and check against expected
        agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_HTABLE);
        agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, htable_pkg::HTABLE_TYPE_CUCKOO);
        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, SIZE);
    `SVTEST_END

    `SVTEST(info_reg)
        int got_num_tables;
        int got_key_width;
        int got_value_width;
        // Get info and check against expected
        reg_agent.get_num_tables(got_num_tables);
        `FAIL_UNLESS_EQUAL(got_num_tables, NUM_TABLES);
        reg_agent.get_key_width(got_key_width);
        `FAIL_UNLESS_EQUAL(got_key_width, KEY_WID);
        reg_agent.get_value_width(got_value_width);
        `FAIL_UNLESS_EQUAL(got_value_width, VALUE_WID);
    `SVTEST_END

    `SVTEST(ctrl_reset)
        bit error, timeout;
        agent.clear_all(error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(soft_reset)
        reg_agent.soft_reset();
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
        exp_stats.insert_ok += 1;
        exp_stats.active += 1;
        // Read back and check
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(unset)
        KEY_T key;
        VALUE_T exp_value;
        ENTRY_T got_value;
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
        exp_stats.insert_ok += 1;
        exp_stats.active += 1;
        // Clear entry (and check previous value)
        agent.unset(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        exp_stats.delete_ok += 1;
        exp_stats.active -= 1;
        // Read back and check that entry is cleared
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, '0);
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(replace)
        KEY_T key;
        VALUE_T exp_value [2];
        ENTRY_T got_value;
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
        exp_stats.insert_ok += 1;
        exp_stats.active += 1;
        // Replace entry (and check previous value)
        agent.replace(key, exp_value[1], got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[0]);
        // Read back and check for new entry
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[1]);
        // Check stats
        check_stats();
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
        exp_stats.insert_ok += 1;
        exp_stats.active += 1;
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(many_entries)
        const int NUM_ENTRIES = SIZE/10;
        VALUE_T entries [KEY_T];
        bit error;
        bit timeout;

        do begin
            KEY_T __key;
            VALUE_T __value;
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Generate random value
            void'(std::randomize(__value));
            // Add key to hash table
            agent.set(__key, __value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            exp_stats.insert_ok += 1;
            exp_stats.active += 1;
            entries[__key] = __value;
        end while (entries.size() < NUM_ENTRIES);
        foreach(entries[key]) begin
            bit got_valid;
            VALUE_T got_value;
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, entries[key]);
        end
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(fill_to_50percent)
        const int NUM_ENTRIES = SIZE/2;
        VALUE_T entries [KEY_T];
        bit error;
        bit timeout;

        do begin
            KEY_T __key;
            VALUE_T __value;
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Generate random value
            void'(std::randomize(__value));
            // Add key to hash table
            agent.set(__key, __value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            exp_stats.insert_ok += 1;
            exp_stats.active += 1;
            entries[__key] = __value;
        end while (entries.size() < NUM_ENTRIES);
        foreach(entries[key]) begin
            bit got_valid;
            VALUE_T got_value;
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, entries[key]);
        end
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(fill_to_75percent)
        const int NUM_ENTRIES = SIZE*0.75;
        VALUE_T entries [KEY_T];
        bit error;
        bit timeout;

        do begin
            KEY_T __key;
            VALUE_T __value;
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Generate random value
            void'(std::randomize(__value));
            // Add key to hash table
            agent.set(__key, __value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            exp_stats.insert_ok += 1;
            exp_stats.active += 1;
            entries[__key] = __value;
        end while (entries.size() < NUM_ENTRIES);
        foreach(entries[key]) begin
            bit got_valid;
            VALUE_T got_value;
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, entries[key]);
        end
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(insert_loop)
        KEY_T keys [NUM_TABLES+1];
        VALUE_T __value;
        VALUE_T entries [KEY_T];
        bit error;
        bit timeout;
        bit got_valid;
        VALUE_T got_value;

        // Generate random (unique) key
        void'(std::randomize(keys[0]));
        void'(std::randomize(__value));
        // Add key to hash table
        agent.set(keys[0], __value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_stats.insert_ok += 1;
        exp_stats.active += 1;
        entries[keys[0]] = __value;
        // Generate and insert NUM_TABLES-1 additional keys:
        // Each key is different than first but with same hash values
        for (int i = 1; i < NUM_TABLES; i++) begin
            void'(std::randomize(__value));
            void'(std::randomize(keys[i]));
            keys[i][NUM_TABLES*HASH_WID-1:0] = keys[0][NUM_TABLES*HASH_WID-1:0];
            // Add key
            agent.set(keys[i], __value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            exp_stats.insert_ok += 1;
            exp_stats.active += 1;
        end
        // Check
        foreach(entries[key]) begin
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, entries[key]);
        end
        // Add another key that hashes to the same values
        void'(std::randomize(__value));
        void'(std::randomize(keys[NUM_TABLES]));
        keys[NUM_TABLES][NUM_TABLES*HASH_WID-1:0] = keys[0][NUM_TABLES*HASH_WID-1:0];
        agent.set(keys[NUM_TABLES], __value, error, timeout);
        // Expect insertion failure due to cuckoo hashing insertion loop
        `FAIL_UNLESS(error);
        `FAIL_IF(timeout);
        exp_stats.insert_fail += 1;
        // Check again and ensure that the original NUM_TABLES keys remain in the table
        foreach(entries[key]) begin
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, entries[key]);
        end
        // Check that new entry is not in the table
        lookup_if.query(keys[NUM_TABLES], got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        // Check stats
        check_stats();
    `SVTEST_END


    `SVTEST(stash_hit)
        KEY_T keys [NUM_TABLES+1];
        VALUE_T entries [KEY_T];
        bit error;
        bit timeout;

        VALUE_T __value;
        // Generate random (unique) key
        void'(std::randomize(keys[0]));
        void'(std::randomize(__value));
        // Add key to hash table
        agent.set(keys[0], __value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_stats.insert_ok += 1;
        exp_stats.active += 1;
        entries[keys[0]] = __value;
        // Generate and insert NUM_TABLES-1 additional keys:
        // Each key is different than first but with same hash values
        for (int i = 1; i < NUM_TABLES; i++) begin
            void'(std::randomize(__value));
            void'(std::randomize(keys[i]));
            keys[i][NUM_TABLES*HASH_WID-1:0] = keys[0][NUM_TABLES*HASH_WID-1:0];
            // Add key
            agent.set(keys[i], __value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            exp_stats.insert_ok += 1;
            exp_stats.active += 1;
        end
        // Check
        foreach(entries[key]) begin
            bit got_valid;
            VALUE_T got_value;
            lookup_if.query(key, got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, entries[key]);
        end
        // 'Disable' cuckoo insertion loop detection
        reg_agent.set_cuckoo_ops_limit('1);
        // Add another key that hashes to the same values
        // - this key should have no place in the table since all eligible locations
        //   are occupied; however, while the insertion attempt is being made, it
        //   (along with the other inserted keys) should be accessible via the lookup
        //   interface; at any given time, a key will either be in one of the hash
        //   tables or in the bubble stash
        void'(std::randomize(__value));
        void'(std::randomize(keys[NUM_TABLES]));
        keys[NUM_TABLES][NUM_TABLES*HASH_WID-1:0] = keys[0][NUM_TABLES*HASH_WID-1:0];
        entries[keys[NUM_TABLES]] = __value;
        fork
            begin
                fork
                    begin
                        // Fork insertion process since it is expected to never complete
                        agent.set(keys[NUM_TABLES], __value, error, timeout);
                    end
                    begin
                        // Wait until the insertion is in progress
                        lookup_if._wait(100);
                        for (int i = 0; i < 1000; i++) begin
                            // Cycle through 'inserted' keys, check that all lookup requests are successful
                            // while the keys are constantly shuffled during the cuckoo insertion
                            foreach(entries[key]) begin
                                bit got_valid;
                                VALUE_T got_value;
                                lookup_if.query(key, got_valid, got_value, error, timeout);
                                `FAIL_IF(error);
                                `FAIL_IF(timeout);
                                `FAIL_UNLESS(got_valid);
                                `FAIL_UNLESS_EQUAL(got_value, entries[key]);
                            end
                        end
                    end
                join_any
                disable fork;
            end
        join
    `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
        exp_stats = '{default: '0};
    endtask

    function automatic hash_t hash(input KEY_T key, input int tbl);
        return key[HASH_WID*tbl +: HASH_WID];
    endfunction

    task check_stats(input bit clear = 1'b0);
        stats_t got_stats;
        bit [31:0] got_dbg_active;
        // Registers
        reg_agent.get_stats(got_stats, clear);
        reg_agent.get_dbg_active_cnt(got_dbg_active);
        `FAIL_UNLESS_EQUAL(got_stats.insert_ok,   exp_stats.insert_ok);
        `FAIL_UNLESS_EQUAL(got_stats.insert_fail, exp_stats.insert_fail);
        `FAIL_UNLESS_EQUAL(got_stats.delete_ok,   exp_stats.delete_ok);
        `FAIL_UNLESS_EQUAL(got_stats.delete_fail, exp_stats.delete_fail);
        `FAIL_UNLESS_EQUAL(got_stats.active,      exp_stats.active);
        `FAIL_UNLESS_EQUAL(got_dbg_active,        exp_stats.active);
        // Status interface
        `FAIL_UNLESS_EQUAL(status_if.fill,          exp_stats.active);
        `FAIL_UNLESS_EQUAL(status_if.cnt_active,    exp_stats.active);
        `FAIL_UNLESS_EQUAL(status_if.cnt_activate,  exp_stats.insert_ok);
        `FAIL_UNLESS_EQUAL(status_if.cnt_deactivate,exp_stats.delete_ok);
    endtask

endmodule
