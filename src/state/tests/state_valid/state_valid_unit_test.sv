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
`define SVUNIT_TIMEOUT 2ms

module state_valid_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_valid_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 14;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type DUMMY_T = bit;

    localparam type STATE_T = DUMMY_T; // Unused
    localparam type UPDATE_T = DUMMY_T; // Unused

    //===================================
    // DUT
    //===================================
    // Signals
    logic   clk;
    logic   srst;
    logic   init_done;

    // Interfaces
    db_ctrl_intf      #(.KEY_T(ID_T), .VALUE_T(STATE_T)) ctrl_if (.clk(clk));
    db_info_intf      #()                                info_if ();
    db_status_intf    #()                                status_if (.clk(clk), .srst(srst));
    state_update_intf #(.ID_T(ID_T),  .STATE_T(STATE_T)) update_if (.clk(clk));

    // Instantiation
    state_valid #(
        .ID_T ( ID_T )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::env env;

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, DUMMY_T) ctrl_agent;

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Interfaces
    std_reset_intf reset_if (.clk(clk));

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Testbench environment
        env = new();
        env.reset_vif = reset_if;

        // Instantiate agent
        ctrl_agent = new("db_ctrl_agent", NUM_IDS);
        ctrl_agent.ctrl_vif = ctrl_if;
        ctrl_agent.info_vif = info_if;

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        ctrl_agent.idle();
        update_if.idle();

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
    DUMMY_T __state_unused = 1'b0;
    DUMMY_T __update_unused = 1'b0;

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
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        int got_size;
        // Check (database) type
        ctrl_agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_STATE);
        // Check (state) type
        ctrl_agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, state_pkg::STATE_TYPE_VALID);
        // Check size
        ctrl_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    `SVTEST(enable_record)
        ID_T id;
        bit enabled;
        // Randomize
        void'(std::randomize(id));
        // Enable record
        enable(id);
        // Wait for enable to happen
        ctrl_agent._wait(5);
        // Check record
        get_valid(id, enabled);
       `FAIL_UNLESS(enabled);
    `SVTEST_END

    `SVTEST(enable_disable_record)
        ID_T id;
        bit enabled;
        // Randomize
        void'(std::randomize(id));
        // Enable record
        enable(id);
        // Wait for enable to happen
        ctrl_agent._wait(5);
        // Disable record
        _disable(id, enabled);
        // Check that previous state is enabled
        `FAIL_UNLESS(enabled);
        // Wait for clear to happen
        ctrl_agent._wait(5);
        // Check that counter is now cleared
        get_valid(id, enabled);
        `FAIL_IF(enabled);
    `SVTEST_END

    `SVTEST(disable_all_records)
        localparam int NUM_RECORDS = 100;
        ID_T id [NUM_RECORDS];
        bit enabled;
        // Randomize
        void'(std::randomize(id));
        
        // Enable IDs
        for (int i = 0; i < NUM_RECORDS; i++) enable(id[i]);
        
        // Wait for last write to happen
        ctrl_agent._wait(5);

        // Check
        for (int i = 0; i < NUM_RECORDS; i++) begin
            get_valid(id[i], enabled);
            `FAIL_UNLESS(enabled);
        end

        // Issue control reset
        clear_all();
 
        // Check that all records are disabled
        for (int i = 0; i < NUM_RECORDS; i++) begin
            get_valid(id[i], enabled);
            `FAIL_IF(enabled);
        end
    `SVTEST_END

    `SVTEST(update_single)
        ID_T id;
        bit enabled;

        // Randomize
        void'(std::randomize(id));

        // Enable
        enable(id);
        ctrl_agent._wait(5);

        // Query from update interface
        send(id, __update_unused);   
        receive(enabled);
        `FAIL_UNLESS(enabled);

        // Check
        get_valid(id, enabled);
        `FAIL_UNLESS(enabled);
    `SVTEST_END

    `SVTEST(update_multiple)
        localparam int NUM_RECORDS = NUM_IDS/8;
        localparam int NUM_QUERIES = NUM_IDS/4;
        ID_T id [NUM_RECORDS];
        bit enabled;

        // Randomize
        void'(std::randomize(id));
        
        // Enable IDs
        for (int i = 0; i < NUM_RECORDS; i++) enable(id[i]);
        
        // Wait for last write to happen
        ctrl_agent._wait(5);

        // Submit queries from update interface
        for (int i = 0; i < NUM_QUERIES; i++) begin
            ID_T current_id;
            void'(std::randomize(current_id));
            send(current_id, __update_unused);
            receive(enabled);
            `FAIL_UNLESS_EQUAL({current_id inside id}, enabled);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

endmodule
