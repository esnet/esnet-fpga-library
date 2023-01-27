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

module state_write_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_write_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 13;
    localparam int STATE_WID = 32;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type STATE_T = bit[STATE_WID-1:0];
    localparam type DUMMY_T = bit;

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;
    logic   init_done;

    // Interfaces
    db_ctrl_intf      #(.KEY_T(ID_T), .VALUE_T(STATE_T)) ctrl_if (.clk(clk));
    db_info_intf      #() info_if ();
    state_update_intf #(.ID_T(ID_T), .UPDATE_T(STATE_T), .STATE_T(STATE_T)) update_if (.clk(clk));

    // Instantiation
    state_write #(
        .ID_T ( ID_T ),
        .STATE_T ( STATE_T )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::env env;

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, STATE_T) ctrl_agent;

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
        `FAIL_UNLESS_EQUAL(got_subtype, state_pkg::STATE_TYPE_WRITE);
        // Check size
        ctrl_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    `SVTEST(set_state)
        ID_T id;
        STATE_T state;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(state));
        // Set state
        set(id, state);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check state
        check(id, state);
    `SVTEST_END

    `SVTEST(set_clear_state)
        ID_T id;
        STATE_T exp_state;
        STATE_T got_state;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));
        // Enable state
        set(id, exp_state);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Clear state
        clear(id, got_state);
        // Check that previous value of state is returned
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
        // Wait for clear to happen
        ctrl_agent._wait(5);
        // Check that state is now cleared
        check(id, '0);
    `SVTEST_END

    `SVTEST(clear_all_state)
        ID_T id = $urandom % NUM_IDS;
        STATE_T set_state;
        // Randomize
        void'(std::randomize(set_state));
        // Enable ID
        set(id, set_state);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        check(id, set_state);
        // Issue control reset
        clear_all();
        // Check that value is now 'disabled'
        check(id, '0);
    `SVTEST_END

    `SVTEST(update_state)
        ID_T id;
        STATE_T got_state;
        STATE_T exp_state;
        int flag;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));

        // Update
        send(id, exp_state);
        receive(got_state);
        `FAIL_UNLESS_EQUAL(got_state, '0);

        // Check
        check(id, exp_state);
    `SVTEST_END

    `SVTEST(init_and_update)
        ID_T id;
        STATE_T exp_state [2];
        STATE_T got_state;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));

        // Update
        send(id, exp_state[0]);
        receive(got_state);
        `FAIL_UNLESS_EQUAL(got_state, '0);

        // Update (with initialization)
        send(id, exp_state[1], 1);
        receive(got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[0]);

        // Check value (from control plane)
        check(id, exp_state[1]);

    `SVTEST_END

    `SVTEST(back_to_back_updates)
        ID_T id;
        STATE_T exp_state [2];
        STATE_T got_state;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));

        fork
            begin
                // Send update
                send(id, exp_state[0]);
                // Send another update
                send(id, exp_state[1]);
            end
            begin
                // Receive responses
                receive(got_state);
                `FAIL_UNLESS_EQUAL(got_state, '0);
                receive(got_state);
                `FAIL_UNLESS_EQUAL(got_state, exp_state[0]);
            end
        join

        // Check
        check(id, exp_state[1]);

    `SVTEST_END

    `SVTEST(ten_consecutive_updates)
        ID_T id;
        STATE_T exp_state [10];
        STATE_T got_state;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));

        fork
            begin
                for (int i = 0; i < 10; i++) begin
                    // Send update
                    send(id, exp_state[i]);
                end
            end
            begin
                receive(got_state);
                `FAIL_UNLESS_EQUAL(got_state, '0);
                for (int i = 0; i < 9; i++) begin
                    // Receive responses
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        check(id, exp_state[9]);

    `SVTEST_END

    `SVUNIT_TESTS_END

    task send(input ID_T id, input STATE_T state, input bit init=1'b0);
        update_if.send(id, state, init);
    endtask

    task receive(output STATE_T state);
        bit __timeout;
        update_if.receive(state, __timeout);
    endtask

    task set(input ID_T id, input STATE_T state);
        automatic DUMMY_T __dummy = 1'b0;
        bit error;
        bit timeout;
        ctrl_agent.set(id, state, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while setting state for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while setting state for ID 0x%0x.",
                id
            )
        );
    endtask

    task clear(input ID_T id, output STATE_T old_state);
        DUMMY_T __dummy;
        bit error;
        bit timeout;
        ctrl_agent.unset(id, __dummy, old_state, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while clearing state for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while clearing state for ID 0x%0x.",
                id
            )
        );
    endtask

    task check(input ID_T id, input STATE_T exp_state);
        DUMMY_T __dummy;
        STATE_T got_state;
        bit error;
        bit timeout;
        ctrl_agent.get(id, __dummy, got_state, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while checking state for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while checking state for ID 0x%0x.",
                id
            )
        );
        `FAIL_UNLESS_LOG(
            got_state === exp_state,
            $sformatf(
                "Mismatch detected for ID 0x%0x. (Exp: 0x%0x, Got: 0x%0x.)",
                id, exp_state, got_state
            )
        );
    endtask

    task clear_all();
        bit error;
        bit timeout;
        ctrl_agent.clear_all(error, timeout);
        `FAIL_IF_LOG(
            error,
            "Error detected while performing RESET operation."
        );
        `FAIL_IF_LOG(
            timeout,
            "Timeout detected while performing RESET operation."
        );
    endtask

endmodule
