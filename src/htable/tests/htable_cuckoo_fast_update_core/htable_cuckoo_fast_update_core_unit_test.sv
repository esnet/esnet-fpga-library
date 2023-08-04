`include "svunit_defines.svh"

module htable_cuckoo_fast_update_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import db_pkg::*;
    import htable_pkg::*;
    import db_verif_pkg::*;
    import htable_verif_pkg::*;

    string name = "htable_cuckoo_fast_update_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    parameter int KEY_WID = 96;
    parameter int VALUE_WID = 32;
    parameter int HASH_WID = 8;
    parameter int TIMEOUT_CYCLES = 0;
    parameter int HASH_LATENCY = 0;
    
    parameter int NUM_TABLES = 3;
    parameter int TABLE_SIZE[NUM_TABLES] = '{default: 256};

    const int SIZE = TABLE_SIZE.sum();

    parameter int UPDATE_BURST_SIZE = 8;
    
    //===================================
    // Typedefs
    //===================================
    parameter type KEY_T = logic [KEY_WID-1:0];
    parameter type VALUE_T = logic [VALUE_WID-1:0];
    parameter type HASH_T = logic [HASH_WID-1:0];
    parameter type ENTRY_T = struct packed {KEY_T key; VALUE_T value;};

    typedef struct {
        int update;
        int active;
    } update_stats_t;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic en;

    logic init_done;

    axi4l_intf #() axil_if ();

    db_info_intf info_if ();
    db_status_intf status_if (.clk(clk), .srst(srst));
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if (.clk(clk));

    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) lookup_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) update_if (.clk(clk));

    KEY_T   lookup_key;
    hash_t  lookup_hash [NUM_TABLES];
    
    KEY_T   ctrl_key  [NUM_TABLES];
    hash_t  ctrl_hash [NUM_TABLES];

    logic tbl_init [NUM_TABLES];
    logic tbl_init_done [NUM_TABLES];

    db_intf #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_wr_if [NUM_TABLES] (.clk(clk));
    db_intf #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_rd_if [NUM_TABLES] (.clk(clk));
    
    htable_cuckoo_fast_update_core #(
        .KEY_T (KEY_T),
        .VALUE_T (VALUE_T),
        .NUM_TABLES (NUM_TABLES),
        .TABLE_SIZE (TABLE_SIZE),
        .HASH_LATENCY (HASH_LATENCY),
        .UPDATE_BURST_SIZE (UPDATE_BURST_SIZE)
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
                .KEY_T (HASH_T),
                .VALUE_T (ENTRY_T)
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
    htable_cuckoo_reg_agent cuckoo_reg_agent;
    htable_fast_update_reg_agent fast_update_reg_agent;
    db_ctrl_agent #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) agent;
    std_reset_intf reset_if (.clk(clk));

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign AXI clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    assign axil_if.aresetn = !reset_if.reset;

    assign en = 1'b1;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axil_reg_agent = new;
        axil_reg_agent.axil_vif = axil_if;

        cuckoo_reg_agent      = new("cuckoo_reg_agent",      axil_reg_agent, 'h00);
        fast_update_reg_agent = new("fast_update_reg_agent", axil_reg_agent, 'h80);

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
        update_if.idle();

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
    stats_t exp_cuckoo_stats;
    update_stats_t exp_update_stats;

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
        `FAIL_UNLESS_EQUAL(got_subtype, htable_pkg::HTABLE_TYPE_CUCKOO_FAST_UPDATE);

        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, SIZE);
    `SVTEST_END

    `SVTEST(cuckoo_info_reg)
        int got_num_tables;
        int got_key_width;
        int got_value_width;
        // Get info and check against expected
        cuckoo_reg_agent.get_num_tables(got_num_tables);
        `FAIL_UNLESS_EQUAL(got_num_tables, NUM_TABLES);
        cuckoo_reg_agent.get_key_width(got_key_width);
        `FAIL_UNLESS_EQUAL(got_key_width, KEY_WID);
        cuckoo_reg_agent.get_value_width(got_value_width);
        `FAIL_UNLESS_EQUAL(got_value_width, VALUE_WID);
    `SVTEST_END

    `SVTEST(fast_update_info)
        int got_burst_size;
        int got_key_width;
        int got_value_width;
        // Get info and check against expected
        fast_update_reg_agent.get_burst_size(got_burst_size);
        `FAIL_UNLESS_EQUAL(got_burst_size, UPDATE_BURST_SIZE);
        fast_update_reg_agent.get_key_width(got_key_width);
        `FAIL_UNLESS_EQUAL(got_key_width, KEY_WID);
        fast_update_reg_agent.get_value_width(got_value_width);
        `FAIL_UNLESS_EQUAL(got_value_width, VALUE_WID);
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
        exp_update_stats.update += 1;
        // Read back and check
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Wait for cuckoo insertion
        agent._wait(100);
        exp_cuckoo_stats.insert_ok += 1;
        exp_cuckoo_stats.active += 1;
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
        `FAIL_UNLESS_EQUAL(got_value, '0);
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
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVTEST(update_get)
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
        // Query database from control interface
        agent.get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
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

    `SVTEST(delete)
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Insert entry
        update_if.update(key, 1'b1, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_update_stats.update += 1;
        exp_cuckoo_stats.insert_ok += 1;
        exp_cuckoo_stats.active += 1;
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Delete entry
        update_if.update(key, 1'b0, '0, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_update_stats.update += 1;
        exp_cuckoo_stats.delete_ok += 1;
        exp_cuckoo_stats.active -= 1;
        // Wait for delete to be processed
        update_if._wait(100);
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        // Check stats
        check_stats();
    `SVTEST_END

    `SVTEST(delete_fail)
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Insert entry
        update_if.update(key, 1'b1, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_update_stats.update += 1;
        exp_cuckoo_stats.insert_ok += 1;
        exp_cuckoo_stats.active += 1;
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Delete entry
        update_if.update(key, 1'b0, '0, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_update_stats.update += 1;
        exp_cuckoo_stats.delete_ok += 1;
        exp_cuckoo_stats.active -= 1;
        // Wait for delete to be processed
        update_if._wait(50);
        // Query database from app interface
        lookup_if.query(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        // Delete entry again (should fail)
        update_if.update(key, 1'b0, '0, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_update_stats.update += 1;
        exp_cuckoo_stats.delete_fail += 1;
        // Wait for delete to be processed
        update_if._wait(50);
        // Insert entry again
        update_if.update(key, 1'b1, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        exp_update_stats.update += 1;
        exp_cuckoo_stats.insert_ok += 1;
        exp_cuckoo_stats.active += 1;
        // Wait for insert to be processed
        update_if._wait(50);
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
         const int NUM_ENTRIES = SIZE/2;
         VALUE_T entries [KEY_T];
         VALUE_T got_value;
         bit got_valid;
         bit error;
         bit timeout;
         for (int i = 0; i < NUM_ENTRIES; i++) begin
             KEY_T __key;
             VALUE_T __value;
             // Randomize key/value
             void'(std::randomize(__key));
             void'(std::randomize(__value));
             entries[__key] = __value;
             // Add entry
             update_if.update(__key, 1'b1, __value, error, timeout, 1000);
             `FAIL_IF(error);
             `FAIL_IF(timeout);
             update_if._wait(200);
         end
         foreach (entries[key]) begin
             // Query database from app interface
             lookup_if.query(key, got_valid, got_value, error, timeout);
             `FAIL_IF(error);
             `FAIL_IF(timeout);
             `FAIL_UNLESS(got_valid);
             `FAIL_UNLESS_EQUAL(got_value, entries[key]);
         end
    `SVTEST_END

    `SVTEST(max_burst_update)
        localparam int BURST_CNT = UPDATE_BURST_SIZE;
        KEY_T key [BURST_CNT];
        VALUE_T exp_value [BURST_CNT];
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize keys/values
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        for (int i = 0; i < BURST_CNT; i++) begin
            update_if.post_update(key[i], 1'b1, exp_value[i], timeout);
            `FAIL_IF(timeout);
        end
        #10us;
        // Query database and check that all values are returned
        for (int i = 0; i < BURST_CNT; i++) begin
            lookup_if.query(key[i], got_valid, got_value, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(got_valid);
            `FAIL_UNLESS_EQUAL(got_value, exp_value[i]);
        end
    `SVTEST_END


    `SVTEST(burst_update_same_key)
        localparam int BURST_CNT = 8;
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
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
        exp_cuckoo_stats = '{default: '0};
        exp_update_stats = '{default: '0};
    endtask

    function automatic hash_t hash(input KEY_T key, input int tbl);
        return key[HASH_WID*tbl +: HASH_WID];
    endfunction

    task check_stats(input bit clear = 1'b0);
        stats_t got_stats;
        bit [31:0] got_dbg_active;
        bit [63:0] got_update;
        // Registers
        cuckoo_reg_agent.get_stats(got_stats, clear);
        cuckoo_reg_agent.get_dbg_active_cnt(got_dbg_active);
        `FAIL_UNLESS_EQUAL(got_stats.insert_ok,   exp_cuckoo_stats.insert_ok);
        `FAIL_UNLESS_EQUAL(got_stats.insert_fail, exp_cuckoo_stats.insert_fail);
        `FAIL_UNLESS_EQUAL(got_stats.delete_ok,   exp_cuckoo_stats.delete_ok);
        `FAIL_UNLESS_EQUAL(got_stats.delete_fail, exp_cuckoo_stats.delete_fail);
        `FAIL_UNLESS_EQUAL(got_stats.active,      exp_cuckoo_stats.active);
        `FAIL_UNLESS_EQUAL(got_dbg_active,        exp_cuckoo_stats.active);
        // Status interface
        `FAIL_UNLESS_EQUAL(status_if.fill,          exp_cuckoo_stats.active);
        `FAIL_UNLESS_EQUAL(status_if.cnt_active,    exp_cuckoo_stats.active);
        `FAIL_UNLESS_EQUAL(status_if.cnt_activate,  exp_cuckoo_stats.insert_ok);
        `FAIL_UNLESS_EQUAL(status_if.cnt_deactivate,exp_cuckoo_stats.delete_ok);
         // Update stats
         fast_update_reg_agent.get_stats(got_stats, clear);
         fast_update_reg_agent.get_update_cnt(got_update);
         fast_update_reg_agent.get_dbg_active_cnt(got_dbg_active);
         `FAIL_UNLESS_EQUAL(got_stats.insert_ok,   exp_cuckoo_stats.insert_ok);
         `FAIL_UNLESS_EQUAL(got_stats.insert_fail, exp_cuckoo_stats.insert_fail);
         `FAIL_UNLESS_EQUAL(got_stats.delete_ok,   exp_cuckoo_stats.delete_ok);
         `FAIL_UNLESS_EQUAL(got_stats.delete_fail, exp_cuckoo_stats.delete_fail);
         `FAIL_UNLESS_EQUAL(got_stats.active,      exp_update_stats.active);
         `FAIL_UNLESS_EQUAL(got_dbg_active,        exp_update_stats.active);
         `FAIL_UNLESS_EQUAL(got_update,            exp_update_stats.update);
    endtask

endmodule
