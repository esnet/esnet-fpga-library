`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 20ms

module state_timer_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_timer_ut";
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
    localparam type STATE_T = TIMER_T;
    localparam type UPDATE_T = logic; // Unused

    localparam type DUMMY_T = logic;

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;

    logic   init_done;

    logic   tick;

    // Interfaces
    db_info_intf                                        info_if   ();
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))     ctrl_if   (.clk(clk));
    state_update_intf #(.ID_T(ID_T), .STATE_T(TIMER_T)) update_if (.clk(clk));

    // Instantiation
    state_timer #(
        .ID_T    ( ID_T ),
        .TIMER_T ( TIMER_T )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::env env;

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, TIMER_T) ctrl_agent;

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
        `FAIL_UNLESS_EQUAL(got_subtype, state_pkg::STATE_TYPE_TIMER);
        // Check size
        ctrl_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    `SVTEST(single_update)
        ID_T id;
        TIMER_T got_state;
        DUMMY_T __update_unused;

        // Randomize ID
        void'(std::randomize(id));

        fork
            begin
                // Send first update to initialize counter
                send(id, __update_unused);
                // Inject delay
                _wait(6);

                // Advance timer
                _tick();

                // Send second update
                send(id, __update_unused);
            end
            begin
                // Ignore first update (timer not yet initialized)
                receive(got_state);

                // Receive second update
                receive(got_state);

                // Expect time delta between two updates to be 1 tick
                `FAIL_UNLESS_LOG(
                    got_state == 1,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 1, got_state
                    )
                );

                // Get time delta from read interface
                // (should be 0 because no ticks have occurred since last update)
                get(id, got_state);
                `FAIL_UNLESS_LOG(
                    got_state == 0,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_state
                    )
                );

            end
        join
    `SVTEST_END

    `SVTEST(single_update_zero_delay)
        ID_T id;
        TIMER_T got_state;
        DUMMY_T __update_unused;

        // Randomize ID
        void'(std::randomize(id));

        fork
            begin
                // Send first update to initialize counter
                send(id, __update_unused);
                // Inject delay
                _wait(6);

                // Send second update
                send(id, __update_unused);
            end
            begin
                // Ignore first update (timer not yet initialized)
                receive(got_state);

                // Receive second update
                receive(got_state);

                // Expect timer values to be the same (delta = 0)
                `FAIL_UNLESS_LOG(
                    got_state == 0,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_state
                    )
                );
                
                // Get time delta from read interface
                // (should be 0 because no ticks have occurred since last update)
                get(id, got_state);
                `FAIL_UNLESS_LOG(
                    got_state == 0,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_state
                    )
                );

            end
        join
    `SVTEST_END
    
    `SVTEST(multiple_update_single_id)
        ID_T id;
        TIMER_T got_state;
        DUMMY_T __update_unused;
        int exp_timer_delta = 10;
        fork
            begin
                // Send first update to initialize counter
                send(id, __update_unused);
                // Inject delay
                _wait(6);

                // Send second update
                send(id, __update_unused);
                // Inject delay
                _wait(6);

                // Advance timer
                ticks(exp_timer_delta);
                
                // Send third update after some (known) number of ticks
                send(id, __update_unused);
            end
            begin
                // Ignore first update (timer not yet initialized)
                receive(got_state);
                // Receive second update
                receive(got_state);
                // Check second update
                `FAIL_UNLESS_LOG(
                    got_state == 0,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_state
                    )
                );
                
                // Receive third update
                receive(got_state);

                // Check third update
                `FAIL_UNLESS_LOG(
                    got_state == exp_timer_delta,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, exp_timer_delta, got_state
                    )
                );

                // Get time delta from read interface
                // (should be 0 because no ticks have occurred since last update)
                get(id, got_state);
                `FAIL_UNLESS_LOG(
                    got_state == 0,
                    $sformatf(
                        "Timer delta mismatch for flow %0d. Exp: %0d, Got: %0d.",
                        id, 0, got_state
                    )
                );

            end
        join
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

    // Timer-specific tasks
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
