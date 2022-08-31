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

module state_aging_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import state_verif_pkg::*;

    string name = "state_aging_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 16;
    localparam int TIMER_WID = 12;
    localparam int TS_PER_TICK = 3;
    localparam bit TS_CLK_DDR = 0;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;
    localparam int MAX_TIMEOUT = 2**TIMER_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type TIMER_T = bit[TIMER_WID-1:0];
    localparam type DUMMY_T = bit;

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;

    logic   init_done;

    logic   ts_clk;

    TIMER_T cfg_timeout;

    // Interfaces
    axi4l_intf                                       axil_if   ();
    db_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))       update_if (.clk(clk));
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(DUMMY_T))  ctrl_if   (.clk(clk));
    std_event_intf #(.MSG_T(ID_T))                   notify_if (.clk(clk));

    // Instantiation
    state_aging_core #(
        .ID_T        ( ID_T ),
        .TIMER_T     ( TIMER_T ),
        .TS_PER_TICK ( TS_PER_TICK ),
        .TS_CLK_DDR  ( TS_CLK_DDR )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::env env;

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Assign AXI-L clock (125MHz);
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    // Interfaces
    std_reset_intf reset_if (.clk(clk));

    // AXI-L agent
    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent;

    // Register agent
    state_aging_core_reg_agent reg_agent;

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, DUMMY_T) ctrl_agent;

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    initial axil_if.aresetn = 1'b0;
    always @(posedge axil_if.aclk or posedge srst) axil_if.aresetn <= !srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Testbench environment
        env = new;
        env.reset_vif = reset_if;

        // Instantiate register agents
        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;

        reg_agent = new("state_aging_core_reg_agent", axil_reg_agent, 0);

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
        reg_agent.idle();

        ts_clk = 0;
        cfg_timeout = 0;

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
    //   reset
    //
    // Desc: Assert reset and check that
    //       inititialization completes
    //       successfully.
    //       (Note) reset assertion/check
    //       is included in setup() task
    //===================================
    `SVTEST(reset)
    `SVTEST_END

    //===================================
    // Test:
    //   soft reset
    //
    // Desc: Assert soft reset via register
    //       interface and check that
    //       initialization completes
    //       successfully.
    //===================================
    `SVTEST(soft_reset)
        reg_agent.soft_reset();
    `SVTEST_END

    //===================================
    // Test:
    //   info check
    //
    // Desc: Read info register and check
    //       that contents match expected
    //       parameterization.
    //===================================
    `SVTEST(info)
        int size;
        int timer_bits;
        int timer_ratio;

        // Array size
        reg_agent.get_size(size);
        `FAIL_UNLESS_LOG(
            size == NUM_IDS,
            $sformatf(
                "Timer array size mismatch. Exp: %d, Got: %d.", NUM_IDS, size
            )
        );

        // Timer width
        reg_agent.get_timer_bits(timer_bits);
        `FAIL_UNLESS_LOG(
            timer_bits == TIMER_WID,
            $sformatf(
                "Timer bits mismatch. Exp: %d, Got: %d.", TIMER_WID, timer_bits
            )
        );

        // Timer clock-to-tick ratio
        reg_agent.get_timer_ratio(timer_ratio);
        `FAIL_UNLESS_LOG(
            timer_ratio == TS_PER_TICK,
            $sformatf(
                "Timer clock-to-tick ratio mismatch. Exp: %d, Got: %d.", TS_PER_TICK, timer_ratio
            )
        );
    `SVTEST_END

    `SVTEST(dbg_cnt_timer)
        int timer_cnt;
        int num_ticks = $urandom % 1000;

        // Check initial timer count
        reg_agent.get_timer_cnt(timer_cnt);
        `FAIL_UNLESS_LOG(
            timer_cnt === 0,
            $sformatf(
                "Timer count mismatch. Exp: %d, Got: %d.", 0, timer_cnt
            )
        );

        // Advance timer
        ticks(num_ticks);

        // Wait for ticks to be generated/counted
        reg_agent._wait(5);

        // Check timer
        reg_agent.get_timer_cnt(timer_cnt);
        `FAIL_UNLESS_LOG(
            timer_cnt === num_ticks,
            $sformatf(
                "Timer count mismatch. Exp: %d, Got: %d.", num_ticks, timer_cnt
            )
        );

        // Reset count
        reg_agent.clear_debug_counts();

        // Check timer
        reg_agent.get_timer_cnt(timer_cnt);
        `FAIL_UNLESS_LOG(
            timer_cnt === 0,
            $sformatf(
                "Timer count mismatch. Exp: %d, Got: %d.", 0, timer_cnt
            )
        );

    `SVTEST_END

    //===================================
    // Test:
    //   set/unset
    //
    // Desc: Enable a random set of timers,
    //       check via register interface
    //       that they are enabled and the
    //       stats track.
    //       Disable half of the timers and
    //       once again check that the correct
    //       subsets are enabled/disabled and
    //       that the stats track.
    //===================================
    `SVTEST(set_unset)
        localparam int __TEST_IDS = NUM_IDS/10;
        ID_T id_set [__TEST_IDS];
        TIMER_T timeout = $urandom % MAX_TIMEOUT;
        DUMMY_T __dummy = 0;
        bit error;
        logic found;
        int active_cnt;

        for (int i = 0; i < __TEST_IDS; i++) begin
            ID_T __id;
            do begin
                __id = $urandom % NUM_IDS;
            end while (__id inside {id_set});
            id_set[i] = __id;
        end

        // Enable records
        foreach (id_set[i]) enable(id_set[i]);

        // Check active record count
        reg_agent.get_active_cnt(active_cnt);
        `FAIL_UNLESS(active_cnt === __TEST_IDS);

        // Read back/check
        foreach (id_set[i]) begin
            ID_T __id_not_set;
            do begin
                __id_not_set = $urandom % NUM_IDS;
            end while (__id_not_set inside {id_set});
            check(id_set[i], found);
            `FAIL_UNLESS(found === 1);
            check(__id_not_set, found);
            `FAIL_UNLESS(found === 0);
        end

        // Disable half of the records
        foreach (id_set[i]) begin
            if (i % 2 == 0) _disable(id_set[i], found);
            `FAIL_UNLESS(found === 1);
        end

        // Check active record count
        reg_agent.get_active_cnt(active_cnt);
        `FAIL_UNLESS(active_cnt === __TEST_IDS/2);

        // Read back/check
        foreach (id_set[i]) begin
            check(id_set[i], found);
            if (i % 2 == 0) begin
                `FAIL_UNLESS(found === 0);
            end else begin
                `FAIL_UNLESS(found === 1);
            end
        end

        // Reset count
        reg_agent.clear_debug_counts();

        // Check active record count
        reg_agent.get_active_cnt(active_cnt);
        `FAIL_UNLESS(active_cnt === 0);

    `SVTEST_END

    //===================================
    // Test:
    //   timeout
    //
    // Desc: Enable a random counter and
    //       set a random timeout value for
    //       the aging core. Advance the
    //       timer to cause a timeout; check
    //       that the timeout notification
    //       is generated and stats track.
    //===================================
    `SVTEST(timeout)
        ID_T id = $urandom % NUM_IDS;
        TIMER_T timeout = $urandom % MAX_TIMEOUT;
        DUMMY_T __dummy = 0;
        bit error;
        logic found;
        int notify_cnt;

        // Check notification count
        reg_agent.get_notify_cnt(notify_cnt);
        `FAIL_UNLESS(notify_cnt === 0);

        // Enable ID
        enable(id);
        // Set timeout
        set_timeout(timeout);
        // Advance timer
        ticks(timeout+1);

        // Expect timeout notification
        wait(notify_if.evt);
        `FAIL_UNLESS(notify_if.msg === id);

        // Check notification count
        reg_agent.get_notify_cnt(notify_cnt);
        `FAIL_UNLESS(notify_cnt === 1);

        // Reset count
        reg_agent.clear_debug_counts();

        // Check notification count
        reg_agent.get_notify_cnt(notify_cnt);
        `FAIL_UNLESS(notify_cnt === 0);

    `SVTEST_END

    //===================================
    // Test:
    //   timer rollover
    //
    // Desc: Perform similar test as in
    //       timeout but start with a timer
    //       that is nearing saturation
    //       (rollover) to ensure consistent
    //       behaviour for that corner case.
    //===================================
    `SVTEST(timer_rollover)
        ID_T id = $urandom % NUM_IDS;
        TIMER_T timeout = 10;
        DUMMY_T __dummy = 0;
        bit error;
        logic found;
        // Advance timer
        ticks(MAX_TIMEOUT-5);
        // Enable ID
        enable(id);
        // Initialize record
        update_if.send(id);
        // Set timeout
        set_timeout(timeout);
        // Advance timer
        ticks(timeout+1);

        // Expect timeout notification
        wait(notify_if.evt);
        `FAIL_UNLESS(notify_if.msg === id);

        // Update timer
        update_if.send(id);

        // Advance timer
        ticks(timeout+1);

        // Expect timeout notification
        wait(notify_if.evt);
        `FAIL_UNLESS(notify_if.msg === id);
    `SVTEST_END

    //===================================
    // Test:
    //   timeout adjacent
    //
    // Desc: Perform similar test as in
    //       timeout but for three consecutive
    //       ids to exercise corner cases
    //       related to the row and column
    //       structure of valid array.
    //===================================
    `SVTEST(timeout_adjacent)
        ID_T id = $urandom % NUM_IDS;
        ID_T id_m1 = (id == 0) ? 2 : id-1;
        ID_T id_p1 = (id == NUM_IDS-1) ? NUM_IDS-3 : id+1;
        bit error;

        TIMER_T timeout = $urandom % MAX_TIMEOUT;
        DUMMY_T __dummy = 0;
        logic found;
        // Enable IDs
        enable(id_m1);
        enable(id);
        enable(id);
        // Set timeout
        set_timeout(timeout);
        // Advance timer
        ticks(timeout+1);

        // Expect timeout notification
        for (int i=0; i<3; i++) begin
            ID_T msg;
            wait(notify_if.evt);
            msg = notify_if.msg;
            `FAIL_UNLESS(msg inside {id_m1, id, id_p1});
        end
    `SVTEST_END

    //===================================
    // Test:
    //   keep alive
    //
    // Desc: Configure timer at random ID
    //       and configure random timeout.
    //       Advance timer to brink of timeout,
    //       then end timer 'update' to refresh
    //       stored timer; advance timer and
    //       check that no timeout notification
    //       is generated.
    //       Advance timer once again to cause
    //       timeout and check that timeout
    //       notification is generated.
    //===================================
    `SVTEST(keep_alive)
        ID_T id = $urandom % NUM_IDS;
        TIMER_T timeout = $urandom % MAX_TIMEOUT;
        DUMMY_T __dummy = 0;
        bit error;
        logic found;
        // Enable ID
        enable(id);
        // Set timeout
        set_timeout(timeout);
        // Advance timer to brink of timeout
        ticks(timeout);
        // Send update to refresh stored timestamp
        update_if.send(id);
        fork
            begin
                fork
                    begin
                        tick();
                        wait(notify_if.evt);
                        `FAIL_IF_LOG(1, "Unexpected timeout notification.");
                    end
                    begin
                        // Wait enough time that timeout notification would be received
                        update_if._wait(2*NUM_IDS*10);
                    end
                join_any
                disable fork;
            end
        join

        // Advance timer to cause timeout
        ticks(timeout+1);

        // Expect timeout notification
        wait(notify_if.evt);
        `FAIL_UNLESS(notify_if.msg === id);
    `SVTEST_END

    //===================================
    // Test:
    //   keep alive
    //
    // Desc: Implement timeout test in the
    //       presence of a significant amount
    //       of both 'control-plane' (i.e.
    //       timer activations) and 'data-plane'
    //       (i.e. timer updates) traffic.
    //       Check that the related state machines
    //       are stable during the resulting
    //       contention and that timeouts are
    //       detected and reported as expected.
    //===================================
    `SVTEST(control_contention)
        localparam int __TEST_NUM_IDS = NUM_IDS/10;
        ID_T ids [] = new[__TEST_NUM_IDS];
        TIMER_T timeout = 10000;
        DUMMY_T __dummy = 0;
        bit error;

        for (int i = 0; i < __TEST_NUM_IDS; i++) begin
            ids[i] = $urandom % NUM_IDS;
        end

        // Set timeout
        set_timeout(timeout);

        fork
            begin
                forever begin
                    ID_T __id_set = $urandom % __TEST_NUM_IDS;
                    // Enable ID
                    enable(ids[__id_set]);
                    ctrl_agent._wait($urandom % 10);
                end
            end
            begin
                forever begin
                    ID_T __id_upd = $urandom % __TEST_NUM_IDS;
                    // Send update
                    update_if.send(__id_upd);
                    update_if._wait($urandom % 6);
                end
            end
            begin
                #1ms;
            end
        join_any

        // Advance timer to cause timeout
        ticks(timeout+1);

        // Expect expiry notification
        wait(notify_if.evt);

    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task toggle_ts_clk();
        ts_clk <= ~ts_clk;
        @(posedge clk);
        if (TS_CLK_DDR == 0) begin
            ts_clk <= ~ts_clk;
            @(posedge clk);
        end
    endtask

    task advance_ts_clk(int cycles);
        repeat(cycles) toggle_ts_clk();
    endtask

    task tick();
        if (TS_PER_TICK == 0) @(posedge clk);
        else advance_ts_clk(TS_PER_TICK);
    endtask

    task ticks(input int num_ticks, input int m=1);
        repeat (num_ticks) tick();
    endtask

    task set_timeout(input TIMER_T timeout);
        cfg_timeout = timeout;
    endtask

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

endmodule
