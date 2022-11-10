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

module state_counter_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_counter_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 14;
    localparam int COUNT_WID = 64;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type COUNT_T = bit[COUNT_WID-1:0];
    localparam type DUMMY_T = bit;

    localparam type STATE_T = COUNT_T;
    localparam type UPDATE_T = DUMMY_T; // Unused

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;
    logic   init_done;

    // Interfaces
    db_ctrl_intf      #(.KEY_T(ID_T), .VALUE_T(COUNT_T)) ctrl_if (.clk(clk));
    db_info_intf      #() info_if ();
    state_update_intf #(.ID_T(ID_T),  .STATE_T(COUNT_T)) update_if (.clk(clk));

    // Instantiation
    state_counter #(
        .ID_T ( ID_T ),
        .COUNT_T ( COUNT_T )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::env env;

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, COUNT_T) ctrl_agent;

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
        `FAIL_UNLESS_EQUAL(got_subtype, state_pkg::STATE_TYPE_COUNTER);
        // Check size
        ctrl_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    `SVTEST(set_counter)
        ID_T id;
        COUNT_T got_count;
        COUNT_T exp_count;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_count));
        // Set counter
        set(id, exp_count);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check counter
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, exp_count);
    `SVTEST_END

    `SVTEST(set_clear_counter)
        ID_T id;
        COUNT_T exp_count;
        COUNT_T got_count;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_count));
        // Enable counter
        set(id, exp_count);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Clear counter
        clear(id, got_count);
        // Check that previous value of counter is returned
        `FAIL_UNLESS_EQUAL(got_count, exp_count);
        // Wait for clear to happen
        ctrl_agent._wait(5);
        // Check that counter is now cleared
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, 0);
    `SVTEST_END

    `SVTEST(clear_all_counters)
        ID_T id;
        COUNT_T exp_count;
        COUNT_T got_count;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_count));
        // Enable ID
        set(id, exp_count);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        //check(id, exp_count);
        // Issue control reset
        clear_all();
        // Check that counter is now cleared
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, 0);
    `SVTEST_END

    `SVTEST(update_once)
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        // Update
        send(id, __update_unused);
        receive(got_count);
        `FAIL_UNLESS_EQUAL(got_count, 0);

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, 1);
    `SVTEST_END

    `SVTEST(update_multiple)
        ID_T id;
        COUNT_T got_count;
        COUNT_T exp_count;

        // Randomize
        void'(std::randomize(id));
        exp_count = $urandom % 1000;

        // Send updates
        for (int i = 0; i < exp_count; i++) begin
            send(id, __update_unused);
            receive(got_count);
            `FAIL_UNLESS_EQUAL(got_count, i);
        end

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, exp_count);
    `SVTEST_END

    `SVTEST(init_and_update)
        ID_T id;
        COUNT_T exp_count;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));
        exp_count = $urandom % 1000;

        // Send updates
        for (int i = 0; i < exp_count; i++) begin
            send(id, __update_unused);
            receive(got_count);
            `FAIL_UNLESS_EQUAL(got_count, i);
        end

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, exp_count);

        // Send update with initialization
        send(id, __update_unused, 1);
        receive(got_count);
        `FAIL_UNLESS_EQUAL(got_count, exp_count);

        // Randomize
        exp_count = $urandom % 1000;

        // Send more updates
        for (int i = 1; i < exp_count; i++) begin
            send(id, __update_unused);
            receive(got_count);
            `FAIL_UNLESS_EQUAL(got_count, i);
        end

        // Check final value (from control plane)
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, exp_count);

    `SVTEST_END

    `SVTEST(back_to_back_updates)
        const int NUM_UPDATES = 2;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVTEST(three_consecutive_updates)
        const int NUM_UPDATES = 3;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVTEST(four_consecutive_updates)
        const int NUM_UPDATES = 4;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVTEST(five_consecutive_updates)
        const int NUM_UPDATES = 5;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVTEST(ten_consecutive_updates)
        const int NUM_UPDATES = 10;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVTEST(fifty_consecutive_updates)
        const int NUM_UPDATES = 50;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVTEST(one_hundred_consecutive_updates)
        const int NUM_UPDATES = 100;
        ID_T id;
        COUNT_T got_count;

        // Randomize
        void'(std::randomize(id));

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, __update_unused);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_count);
                    `FAIL_UNLESS_EQUAL(got_count, i);
                end
            end
        join

        // Check
        get(id, got_count);
        `FAIL_UNLESS_EQUAL(got_count, NUM_UPDATES);

    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

endmodule
