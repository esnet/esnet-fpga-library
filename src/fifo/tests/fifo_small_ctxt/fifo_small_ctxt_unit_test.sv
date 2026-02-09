`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fifo_small_ctxt_unit_test #(
    parameter int DEPTH = 3
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("fifo_small_ctxt_depth%0d__ut", DEPTH);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_WID = 32;
    localparam type DATA_T = bit[DATA_WID-1:0];

    localparam bit FWFT = 1; // Always true for fifo_small_ctxt

    //===================================
    // Derived parameters
    //===================================
    localparam int MEM_WR_LATENCY = 1;
    localparam int MEM_RD_LATENCY = 1;

    localparam int __DEPTH = DEPTH + 1;

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   wr_rdy;
    logic   wr;
    DATA_T  wr_data;

    logic   rd;
    logic   rd_vld;
    DATA_T  rd_data;

    logic   oflow;
    logic   uflow;

    fifo_small_ctxt    #(
        .DATA_WID ( DATA_WID ),
        .DEPTH    ( DEPTH ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 0 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    tb_env #(DATA_T, FWFT) env;

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
    assign wr_if.ready = wr_rdy;

    assign rd = rd_if.ready;
    assign rd_if.data = rd_data;
    assign rd_if.valid = rd_vld;

    clocking cb @(posedge clk);
        input uflow, oflow;
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
        //   _oflow
        //
        // Desc:
        //   verify overflow operation:
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
            `FAIL_UNLESS(cb.oflow == 0);

            // Send DEPTH transactions
            for (int i = 0; i < __DEPTH; i++) begin
                // overflow should be deasserted
                `FAIL_UNLESS(cb.oflow == 0);
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.driver.send(exp_transaction);
            end

            // After filling FIFO, oflow should remain deasserted
            @(cb);
            `FAIL_UNLESS(cb.oflow == 0);

            // Put driver in 'push' mode to allow overflow conditions
            env.driver.set_tx_mode(bus_verif_pkg::TX_MODE_PUSH);

            // Send one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", __DEPTH), __DEPTH);
            env.driver.send(exp_transaction);

            // This should trigger oflow on the same cycle
            `FAIL_UNLESS(cb.oflow == 1);

            // oflow should be deasserted on following cycle
            @(cb);
            `FAIL_UNLESS(cb.oflow == 0);

            // Empty FIFO
            for (int i = 0; i < __DEPTH; i++) begin
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.monitor.receive(got_transaction);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG(
                    match == 1, msg
                );
            end

            @(cb);

            // Send and receive one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", __DEPTH), __DEPTH);
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

endmodule : fifo_small_ctxt_unit_test



// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific FIFO configuration in a way
//  that maintains SVUnit compatibility
`define FIFO_SMALL_CTXT_UNIT_TEST(DEPTH)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  fifo_small_ctxt_unit_test #(DEPTH) test();\
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

// 1-entry FIFO (register)
module fifo_small_ctxt_depth1_unit_test;
`FIFO_SMALL_CTXT_UNIT_TEST(1)
endmodule

// 3-entry FIFO (small)
module fifo_ctxt_depth3_unit_test;
`FIFO_SMALL_CTXT_UNIT_TEST(3)
endmodule

// 8-entry FIFO (small)
module fifo_small_ctxt_depth8_unit_test;
`FIFO_SMALL_CTXT_UNIT_TEST(8)
endmodule

// 32-entry FIFO (small)
module fifo_small_ctxt_depth32_unit_test;
`FIFO_SMALL_CTXT_UNIT_TEST(32)
endmodule