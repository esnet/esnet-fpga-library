`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 20ms

module state_cache_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import htable_pkg::*;
    import db_verif_pkg::*;
    import state_verif_pkg::*;

    string name = "state_cache_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int KEY_WID = 64;
    localparam int HASH_WID = 12;
    localparam int NUM_IDS = 8192;
    localparam int NUM_TABLES = 3;
    localparam int TABLE_SIZE [NUM_TABLES] = '{default: 2**HASH_WID};
    localparam int BURST_SIZE = 8;


    localparam int ID_WID = $clog2(NUM_IDS);

    const int RAW_SIZE = TABLE_SIZE.sum();

    // Typedefs
    localparam type KEY_T = bit[KEY_WID-1:0];
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type ENTRY_T = struct packed {KEY_T key; ID_T id;};
    localparam int  ENTRY_WID = $bits(ENTRY_T);

    localparam type RESULT_T = struct packed {logic _new; ID_T id;};
    localparam int RESULT_WID = $bits(RESULT_T);

    //===================================
    // DUT
    //===================================

    // Signals
    logic    clk;
    logic    srst;

    logic    en;
    logic    init_done;

    KEY_T    lookup_key;
    hash_t   lookup_hash [NUM_TABLES];

    KEY_T    ctrl_key  [NUM_TABLES];
    hash_t   ctrl_hash [NUM_TABLES];

    logic    tbl_init [NUM_TABLES];
    logic    tbl_init_done [NUM_TABLES];

    // Interfaces
    axi4l_intf  #() axil_if ();

    db_intf  #(.KEY_WID(KEY_WID), .VALUE_WID(RESULT_WID)) lookup_if (.clk);
    db_intf  #(.KEY_WID(ID_WID),  .VALUE_WID(KEY_WID))    delete_if (.clk);

    db_intf  #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_wr_if [NUM_TABLES] (.clk);
    db_intf  #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_rd_if [NUM_TABLES] (.clk);

    integer status_fill;

    // Instantiation
    state_cache_core #(
        .KEY_WID ( KEY_WID ),
        .ID_WID ( ID_WID ),
        .NUM_TABLES ( NUM_TABLES ),
        .TABLE_SIZE ( TABLE_SIZE ),
        .HASH_LATENCY ( 0 ),
        .NUM_RD_TRANSACTIONS ( 8 ),
        .UPDATE_BURST_SIZE ( BURST_SIZE )
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

    std_verif_pkg::basic_env env;

    axi4l_verif_pkg::axi4l_reg_agent #() reg_agent;
    state_cache_reg_agent#(KEY_T, ID_T) agent;
    std_reset_intf reset_if (.clk);

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign AXI-L clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    assign axil_if.aresetn = !srst;

    assign en = 1'b1;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Testbench environment
        env = new();
        env.reset_vif = reset_if;

        // AXI-L agent
        reg_agent = new("axil_reg_agent");
        reg_agent.axil_vif = axil_if;

        // Instantiate agents
        agent = new("state_cache_agent", NUM_IDS, reg_agent);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        agent.idle();
        lookup_if.idle();
        delete_if.idle();

        // HW reset
        env.reset_dut();

    endtask

    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
        /* Place Teardown Code Here */
    endtask

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

    //===================================
    // Test:
    //   Reset
    //
    // Description:
    //   Issue (block-level) reset signal,
    //   wait for initialization to complete
    //===================================
    `SVTEST(reset)
    `SVTEST_END

    //===================================
    // Test:
    //   Info
    //
    // Description:
    //   Check reported parameterization
    //   and compare against expected
    //===================================
    `SVTEST(info)
        int got_size;
        // Retrieve size
        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    //===================================
    // Test:
    //   Info (htable)
    //
    // Description:
    //   Check reported parameterization
    //   of underlying data structure and
    //   compare against expected
    //===================================
    `SVTEST(info_htable)
        int got_num_tables;
        int got_burst_size;
        int got_key_width;
        int got_value_width;
        // Get (cuckoo) info and check against expected
        agent.cuckoo_agent.get_num_tables(got_num_tables);
        `FAIL_UNLESS_EQUAL(got_num_tables, NUM_TABLES);
        agent.cuckoo_agent.get_key_width(got_key_width);
        `FAIL_UNLESS_EQUAL(got_key_width, KEY_WID);
        agent.cuckoo_agent.get_value_width(got_value_width);
        `FAIL_UNLESS_EQUAL(got_value_width, ID_WID);

        // Get (fast update) info and check against expected
        agent.fast_update_agent.get_burst_size(got_burst_size);
        `FAIL_UNLESS_EQUAL(got_burst_size, BURST_SIZE);
        agent.fast_update_agent.get_key_width(got_key_width);
        `FAIL_UNLESS_EQUAL(got_key_width, KEY_WID);
        agent.fast_update_agent.get_value_width(got_value_width);
        `FAIL_UNLESS_EQUAL(got_value_width, ID_WID);
    `SVTEST_END

    //===================================
    // Test:
    //   Info
    //
    // Description:
    //   Check reported parameterization
    //   of underlying data structure and
    //   compare against expected
    //===================================
    `SVTEST(info_db)
        int got_size;
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        // Check (database) type
        agent.db_agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_HTABLE);
        // Check (state) type
        agent.db_agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, htable_pkg::HTABLE_TYPE_CUCKOO_FAST_UPDATE);
        // Check size
        agent.db_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, RAW_SIZE);
    `SVTEST_END

    //===================================
    // Test:
    //   Control-plane (soft) reset
    //
    // Description:
    //   Issue soft reset via register interface
    //   and wait for initialization to complete
    //===================================
    `SVTEST(soft_reset)
        agent.soft_reset();
    `SVTEST_END

    //===================================
    // Test:
    //   Set and then retrieve from control plane
    //
    // Description:
    //   Set cache entry via control plane interface,
    //   check by reading entry over the same interface.
    //===================================
    `SVTEST(set_get)
        KEY_T key;
        ID_T got_id;
        ID_T exp_id;
        logic got_valid;
        logic error;
        logic timeout;
        // Randomize
        void'(std::randomize(key));
        exp_id = random_id();
        // Set state
        agent.db_agent.set(key, exp_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Check state
        agent.db_agent.get(key, got_valid, got_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
    `SVTEST_END

    //===================================
    // Test:
    //   Set from control plane,
    //   retrieve from data plane
    //
    // Description:
    //   Set cache entry via control plane interface,
    //   check by reading entry over the lookup
    //   (data plane) interface
    //===================================
    `SVTEST(set_lookup)
        KEY_T key;
        ID_T got_id;
        ID_T exp_id;
        logic got_valid;
        logic tracked;
        logic _new;
        logic error;
        logic timeout;
        // Randomize
        void'(std::randomize(key));
        exp_id = random_id();
        // Set state
        agent.db_agent.set(key, exp_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Check state via control plane
        agent.db_agent.get(key, got_valid, got_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
        // Perform lookup in data plane
        lookup(key, tracked, got_id, _new);
        `FAIL_UNLESS(tracked);
        `FAIL_IF(_new);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
    `SVTEST_END

    //===================================
    // Test:
    //   Auto-insertion from data plane
    //
    // Description:
    //   Perform lookup in data plane and
    //   expect auto-insertion of new entry;
    //   check via control-plane and data-plane
    //   queries.
    //===================================
    `SVTEST(auto_insert)
        KEY_T key;
        ID_T got_id;
        ID_T exp_id;
        logic got_valid;
        logic tracked;
        logic _new;
        logic error;
        logic timeout;

        // Allow ID allocator to queue up a 'max burst' number of IDs
        lookup_if._wait(100);

        // Randomize
        void'(std::randomize(key));
        // Perform lookup in data plane (expect miss resulting in auto-insertion)
        lookup(key, tracked, exp_id, _new);
        `FAIL_UNLESS(tracked);
        `FAIL_UNLESS(_new);
        // Perform another lookup in data plane (expect hit)
        lookup(key, tracked, got_id, _new);
        `FAIL_UNLESS(tracked);
        `FAIL_IF(_new);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
        // Read entry from control plane
        agent.db_agent.get(key, got_valid, got_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
    `SVTEST_END

    //===================================
    // Test:
    //   Auto-insertion and then delete
    //
    // Description:
    //   Perform lookup in data plane and
    //   check that entry is inserted;
    //   Delete entry via delete interface
    //   and check.
    //===================================
    `SVTEST(insert_delete)
        KEY_T key;
        KEY_T got_key;
        ID_T got_id;
        ID_T exp_id;
        logic tracked;
        logic _new;
        logic got_valid;
        logic error;
        logic timeout;

        // Allow ID allocator to queue up a 'max burst' number of IDs
        lookup_if._wait(100);

        // Randomize
        void'(std::randomize(key));
        // Perform lookup in data plane (expect miss resulting in auto-insertion)
        lookup(key, tracked, exp_id, _new);
        `FAIL_UNLESS(tracked);
        `FAIL_UNLESS(_new);
        // Perform another lookup in data plane (expect hit)
        lookup(key, tracked, got_id, _new);
        `FAIL_UNLESS(tracked);
        `FAIL_IF(_new);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
        // Read entry from control plane
        agent.db_agent.get(key, got_valid, got_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
        // Delete entry
        delete(exp_id, got_key);
        `FAIL_UNLESS_EQUAL(got_key, key);
        // Perform lookup in data plane (expect miss resulting in auto-insertion)
        lookup(key, tracked, exp_id, _new);
        `FAIL_UNLESS(tracked);
        `FAIL_UNLESS(_new);
        // Read entry from control plane
        agent.db_agent.get(key, got_valid, got_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
    `SVTEST_END

    //===================================
    // Test:
    //   Auto-insert (random) burst
    //
    // Description:
    //   Perform insertion of a 'max burst'
    //   number of new (random) entries;
    //   check via control-plane and
    //   data-plane queries.
    //===================================
    `SVTEST(auto_insert_random_burst)
        localparam int NUM_ENTRIES = BURST_SIZE;
        ID_T entries [KEY_T];
        ID_T __id;
        bit __tracked;
        bit __new;

        // Allow ID allocator to queue up a 'max burst' number of IDs
        lookup_if._wait(100);

        // Insert 'max burst' number of entries
        do begin
            KEY_T __key;
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Perform lookup in data plane (expect miss resulting in auto-insertion)
            lookup(__key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_UNLESS(__new);
            entries[__key] = __id;
        end while (entries.size() < NUM_ENTRIES);
        // Check
        foreach (entries[key]) begin
            bit error;
            bit timeout;
            // Perform another lookup in data plane (expect hit)
            lookup(key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_IF(__new);
            `FAIL_UNLESS_EQUAL(__id, entries[key]);
            // Read entry from control plane
            agent.db_agent.get(key, __tracked, __id, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(__tracked);
            `FAIL_UNLESS_EQUAL(__id, entries[key]);
        end

    `SVTEST_END

    //===================================
    // Test:
    //   Auto-insert (uniform) burst
    //
    // Description:
    //   Perform insertion of a 'max burst'
    //   number of new entries; check via
    //   control-plane and data-plane
    //   queries.
    //===================================
    `SVTEST(auto_insert_uniform_burst)
        KEY_T key;
        ID_T exp_id;
        ID_T got_id;
        bit __tracked;
        bit __new;
        bit got_valid;
        bit error;
        bit timeout;

        // Allow ID allocator to queue up a 'max burst' number of IDs
        lookup_if._wait(100);

        // Generate random (unique) key
        void'(std::randomize(key));

        // Perform lookup in data plane (expect miss resulting in auto-insertion)
        lookup(key, __tracked, exp_id, __new);
        `FAIL_UNLESS(__tracked);
        `FAIL_UNLESS(__new);

        // Lookup same key 'max burst - 1' more times
        for (int i = 0; i < BURST_SIZE-1; i++) begin
            // Perform lookup in data plane (expect hit)
            lookup(key, __tracked, got_id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_IF(__new);
            `FAIL_UNLESS_EQUAL(got_id, exp_id);
        end
        // Read entry from control plane
        agent.db_agent.get(key, got_valid, got_id, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);

    `SVTEST_END


    //===================================
    // Test:
    //   Back-to-back
    //
    // Description:
    //   Perform insertion and then lookup
    //   of the same key on successive
    //   clock cycles; check that the first
    //   query leads to an insertion event,
    //   and that the next lookup hits the
    //   newly inserted entry.
    //===================================
    `SVTEST(back_to_back)
        localparam int NUM_EVENTS = 2;

        // Allow ID allocator to queue up available IDs
        lookup_if._wait(100);

        fork
            begin
                // Send multiple looup requests for the same key
                KEY_T key;
                void'(std::randomize(key));
                repeat (NUM_EVENTS) begin
                    lookup_send(key);
                end
            end
            begin
                // Check responses
                ID_T exp_id;
                ID_T got_id;
                bit __tracked;
                bit __new;
                // -- First response should reflect new entry
                lookup_receive(__tracked, exp_id, __new);
                `FAIL_UNLESS(__tracked);
                `FAIL_UNLESS(__new);
                // -- Subsequent responses shoud reflect existing entry
                for (int i = 0; i < NUM_EVENTS-1; i++) begin
                    lookup_receive(__tracked, got_id, __new);
                    `FAIL_UNLESS(__tracked);
                    `FAIL_IF(__new);
                    `FAIL_UNLESS_EQUAL(got_id, exp_id);
                end
            end
        join

    `SVTEST_END


    //===================================
    // Test:
    //   Insert 'many' entries and check.
    //
    // Description:
    //   Perform auto-insertion of a significant
    //   number of entries (such that full
    //   cuckoo insertion is exercised).
    //   Check via control-plane and data-plane
    //   queries.
    //===================================
    `SVTEST(many_entries)
        localparam int NUM_ENTRIES = NUM_IDS/5;
        ID_T entries [KEY_T];
        ID_T __id;
        bit __tracked;
        bit __new;
        int got_fill;

        do begin
            KEY_T __key;
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Perform lookup in data plane (expect miss resulting in auto-insertion)
            lookup(__key, __tracked, __id, __new);
            if (__tracked) begin
                `FAIL_UNLESS(__new);
                entries[__key] = __id;
                // Perform another lookup in data plane (expect hit)
                lookup(__key, __tracked, __id, __new);
                `FAIL_UNLESS(__tracked);
                `FAIL_IF(__new);
                `FAIL_UNLESS_EQUAL(__id, entries[__key]);
            end
        end while (entries.size() < NUM_ENTRIES);
        // Wait until cache reaches expected fill level
        do
            agent.db_agent.get_fill(got_fill);
        while (got_fill != NUM_ENTRIES);
        `FAIL_UNLESS_EQUAL(status_fill, NUM_ENTRIES);

        foreach (entries[key]) begin
            bit error;
            bit timeout;
            // Perform another lookup in data plane (expect hit)
            lookup(key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_IF(__new);
            `FAIL_UNLESS_EQUAL(__id, entries[key]);
            // Read entry from control plane
            agent.db_agent.get(key, __tracked, __id, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            `FAIL_UNLESS(__tracked);
            `FAIL_UNLESS_EQUAL(__id, entries[key]);
        end
    `SVTEST_END


    //===================================
    // Test:
    //   Insert to full and check.
    //
    // Description:
    //   Perform auto-insertion of a significant
    //   number of entries (such that full
    //   cuckoo insertion is exercised).
    //   Check via control-plane and data-plane
    //   queries.
    //
    //   Then attempt to insert additional entries,
    //   (at least enough to fill the update FIFO).
    //   These insertions should all fail.
    //
    //   Then attempt to delete some number of entries,
    //   and re-insert the same number.
    //===================================
    `SVTEST(all_entries)
        localparam int NUM_ENTRIES = NUM_IDS;
        localparam int NUM_RECYCLED = NUM_IDS/10;
        KEY_T __key;
        ID_T entries [KEY_T];
        KEY_T entries_rev [ID_T];
        ID_T __id;
        ID_T __id_recycled;
        ID_T __ids_recycled [NUM_RECYCLED];
        bit __tracked;
        bit __new;
        int got_fill;

        do begin
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Perform lookup in data plane (expect miss resulting in auto-insertion)
            lookup(__key, __tracked, __id, __new);
            if (__tracked) begin
                `FAIL_UNLESS(__new);
                entries[__key] = __id;
                entries_rev[__id] = __key;
                // Perform another lookup in data plane (expect hit)
                lookup(__key, __tracked, __id, __new);
                `FAIL_UNLESS(__tracked);
                `FAIL_IF(__new);
                `FAIL_UNLESS_EQUAL(__id, entries[__key]);
            end
        end while (entries.size() < NUM_ENTRIES);
        // Try to insert additional entries (expect failure)
        for (int i = 0; i < (BURST_SIZE + 1); i++) begin
            do begin
                void'(std::randomize(__key));
            end while (entries.exists(__key));
            lookup(__key, __tracked, __id, __new);
            `FAIL_IF(__tracked);
        end
        // Wait until cache reports full
        do begin
            agent.db_agent.get_fill(got_fill);
        end while (got_fill != NUM_ENTRIES);
        `FAIL_UNLESS_EQUAL(status_fill, NUM_ENTRIES);
        // Delete entries
        for (int i = 0; i < NUM_RECYCLED; i++) begin
            do begin
                void'(std::randomize(__id_recycled));
            end while (!entries_rev.exists(__id_recycled));
            delete(__id_recycled, __key);
            `FAIL_UNLESS_EQUAL(__key, entries_rev[__id_recycled]);
            entries.delete(__key);
            entries_rev.delete(__id_recycled);
            __ids_recycled[i] = __id_recycled;
        end
        // Wait until cache reports expected fill
        do begin
            agent.db_agent.get_fill(got_fill);
        end while (got_fill != (NUM_ENTRIES - NUM_RECYCLED));
        `FAIL_UNLESS_EQUAL(status_fill, NUM_ENTRIES - NUM_RECYCLED);
        // Insert entries
        do begin
            // Choose unique key
            do begin
                void'(std::randomize(__key));
            end while (entries.exists(__key));
            lookup(__key, __tracked, __id, __new);
            if (__tracked) begin
                `FAIL_UNLESS(__new);
                `FAIL_UNLESS(__id inside {__ids_recycled});
                entries[__key] = __id;
                entries_rev[__id] = __key;
            end
        end while (entries.size() < NUM_ENTRIES);
        // Allow sufficient time for pending updates to be processed
        do begin
            agent.db_agent.get_fill(got_fill);
        end while (got_fill != NUM_ENTRIES);
        `FAIL_UNLESS_EQUAL(status_fill, NUM_ENTRIES);
        // Check
        `FAIL_UNLESS(entries.size() == NUM_ENTRIES);
        foreach (entries[key]) begin
            bit error;
            bit timeout;
            // Perform another lookup in data plane (expect hit)
            lookup(key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_IF(__new);
            `FAIL_UNLESS_EQUAL(__id, entries[key]);
        end
        // Delete all entries
        foreach (entries_rev[id]) begin
            delete(id, __key);
            `FAIL_UNLESS_EQUAL(__key, entries_rev[id]);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    function automatic hash_t hash(input KEY_T key, input int tbl);
        return key[HASH_WID*tbl +: HASH_WID];
    endfunction

    function automatic int random_id();
        ID_T id;
        void'(std::randomize(id));
        return id % NUM_IDS;
    endfunction

    task lookup_send(input KEY_T key);
        lookup_if.send(key);
    endtask

    task lookup_receive(
            output bit tracked, output ID_T id, output bit _new,
            input bit DEBUG = 0
        );
        bit      __valid;
        RESULT_T __result;
        bit error;
        if (DEBUG) `INFO("--- LOOKUP RESP ---");
        lookup_if.receive(tracked, __result, error);
        `FAIL_IF(error);
        _new = __result._new;
        id = __result.id;
        `FAIL_UNLESS(id inside {[0:NUM_IDS-1]});
        if (DEBUG) begin
            `INFO($sformatf("TRACKED: %b", tracked));
            `INFO($sformatf("NEW: %b", _new));
            `INFO($sformatf("ID: 0x%x", id));
            `INFO("--- LOOKUP RESP Done ---");
        end
    endtask

    task lookup(
            input KEY_T key,
            output bit tracked, output ID_T id, output bit _new,
            input bit DEBUG = 0
        );
        RESULT_T __result;
        bit timeout;
        bit error;
        if (DEBUG) `INFO($sformatf("--- LOOKUP (KEY: 0x%x) ---", key));
        // Lookup request
        lookup_if.query(key, tracked, __result, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        _new = __result._new;
        id = __result.id;
        `FAIL_UNLESS(id inside {[0:NUM_IDS-1]});
        if (DEBUG) begin
            `INFO($sformatf("TRACKED: %b", tracked));
            `INFO($sformatf("NEW: %b", _new));
            `INFO($sformatf("ID: 0x%x", id));
            `INFO($sformatf("--- LOOKUP Done (KEY: 0x%x) ---", key));
        end
    endtask

    task delete(
            input ID_T id, output KEY_T key, input bit DEBUG = 0
        );
        bit   __valid;
        KEY_T __key;
        bit timeout;
        bit error;
        if (DEBUG) `INFO($sformatf("--- DELETE (ID: 0x%x) ---", id));
        // Delete request
        delete_if.query(id, __valid, key, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(__valid);
        if (DEBUG) begin
            `INFO($sformatf("KEY: 0x%x", key));
            `INFO($sformatf("--- DELETE Done (ID: 0x%x) ---", id));
        end
    endtask

endmodule
