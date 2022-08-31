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

module state_flags_core_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_flags_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 13;
    localparam int NUM_FLAGS = 8;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type FLAGS_T = bit[NUM_FLAGS-1:0];
    localparam type DUMMY_T = bit;

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;
    logic   init_done;

    // Interfaces
    db_ctrl_intf      #(.KEY_T(ID_T), .VALUE_T(FLAGS_T)) ctrl_if (.clk(clk));
    state_update_intf #(.ID_T(ID_T), .UPDATE_T(FLAGS_T), .DATA_T(FLAGS_T)) update_if (.clk(clk));

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, FLAGS_T) ctrl_agent;

    // Instantiation
    state_flags_core #(
        .ID_T ( ID_T ),
        .FLAGS_T ( FLAGS_T ),
        .SIM__FAST_INIT ( 0 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::env env;

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

    `SVTEST(compile)
    `SVTEST_END

    `SVTEST(set_flags)
        ID_T id;
        FLAGS_T flags;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(flags));
        // Set flags
        set(id, flags);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check flags
        check(id, flags);
    `SVTEST_END

    `SVTEST(set_clear_flags)
        ID_T id;
        FLAGS_T exp_flags;
        FLAGS_T got_flags;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_flags));
        // Enable flags
        set(id, exp_flags);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Clear flags
        clear(id, got_flags);
        // Check that previous value of flags is returned
        `FAIL_UNLESS_EQUAL(got_flags, exp_flags);
        // Wait for clear to happen
        ctrl_agent._wait(5);
        // Check that flags are now cleared
        check(id, '0);
    `SVTEST_END

    `SVTEST(clear_all_flags)
        ID_T id = $urandom % NUM_IDS;
        FLAGS_T set_flags;
        // Randomize
        void'(std::randomize(set_flags));
        // Enable ID
        set(id, set_flags);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        check(id, set_flags);
        // Issue control reset
        clear_all();
        // Check that value is now 'disabled'
        check(id, '0);
    `SVTEST_END

    `SVTEST(update_one_flag)
        ID_T exp_id;
        ID_T got_id;
        FLAGS_T got_flags;
        FLAGS_T exp_flags;
        int flag;

        // Randomize
        void'(std::randomize(exp_id));
        flag = $urandom % NUM_FLAGS;
        exp_flags = 1 << flag;

        // Update
        send(exp_id, exp_flags);
        receive(got_id, got_flags);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
        `FAIL_UNLESS_EQUAL(got_flags, '0);

        // Check
        check(exp_id, exp_flags);
    `SVTEST_END

    `SVTEST(update_all_flags)
        ID_T exp_id;
        ID_T got_id;
        FLAGS_T got_flags;

        // Randomize
        void'(std::randomize(exp_id));
        // Update all flags, one by one
        for (int i = 0; i < NUM_FLAGS; i++) begin
            send(exp_id, 1 << i);
            receive(got_id, got_flags);
            `FAIL_UNLESS_EQUAL(got_id, exp_id);
            `FAIL_UNLESS_EQUAL(got_flags, 2**i-1);
        end
    `SVTEST_END

    `SVTEST(init_and_update)
        ID_T exp_id;
        ID_T got_id;
        FLAGS_T exp_flags;
        FLAGS_T got_flags;

        // Randomize
        void'(std::randomize(exp_id));
        // Update all flags, one by one
        for (int i = 0; i < NUM_FLAGS; i++) begin
            send(exp_id, 1 << i);
            receive(got_id, got_flags);
            `FAIL_UNLESS_EQUAL(got_id, exp_id);
            `FAIL_UNLESS_EQUAL(got_flags, 2**i-1);
        end

        // Randomize
        void'(std::randomize(exp_flags));
        // Update (with initialization)
        send(exp_id, exp_flags, 1);
        receive(got_id, got_flags);
        `FAIL_UNLESS_EQUAL(got_id, exp_id);
        `FAIL_UNLESS_EQUAL(got_flags, 2**NUM_FLAGS-1);

        // Check value (from control plane)
        check(exp_id, exp_flags);

    `SVTEST_END

    `SVTEST(back_to_back_updates)
        ID_T exp_id;
        ID_T got_id;
        FLAGS_T flags [2];
        FLAGS_T got_flags;
        int flag;

        // Randomize
        void'(std::randomize(exp_id));
        flag = $urandom % NUM_FLAGS;
        flags[0] = 1 << flag;
        flags[1] = 1 << ((flag + 2) % NUM_FLAGS);

        fork
            begin
                // Send update
                send(exp_id, flags[0]);
                // Send another update
                send(exp_id, flags[1]);
            end
            begin
                ID_T got_id;
                // Receive responses
                receive(got_id, got_flags);
                `FAIL_UNLESS_EQUAL(got_id, exp_id);
                `FAIL_UNLESS_EQUAL(got_flags, '0);
                receive(got_id, got_flags);
                `FAIL_UNLESS_EQUAL(got_id, exp_id);
                `FAIL_UNLESS_EQUAL(got_flags, flags[0]);
            end
        join

        // Check
        check(exp_id, flags[0] | flags[1]);

    `SVTEST_END

    `SVTEST(ten_consecutive_updates)
        ID_T exp_id;
        ID_T got_id;
        FLAGS_T exp_flags;
        FLAGS_T got_flags;
        int flag;

        // Randomize
        void'(std::randomize(exp_id));
        flag = $urandom % NUM_FLAGS;

        fork
            begin
                for (int i = 0; i < 10; i++) begin
                    // Send update
                    send(exp_id, 1 << ((flag + i) % NUM_FLAGS));
                end
            end
            begin
                for (int i = 0; i < 10; i++) begin
                    // Receive responses
                    receive(got_id, got_flags);
                    `FAIL_UNLESS_EQUAL(got_id, exp_id);
                    exp_flags = '0;
                    for (int j = 0; j < i; j++) begin
                        exp_flags |= 1 << ((flag + j) % NUM_FLAGS);
                    end
                    `FAIL_UNLESS_EQUAL(got_flags, exp_flags);
                end
            end
        join

        // Check
        exp_flags = '0;
        for (int i = 0; i < 10; i++) begin
            exp_flags |= 1 << ((flag + i) % NUM_FLAGS);
        end
        check(exp_id, exp_flags);

    `SVTEST_END

    `SVUNIT_TESTS_END

    task send(input ID_T id, input FLAGS_T flags, input bit init=1'b0);
        update_if.send(id, flags, init);
    endtask

    task receive(output ID_T id, output FLAGS_T flags);
        bit __timeout;
        update_if.receive(id, flags, __timeout);
    endtask

    task set(input ID_T id, input FLAGS_T flags);
        automatic DUMMY_T __dummy = 1'b0;
        bit error;
        bit timeout;
        ctrl_agent.set(id, flags, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while setting flags for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while setting flags for ID 0x%0x.",
                id
            )
        );
    endtask

    task clear(input ID_T id, output FLAGS_T old_flags);
        DUMMY_T __dummy;
        bit error;
        bit timeout;
        ctrl_agent.unset(id, __dummy, old_flags, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while clearing flags for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while clearing flags for ID 0x%0x.",
                id
            )
        );
    endtask

    task check(input ID_T id, input FLAGS_T exp_flags);
        DUMMY_T __dummy;
        FLAGS_T got_flags;
        bit error;
        bit timeout;
        ctrl_agent.get(id, __dummy, got_flags, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while checking flags for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while checking flags for ID 0x%0x.",
                id
            )
        );
        `FAIL_UNLESS_LOG(
            got_flags === exp_flags,
            $sformatf(
                "Mismatch detected for ID 0x%0x. (Exp: 0x%0x, Got: 0x%0x.)",
                id, exp_flags, got_flags
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
