`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fifo_small_unit_test #(
    parameter int DEPTH = 3
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("fifo_small_depth%0d__ut", DEPTH);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  DATA_WID = 32;
    localparam type DATA_T = bit[DATA_WID-1:0];

    //===================================
    // Derived parameters
    //===================================
    localparam int MEM_WR_LATENCY = 1;

    localparam int CNT_WID = $clog2(DEPTH+1);

    //===================================
    // Typedefs
    //===================================
    typedef logic [CNT_WID-1:0] count_t;

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   wr;
    DATA_T  wr_data;

    logic   rd;
    DATA_T  rd_data;

    logic   [CNT_WID-1:0] count;
    logic   full;
    logic   oflow;
    logic   empty;
    logic   uflow;

    fifo_small   #(
        .DATA_WID ( DATA_WID ),
        .DEPTH    ( DEPTH )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    tb_env #(DATA_T, 1) env;

    std_reset_intf reset_if (.clk);

    bus_intf #(DATA_WID) wr_if (.clk);
    bus_intf #(DATA_WID) rd_if (.clk);

    // Assign reset interface
    assign srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~srst;

    // Assign data interfaces
    assign wr = wr_if.valid;
    assign wr_data = wr_if.data;
    assign wr_if.ready = !full;

    assign rd = rd_if.ready;
    assign rd_if.data = rd_data;
    assign rd_if.valid = !empty;

    clocking cb @(posedge clk);
        output wr, wr_data, rd;
        input rd_data, empty, full, count, uflow, oflow;
    endclocking

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create testbench environment
        env = new("tb_env", reset_if, wr_if, rd_if);
        env.build();

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */
        env.reset();
        env.idle();

        env.reset_dut();

        #50ns;
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
        // Desc:
        //   Reset and
        //===================================
        `SVTEST(reset)
        `SVTEST_END
        //===================================
        // Test:
        //   single_item
        //
        // Desc:
        //   send one item to FIFO, read it
        //   it out and compare
        //===================================
        `SVTEST(single_item)
            // Declarations
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;
            bit match;
            string msg;

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);

            @(cb);

            // Receive transaction
            env.monitor.receive(got_transaction);

            // Compare transactions
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG(
                match == 1, msg
            );

        `SVTEST_END

        //===================================
        // Test:
        //   _empty
        //
        // Desc:
        //   verify empty flag:
        //   - check that empty is asserted after init
        //   - check that empty is deasserted after single write to FIFO
        //   - check that empty is reasserted after read from FIFO
        //===================================
        `SVTEST(_empty)
            // Declarations
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Empty should be asserted immediately following init
            `FAIL_UNLESS(cb.empty == 1);

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);

            // Allow write transaction to be registered by FIFO
            wr_if._wait(MEM_WR_LATENCY+1);

            // Check that empty is deasserted
            repeat (2) @(cb);
            `FAIL_UNLESS(cb.empty == 0);

            // Receive transaction
            env.monitor.receive(got_transaction);

            // Check that empty is reasserted on next cycle
            @(cb);
            `FAIL_UNLESS(cb.empty == 1);

        `SVTEST_END

        //===================================
        // Test:
        //   _full
        //
        // Desc:
        //   verify full flag:
        //   - check that full is deasserted after init
        //   - check that full is asserted after NUM_ITEMS write to FIFO
        //   - check that full is deasserted after single read from FIFO
        //===================================
        `SVTEST(_full)
            // Declarations
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            exp_transaction = new("exp_transaction", exp_item);

            // Full should be deasserted immediately following init
            `FAIL_UNLESS(cb.full == 0);

            // Send DEPTH transactions
            for (int i = 0; i < DEPTH; i++) begin
                `FAIL_UNLESS(cb.full == 0);
                env.driver.send(exp_transaction);
            end

            // Full should be asserted on next cycle
            @(cb);
            `FAIL_UNLESS(cb.full == 1);

            // Receive transaction
            env.monitor.receive(got_transaction);

            // Check that full is once again deasserted (takes an extra cycle for read to take effect)
            repeat (2) @(cb);
            `FAIL_UNLESS(cb.full == 0);

        `SVTEST_END

        //===================================
        // Test:
        //   _oflow
        //
        // Desc:
        //   verify overflow operation:
        //   - check that full is deasserted after init
        //   - check that full is asserted after NUM_ITEMS write to FIFO
        //   - write into fifo while full, check that oflow flag is asserted
        //   - read from fifo, check data integrity
        //   - write/read from fifo, check data integrity
        //===================================
        `SVTEST(_oflow)
            // Declarations
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            bit match;
            string msg;

            // Overflow should be deasserted immediately following init
            `FAIL_UNLESS(cb.full == 0);
            `FAIL_UNLESS(cb.oflow == 0);

            // Send DEPTH transactions
            for (int i = 0; i < DEPTH; i++) begin
                // Full/overflow should be deasserted
                `FAIL_UNLESS(cb.full == 0);
                `FAIL_UNLESS(cb.oflow == 0);
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.driver.send(exp_transaction);
            end

            // After filling FIFO, full should be asserted (oflow should remain deasserted)
            @(cb);
            `FAIL_UNLESS(cb.full == 1);
            `FAIL_UNLESS(cb.oflow == 0);

            // Put driver in 'push' mode to allow overflow conditions
            env.driver.set_tx_mode(bus_verif_pkg::TX_MODE_PUSH);

            // Send one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", DEPTH), DEPTH);
            env.driver.send(exp_transaction);

            // This should trigger oflow on the same cycle
            `FAIL_UNLESS(cb.oflow == 1);

            // Full should remain asserted, oflow should be deasserted on following cycle
            @(cb);
            `FAIL_UNLESS(cb.full == 1);
            `FAIL_UNLESS(cb.oflow == 0);

            // Empty FIFO
            for (int i = 0; i < DEPTH; i++) begin
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.monitor.receive(got_transaction);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG(
                    match == 1, msg
                );
            end

            @(cb);

            // Send and receive one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", DEPTH), DEPTH);
            env.driver.send(exp_transaction);
            `FAIL_UNLESS(cb.oflow == 0);

            wr_if._wait(1);

            env.monitor.receive(got_transaction);
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG(
                match == 1, msg
            );

        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : fifo_small_unit_test



// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific FIFO configuration in a way
//  that maintains SVUnit compatibility
`define FIFO_SMALL_UNIT_TEST(DEPTH)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  fifo_small_unit_test #(DEPTH) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  function void __register_tests();\
    test.__register_tests();\
  endfunction\
  task run();\
    test.run();\
  endtask

// 2-entry FIFO
module fifo_small_depth2_unit_test;
`FIFO_SMALL_UNIT_TEST(2)
endmodule

// 3-entry FIFO
module fifo_small_depth3_unit_test;
`FIFO_SMALL_UNIT_TEST(3)
endmodule

// 8-entry FIFO
module fifo_small_depth8_unit_test;
`FIFO_SMALL_UNIT_TEST(8)
endmodule

// 32-entry FIFO
module fifo_small_depth32_unit_test;
`FIFO_SMALL_UNIT_TEST(32)
endmodule

// 63-entry FIFO
module fifo_sync_std_depth63_unit_test;
`FIFO_SMALL_UNIT_TEST(63)
endmodule

// 64-entry FIFO
module fifo_sync_std_depth64_unit_test;
`FIFO_SMALL_UNIT_TEST(64)
endmodule
