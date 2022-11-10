// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 10ms

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
    localparam int ID_WID = 16;
    localparam int HASH_WID = 12;
    localparam int NUM_IDS = 4096;
    localparam int NUM_TABLES = 3;
    localparam int TABLE_SIZE [NUM_TABLES] = '{default: 4096};
    localparam int BURST_SIZE = 8;

    const int RAW_SIZE = TABLE_SIZE.sum();

    // Typedefs
    localparam type KEY_T = bit[KEY_WID-1:0];
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type ENTRY_T = struct packed {KEY_T key; ID_T id;};

    localparam type RESULT_T = struct packed {logic _new; ID_T id;};

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

    db_intf  #(.KEY_T(KEY_T), .VALUE_T(RESULT_T)) lookup_if (.clk(clk));
    db_intf  #(.KEY_T(ID_T),  .VALUE_T(KEY_T))    delete_if (.clk(clk));

    db_intf  #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_wr_if [NUM_TABLES] (.clk(clk));
    db_intf  #(.KEY_T(hash_t), .VALUE_T(ENTRY_T)) tbl_rd_if [NUM_TABLES] (.clk(clk));

    // Instantiation
    state_cache_core #(
        .KEY_T ( KEY_T ),
        .ID_T ( ID_T ),
        .NUM_IDS ( NUM_IDS ),
        .NUM_TABLES ( NUM_TABLES ),
        .TABLE_SIZE ( TABLE_SIZE ),
        .HASH_LATENCY ( 0 ),
        .NUM_WR_TRANSACTIONS ( 2 ),
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
            localparam int SIZE = TABLE_SIZE[i];
            localparam type HASH_T = logic[$clog2(SIZE)-1:0];
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

    std_verif_pkg::env env;

    axi4l_verif_pkg::axi4l_reg_agent #() reg_agent;
    state_cache_reg_agent#(KEY_T, ID_T) agent;
    std_reset_intf reset_if (.clk(clk));

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

        // Instantiate agent
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
        
        // Allow ID allocator to queue up a 'max burst' number of IDs
        lookup_if._wait(100);

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
            // Pace insertions to stay within sustained insertion capability
            lookup_if._wait(64);
            // Perform another lookup in data plane (expect hit)
            lookup(__key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_IF(__new);
            `FAIL_UNLESS_EQUAL(__id, entries[__key]);
        end while (entries.size() < NUM_ENTRIES);
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
    //===================================
    `SVTEST(all_entries)
        localparam int NUM_ENTRIES = NUM_IDS;
        KEY_T __key;
        ID_T entries [KEY_T];
        ID_T __id;
        bit __tracked;
        bit __new;

        // Allow ID allocator to queue up a 'max burst' number of IDs
        lookup_if._wait(100);

        do begin
            // Generate random (unique) key
            void'(std::randomize(__key));
            if (entries.exists(__key)) continue;
            // Perform lookup in data plane (expect miss resulting in auto-insertion)
            lookup(__key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_UNLESS(__new);
            entries[__key] = __id;
            // Pace insertions to stay within sustained insertion capability
            lookup_if._wait(100);
            // Perform another lookup in data plane (expect hit)
            lookup(__key, __tracked, __id, __new);
            `FAIL_UNLESS(__tracked);
            `FAIL_IF(__new);
            `FAIL_UNLESS_EQUAL(__id, entries[__key]);
        end while (entries.size() < NUM_ENTRIES);
        // Try to insert another entry (expect failure)
        do begin
            void'(std::randomize(__key));
        end while (entries.exists(__key));
        lookup(__key, __tracked, __id, __new);
        `FAIL_IF(__tracked);
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