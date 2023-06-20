`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 20ms

module timer_expiry_unit_test;
    import svunit_pkg::svunit_testcase;
    import timer_verif_pkg::*;

    string name = "timer_expiry_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int TIMER_WID = 12;
    localparam int TIMER_MAX_VALUE = 2**TIMER_WID-1;

    // Typedefs
    localparam type TIMER_T = bit[TIMER_WID-1:0];

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;

    logic   en;
    logic   reset;
    logic   freeze;

    logic   tick;

    TIMER_T timer_in;
    logic   expired;

    TIMER_T timer_out;

    // Interfaces
    axi4l_intf axil_if ();

    // Instantiation
    timer_expiry #(
        .TIMER_T  ( TIMER_T )
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
    timer_expiry_reg_agent reg_agent;

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = !srst;

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

        // Instantiate register agent
        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;

        reg_agent = new("timer_expiry_reg_agent", axil_reg_agent, 0);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        reg_agent.idle();

        tick = 1'b0;
        en = 1'b1;
        reset = 1'b0;
        freeze = 1'b0;

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
        int timer_bits;
        // Check timer width
        reg_agent.get_timer_bits(timer_bits);
        `FAIL_UNLESS_LOG(
            timer_bits == TIMER_WID,
            $sformatf(
                "Timer bits mismatch. Exp: %d, Got: %d.", TIMER_WID, timer_bits
            )
        );
    `SVTEST_END

    //===================================
    // Test:
    //   timer check
    //
    // Desc: Read debug register to retrieve
    //       current value of timer; check
    //       that it matches expected timer
    //       value.
    //===================================
    `SVTEST(dbg_timer)
        int __timer;
        int num_ticks = $urandom % 1000;
        // Check initial timer count
        reg_agent.get_timer_value(__timer);
        `FAIL_UNLESS_LOG(
            __timer === 0,
            $sformatf(
                "Timer count mismatch. Exp: %d, Got: %d.", 0, __timer
            )
        );
        // Advance timer
        ticks(num_ticks);
        // Wait for ticks to be generated/counted
        reg_agent._wait(5);
        // Check timer
        reg_agent.get_timer_value(__timer);
        `FAIL_UNLESS_LOG(
            __timer === num_ticks,
            $sformatf(
                "Timer count mismatch. Exp: %d, Got: %d.", num_ticks, __timer
            )
        );
    `SVTEST_END

    `SVTEST(cfg_timeout)
        int exp_cfg_timeout = 0;
        int got_cfg_timeout;
        // Randomize config value to non-zero value
        do begin
            void'(std::randomize(exp_cfg_timeout));
        end while (exp_cfg_timeout == 0);
        // Configure timeout value via register write
        reg_agent.set_timeout(exp_cfg_timeout);
        // Read back timeout value
        reg_agent.get_timeout(got_cfg_timeout);
        `FAIL_UNLESS_EQUAL(got_cfg_timeout, exp_cfg_timeout);
    `SVTEST_END

    `SVTEST(timer_output)
        TIMER_T exp_timer;
        // Randomize timer value
        void'(std::randomize(exp_timer));
        // Initialize timer
        ticks(exp_timer);
        @(posedge clk);
        // Check that timer output value matches expected timer state
        `FAIL_UNLESS_EQUAL(timer_out, exp_timer);
    `SVTEST_END

    `SVTEST(timeout_wrap)
        int cfg_timeout;
        TIMER_T timer;
        TIMER_T exp_threshold;
        cfg_timeout = $urandom_range(51, 100);
        // Configure timeout value via register write
        reg_agent.set_timeout(cfg_timeout);
        // Set timer initial state
        timer = $urandom_range(0, 50);
        exp_threshold = timer - cfg_timeout;
        ticks(timer);
        @(posedge clk);
        timer_in = timer;
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = exp_threshold + 1;
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = exp_threshold;
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = exp_threshold - 1;
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = '0;
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = '1;
        @(posedge clk);
        `FAIL_IF(expired);
    `SVTEST_END

    `SVTEST(timer_rollover)
        localparam TIMER_SET_VALUE = TIMER_MAX_VALUE;
        reg_agent.set_timeout(10);
        // Set timer to max value
        ticks(TIMER_MAX_VALUE);
        @(posedge clk);
        timer_in = TIMER_MAX_VALUE-1;
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = TIMER_MAX_VALUE;
        @(posedge clk);
        `FAIL_IF(expired);
        ticks(1);
        @(posedge clk);
        `FAIL_IF(expired);
        ticks(8);
        @(posedge clk);
        `FAIL_IF(expired);
        ticks(1);
        @(posedge clk);
        `FAIL_UNLESS(expired);
    `SVTEST_END

    `SVTEST(timer_zero)
        // Test expiry around zero time value
        // (boundary between positive/negative
        //  value representations)
        localparam int TIMER_SET_VALUE = 0;
        reg_agent.set_timeout(10);
        // Set timer to set point
        ticks(TIMER_SET_VALUE);
        @(posedge clk);
        timer_in = (TIMER_SET_VALUE-1);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE+1);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE-9);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE-10);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        // Set expiry threshold at set point
        ticks(10);
        timer_in = (TIMER_SET_VALUE-1);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = (TIMER_SET_VALUE);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = (TIMER_SET_VALUE+1);
        @(posedge clk);
        `FAIL_IF(expired);
    `SVTEST_END

    `SVTEST(timer_max)
        // Test expiry around zero time value
        // (boundary between positive/negative
        //  value representations)
        localparam int TIMER_SET_VALUE = TIMER_MAX_VALUE;
        reg_agent.set_timeout(10);
        // Set timer to set point
        ticks(TIMER_SET_VALUE);
        @(posedge clk);
        timer_in = (TIMER_SET_VALUE-1);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE+1);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE-9);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE-10);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        // Set expiry threshold at set point
        ticks(10);
        timer_in = (TIMER_SET_VALUE-1);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = (TIMER_SET_VALUE);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = (TIMER_SET_VALUE+1);
        @(posedge clk);
        `FAIL_IF(expired);
    `SVTEST_END


    `SVTEST(timer_midpoint)
        // Test expiry around midpoint of timer range
        // (boundary between positive/negative
        //  value representations)
        localparam int TIMER_SET_VALUE = (TIMER_MAX_VALUE + 1)/2;
        reg_agent.set_timeout(10);
        // Set timer to set point
        ticks(TIMER_SET_VALUE);
        @(posedge clk);
        timer_in = (TIMER_SET_VALUE-1);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE+1);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE-9);
        @(posedge clk);
        `FAIL_IF(expired);
        timer_in = (TIMER_SET_VALUE-10);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        // Set expiry threshold at set point
        ticks(10);
        timer_in = (TIMER_SET_VALUE-1);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = (TIMER_SET_VALUE);
        @(posedge clk);
        `FAIL_UNLESS(expired);
        timer_in = (TIMER_SET_VALUE+1);
        @(posedge clk);
        `FAIL_IF(expired);
    `SVTEST_END

    `SVTEST(timeout)
        localparam int NUM_TRIALS = 1000;
        int cfg_timeout;
        TIMER_T timer;
        TIMER_T exp_threshold;
        bit exp_expiry;
        cfg_timeout = $urandom() % 1000;
        // Configure timeout value via register write
        reg_agent.set_timeout(cfg_timeout);
        // Set timer initial state
        void'(std::randomize(timer));
        ticks(timer);
        @(posedge clk);
        exp_threshold = timer - cfg_timeout;
        for (int i = 0; i < NUM_TRIALS; i++) begin
            timer_in = $urandom_range(timer-2000, timer);
            @(posedge clk);
            if (timer - timer_in >= cfg_timeout) exp_expiry = 1'b1;
            else                                 exp_expiry = 1'b0;
            `FAIL_UNLESS_EQUAL(expired, exp_expiry);
        end
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

    task ticks(input int num_ticks);
        repeat (num_ticks) _tick();
        @(posedge clk);
    endtask

endmodule
