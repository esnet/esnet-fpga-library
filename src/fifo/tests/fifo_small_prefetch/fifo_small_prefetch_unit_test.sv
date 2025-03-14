`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fifo_small_prefetch_unit_test #(
    parameter int PIPELINE_DEPTH = 1
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("fifo_small_prefetch_depth%0d__ut", PIPELINE_DEPTH);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type DATA_T = bit[31:0];
    localparam int DEPTH = PIPELINE_DEPTH > 1 ? 2*(2**$clog2(PIPELINE_DEPTH)) : 2;

    //===================================
    // Derived parameters
    //===================================
    localparam int MEM_WR_LATENCY = 1;

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   wr;
    logic   wr_rdy;
    DATA_T  wr_data;
    logic   oflow;

    logic   rd;
    logic   rd_rdy;
    DATA_T  rd_data;

    fifo_small_prefetch  #(
        .DATA_T           ( DATA_T ),
        .PIPELINE_DEPTH   ( PIPELINE_DEPTH )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    logic __wr_rdy [PIPELINE_DEPTH];
    logic full;
    logic empty;

    tb_env #(DATA_T, 1) env;

    std_reset_intf reset_if (.clk);

    bus_intf #(DATA_T) wr_if (.clk);
    bus_intf #(DATA_T) rd_if (.clk);

    // Assign reset interface
    assign srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~srst;

    assign wr_if.srst = srst;
    assign rd_if.srst = srst;

    // Assign data interfaces
    initial __wr_rdy = '{default: 1'b1};
    always @(posedge clk) begin
        if (srst) __wr_rdy <= '{default: 1'b1};
        else begin
            for (int i = 1; i < PIPELINE_DEPTH; i++) begin
                __wr_rdy[i] <= __wr_rdy[i-1];
            end
            __wr_rdy[0] <= wr_rdy;
        end
    end
    assign wr = wr_if.valid;
    assign wr_data = wr_if.data;
    assign wr_if.ready = __wr_rdy[PIPELINE_DEPTH-1];
    assign full = !wr_if.ready;

    assign rd = rd_if.ready;
    assign rd_if.data = rd_data;
    assign rd_if.valid = rd_rdy;
    assign empty = !rd_rdy;

    clocking cb @(posedge clk);
        default input #1step output #1step;
        input full, oflow, empty;
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
            `FAIL_UNLESS(cb.empty);

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);

            // Allow write transaction to be registered by FIFO
            wr_if._wait(MEM_WR_LATENCY);

            // Check that empty is deasserted
            `FAIL_IF(cb.empty);

            // Receive transaction
            env.monitor.receive(got_transaction);

            // Check that empty is reasserted on next cycle
            @(cb);
            `FAIL_UNLESS(cb.empty);

        `SVTEST_END

        //===================================
        // Test:
        //   _full
        //
        // Desc:
        //   verify full flag:
        //   - check that full is deasserted after init
        //   - check that full is asserted when FIFO is full
        //   - check that full is deasserted after single read from FIFO
        //===================================
        `SVTEST(_full)
            // Declarations
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            exp_transaction = new("exp_transaction", exp_item);

            // Full should be deasserted immediately following init
            `FAIL_IF(cb.full);

            // Send enough transactions to trigger 'full'
            for (int i = 0; i < (DEPTH - PIPELINE_DEPTH + 1); i++) begin
                `FAIL_IF(cb.full);
                env.driver.send(exp_transaction);
            end
            // Full should be asserted after some delay
            fork
                @(cb.full);
                begin
                    repeat (DEPTH) @(cb);
                    `FAIL_IF_LOG(1, "Full not asserted");
                end
            join_any
            disable fork;

            // Receive transaction
            env.monitor.receive(got_transaction);

            // Check that full is once again deasserted (takes an extra cycle for read to take effect)
            fork
                @(!cb.full);
                begin
                    repeat (DEPTH+1) @(cb);
                    `FAIL_IF_LOG(1, "Full not deasserted");
                end
            join_any
            disable fork;

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
            `FAIL_IF(cb.full);
            `FAIL_IF(cb.oflow);

            // Send enough transactions to trigger 'full'
            for (int i = 0; i < (DEPTH - PIPELINE_DEPTH + 1); i++) begin
                // Full/overflow should be deasserted
                `FAIL_IF(cb.full);
                `FAIL_IF(cb.oflow);
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.driver.send(exp_transaction);
            end

            // After exceeding almost full depth, 'full' should be asserted (oflow should remain deasserted)
            fork
                @(cb.full);
                `FAIL_IF(cb.oflow);
                begin
                    repeat (DEPTH) @(cb);
                    `FAIL_IF_LOG(1, "Full not asserted");
                end
            join_any
            disable fork;

            // Send PIPELINE_DEPTH-1 more transactions (should be accommodated in FIFO)
            for (int i = 0; i <  PIPELINE_DEPTH-1; i++) begin
                `FAIL_IF(cb.oflow); // Overflow should stay deasserted
                exp_transaction = new($sformatf("exp_transaction_%d", DEPTH-PIPELINE_DEPTH+1+i), DEPTH-PIPELINE_DEPTH+1+i);
                env.driver.send(exp_transaction);
            end
            `FAIL_IF(cb.oflow);

            @(cb);
            `FAIL_UNLESS(cb.full);

            // Put driver in 'push' mode to force transactions despite wr_rdy being deasserted
            env.driver.set_tx_mode(bus_verif_pkg::TX_MODE_PUSH);

            // Send one more transaction
            // This should trigger oflow on the same cycle
            exp_transaction = new($sformatf("exp_transaction_%d", DEPTH), DEPTH);
            env.driver.send(exp_transaction);
            `FAIL_UNLESS(cb.oflow);

            // Full should remain asserted, oflow should be deasserted on following cycle
            @(cb);
            `FAIL_UNLESS(cb.full);
            `FAIL_IF(cb.oflow);

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
            `FAIL_IF(cb.oflow);

            wr_if._wait(1);

            env.monitor.receive(got_transaction);
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG(
                match == 1, msg
            );

        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : fifo_small_prefetch_unit_test



// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific FIFO configuration in a way
//  that maintains SVUnit compatibility
`define FIFO_SMALL_PREFETCH_UNIT_TEST(PIPELINE_DEPTH)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  fifo_small_prefetch_unit_test #(PIPELINE_DEPTH) test();\
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

// Pipeline depth 1
module fifo_small_prefetch_pldepth1_unit_test;
`FIFO_SMALL_PREFETCH_UNIT_TEST(1)
endmodule

// Pipeline depth 3
module fifo_small_prefetch_pldepth3_unit_test;
`FIFO_SMALL_PREFETCH_UNIT_TEST(3)
endmodule

// Pipeline depth 8
module fifo_small_prefetch_pldepth8_unit_test;
`FIFO_SMALL_PREFETCH_UNIT_TEST(8)
endmodule

// Pipeline depth 15
module fifo_small_prefetch_pldepth15_unit_test;
`FIFO_SMALL_PREFETCH_UNIT_TEST(15)
endmodule

