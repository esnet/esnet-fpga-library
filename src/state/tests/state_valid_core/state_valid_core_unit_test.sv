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

module state_valid_core_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_valid_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 13;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type DUMMY_T = bit;

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;
    logic   init_done;

    // Interfaces
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(DUMMY_T)) ctrl_if (.clk(clk));

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, DUMMY_T) ctrl_agent;

    // Instantiation
    state_valid_core #(
        .ID_T ( ID_T ),
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

    `SVTEST(set)
        ID_T id = $urandom % NUM_IDS;
        DUMMY_T __dummy = 0;
        logic found;
        // Enable ID
        enable(id);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        check(id, found);
        `FAIL_UNLESS(found === 1);
    `SVTEST_END

    `SVTEST(set_unset)
        ID_T id = $urandom % NUM_IDS;
        DUMMY_T __dummy = 0;
        logic found;
        // Enable ID
        enable(id);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Disable ID
        _disable(id, found);
        // Check that previous value was 'enabled'
        `FAIL_UNLESS(found === 1);
        // Wait for write to happen
        ctrl_agent._wait(5);
        check(id, found);
        // Check that new value is 'disabled'
        `FAIL_UNLESS(found === 0);
    `SVTEST_END

    `SVTEST(set_unset_adjacent)
        ID_T id = $urandom % (NUM_IDS-2) + 1;
        DUMMY_T __dummy = 0;
        logic found;
        // Enable ID
        enable(id);
        // Enable ID-1
        enable(id-1);
        // Enable ID+1
        enable(id+1);
        // Disable ID
        _disable(id, found);
        // Check that previous value was 'enabled'
        `FAIL_UNLESS(found === 1);
        // Wait for write to happen
        ctrl_agent._wait(5);
        check(id, found);
        // Check that new value is 'disabled'
        `FAIL_UNLESS(found === 0);
        // Check that adjacent values are still enabled
        check(id-1, found);
        `FAIL_UNLESS(found === 1);
        check(id+1, found);
        `FAIL_UNLESS(found === 1);
    `SVTEST_END

    `SVTEST(_clear_all)
        ID_T id = $urandom % NUM_IDS;
        DUMMY_T __dummy = 0;
        logic found;
        // Enable ID
        enable(id);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        check(id, found);
        `FAIL_UNLESS(found === 1);
        // Issue control reset
        clear_all();
        // Check that value is now 'disabled'
        check(id, found);
        `FAIL_UNLESS(found === 0);
    `SVTEST_END

    `SVUNIT_TESTS_END

    task enable(input ID_T id);
        DUMMY_T __dummy = 0;
        bit error;
        bit timeout;
        ctrl_agent.set(id, __dummy, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while enabling ID [0x%0x].",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while enabling ID [0x%0x].",
                id
            )
        );
    endtask

    task _disable(input ID_T id, output bit found);
        DUMMY_T __dummy = 0;
        bit error;
        bit timeout;
        ctrl_agent.unset(id, found, __dummy, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while enabling ID [0x%0x].",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while enabling ID [0x%0x].",
                id
            )
        );
    endtask

    task check(input ID_T id, output bit found);
        DUMMY_T __dummy;
        bit error;
        bit timeout;
        ctrl_agent.get(id, found, __dummy, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while checking ID [0x%0x].",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while checking ID [0x%0x].",
                id
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
