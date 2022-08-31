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
`define SVUNIT_TIMEOUT 20ms

module state_timer_core_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_timer_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 16;
    localparam int TIMER_WID = 18;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type TIMER_T = bit[TIMER_WID-1:0];

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;

    logic   init_done;

    logic   tick;

    // Interfaces
    db_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T)) update_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T)) read_if   (.clk(clk));

    // Instantiation
    state_timer_core #(
        .ID_T    ( ID_T ),
        .TIMER_T ( TIMER_T ),
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
        env = new;
        env.reset_vif = reset_if;

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        read_if.idle();
        update_if.idle();

        tick = 0;

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

    `SVTEST(reset)
    `SVTEST_END

    `SVTEST(single_update)
        ID_T id = 'hAB;
        TIMER_T exp_ts_delta = 1;
        TIMER_T got_ts_delta;
        logic __found_unused;
        logic __timeout_unused;
        bit error;
        bit __xid_unused;
        fork
            begin
                // Send first update to initialize counter
                update_if.send(id);
                // Inject delay
                update_if._wait(5);

                // Advance timer
                _tick();

                // Send second update
                update_if.send(id);
            end
            begin
                // Ignore first update (timer not yet initialized)
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);

                // Receive second update
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);

                // Expect time delta between two updates to be at most 1 tick
                `FAIL_UNLESS_LOG(
                    got_ts_delta == exp_ts_delta,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, exp_ts_delta, got_ts_delta
                    )
                );

                // Get time delta from read interface
                // (should be 0 because no ticks have occurred since last update)
                read_if.query(id, '0, __found_unused, got_ts_delta, error, __timeout_unused, 0);
                `FAIL_UNLESS_LOG(
                    got_ts_delta == 0,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_ts_delta
                    )
                );

            end
        join
    `SVTEST_END

    `SVTEST(single_update_zero_delay)
        ID_T id = 'hAB;
        TIMER_T exp_ts_delta = 0;
        TIMER_T got_ts_delta;
        logic __found_unused;
        logic __timeout_unused;
        bit error;
        bit __xid_unused;
        fork
            begin
                // Send first update to initialize counter
                update_if.send(id);
                // Inject delay
                update_if._wait(5);

                // Send second update
                update_if.send(id);
            end
            begin
                // Ignore first update (timer not yet initialized)
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);
                // Receive second update
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);

                // Expect time delta between two updates to be at most 1 tick
                `FAIL_UNLESS_LOG(
                    got_ts_delta == exp_ts_delta,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, exp_ts_delta, got_ts_delta
                    )
                );

                // Get time delta from read interface
                // (should be 0 because no ticks have occurred since last update)
                read_if.query(id, '0, __found_unused, got_ts_delta, error, __timeout_unused, 0);
                `FAIL_UNLESS_LOG(
                    got_ts_delta == 0,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_ts_delta
                    )
                );
            end
        join
    `SVTEST_END

    `SVTEST(multiple_update_single_id)
        ID_T id = 'hAB;
        TIMER_T got_ts_delta;
        int exp_ts_delta = 10;
        logic __found_unused;
        logic __timeout_unused;
        bit error;
        bit __xid_unused;
        fork
            begin
                // Send first update to initialize counter
                update_if.send(id);
                // Inject delay
                update_if._wait(5);

                // Send second update
                update_if.send(id);
                // Inject delay
                update_if._wait(5);

                // Advance timer
                ticks(exp_ts_delta);
                
                // Send third update after some (known) number of ticks
                update_if.send(id);
            end
            begin
                // Ignore first update (timer not yet initialized)
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);
                // Receive second update
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);
                // Check second update
                `FAIL_UNLESS_LOG(
                    got_ts_delta == 0,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_ts_delta
                    )
                );
                
                // Receive third update
                update_if.receive(__found_unused, got_ts_delta, error, __xid_unused);

                // Check third update
                `FAIL_UNLESS_LOG(
                    got_ts_delta == exp_ts_delta,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, exp_ts_delta, got_ts_delta
                    )
                );

                // Get time delta from read interface
                // (should be 0 because no ticks have occurred since last update)
                read_if.query(id, '0, __found_unused, got_ts_delta, error, __timeout_unused, 0);
                `FAIL_UNLESS_LOG(
                    got_ts_delta == 0,
                    $sformatf(
                        "TS delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_ts_delta
                    )
                );

            end
        join
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task _tick();
        tick <= 1'b1;
        @(posedge clk);
        tick <= 1'b0;
    endtask

    task ticks(input int num_ticks, input int m=1);
        for (int i = 0; i < num_ticks; i++) begin
            _tick();
            repeat (m-1) @(posedge clk);
        end
    endtask

endmodule
