`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fifo_async_unit_test #(
    parameter int DEPTH = 3,
    parameter bit FWFT = 1'b0
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;

    localparam string type_string = FWFT ? "fwft" : "std";

    // Synthesize testcase name from parameters
    string name = $sformatf("fifo_async_%s_depth%0d__ut", type_string, DEPTH);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type DATA_T = bit[31:0];

    //===================================
    // Derived parameters
    //===================================
    localparam int MEM_WR_LATENCY = DUT.i_fifo_core.MEM_WR_LATENCY;
    localparam int MEM_RD_LATENCY = DUT.i_fifo_core.MEM_RD_LATENCY;

    // Adjust 'effective' FIFO depth to account for optional FWFT buffer
    localparam int __DEPTH = FWFT ? DEPTH + 1 : DEPTH;

    localparam int CNT_WID = $clog2(__DEPTH+1);

    //===================================
    // Typedefs
    //===================================
    typedef logic [CNT_WID-1:0] count_t;

    //===================================
    // DUT
    //===================================

    logic   wr_clk;
    logic   wr_srst;
    logic   wr_rdy;
    logic   wr;
    DATA_T  wr_data;

    logic   rd_clk;
    logic   rd_srst;
    logic   rd;
    logic   rd_ack;
    DATA_T  rd_data;

    logic   full;
    logic   empty;
    count_t wr_count;
    count_t rd_count;

    logic   oflow;
    logic   uflow;

    localparam FIFO_ASYNC_LATENCY = 6;  // 1 (bin2gray) + 3 (sync) + 1 (gray2bin) + 1 (phase delta)

    fifo_async #(
        .DATA_T  ( DATA_T ),
        .DEPTH   ( DEPTH ),
        .FWFT    ( FWFT )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    tb_env #(DATA_T, FWFT) env;

    std_reset_intf reset_if (.clk(wr_clk));

    std_raw_intf #(DATA_T) wr_if (.clk(wr_clk));
    std_raw_intf #(DATA_T) rd_if (.clk(rd_clk));

    // Assign reset interface
    assign wr_srst = reset_if.reset;
    assign rd_srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge wr_clk) reset_if.ready <= ~wr_srst;

    // Assign data interfaces
    assign wr = wr_if.valid;
    assign wr_data = wr_if.data;
    assign wr_if.ready = wr_rdy;

    assign rd = rd_if.ready;
    assign rd_if.data = rd_data;
    assign rd_if.valid = rd_ack;

    clocking cb_wr @(posedge wr_clk);
        default input #1step output #1step;
        input full, oflow;
    endclocking

    clocking cb_rd @(posedge rd_clk);
        default input #1step output #1step;
        input empty, uflow;
    endclocking

    // Generate clocks
    real clk_ratio     = 1;
    real wr_clk_period = 5;
    real rd_clk_period = 5;

    initial wr_clk = 1'b0;
    always #(wr_clk_period) wr_clk = ~wr_clk;

    initial rd_clk = 1'b0;
    always #(rd_clk_period) rd_clk = ~rd_clk;


    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create testbench environment
        env = new("tb_env", reset_if, wr_if, rd_if);
        env.connect();

        env.set_debug_level(0);

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */
        env.reset();

        // Set clk frequencies
        clk_ratio = 1; rd_clk_period = 5; wr_clk_period = 5;

        env.idle();
        env.reset_dut();

        env.driver._wait(10);
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

    bit match;
    string msg;

    `SVUNIT_TESTS_BEGIN
        //===================================
        // Test:
        //   reset
        //
        // Desc:
        //
        //===================================
        `SVTEST(reset)
        `SVTEST_END


        //===================================
        // Test:
        //   single_item
        //
        // Desc:
        //   - sends one item into FIFO
        //   - reads item out and compares to expected
        //
        //===================================
        `SVTEST(single_item)
            // Declarations
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);

            // Receive transaction
            if (!FWFT) wait(!empty);
            env.monitor.receive(got_transaction);

            // Compare transactions
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG( match == 1, msg );
        `SVTEST_END


        //===================================
        // Test:
        //   _fast_to_slow_write_read
        //
        // Desc:
        //   - wr_clk runs faster than rd_clk (scaled by 'clk_ratio').
        //   - Cycles through all fifo entries (twice).
        //   - Each cycle writes, reads, and compares the returned value.
        //
        //===================================
        `SVTEST(_fast_to_slow_write_read)
            // Declarations
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Set clk frequencies
            clk_ratio = 2.25;  rd_clk_period = clk_ratio * wr_clk_period;

            // Send, receive and compare a FIFO entry.  Repeat 2 x DEPTH times.
            for (int i = 0; i < 2 * __DEPTH; i++) begin
                exp_transaction = new("exp_transaction", i);
                env.driver.send(exp_transaction);
                @(cb_wr);

                if (!FWFT) wait(!empty);
                env.monitor.receive(got_transaction);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG( match == 1, msg );
                @(cb_rd);
            end
        `SVTEST_END


        //===================================
        // Test:
        //   _fast_to_slow_fill_empty
        //
        // Desc:
        //   - wr_clk runs faster than rd_clk (scaled by 'clk_ratio').
        //   - Fills all fifo entries with unqique values.
        //   - Then reads them all back and compares each value.
        //
        //===================================
        `SVTEST(_fast_to_slow_fill_empty)
            // Declarations
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Set clk frequencies
            clk_ratio = 1.75;  rd_clk_period = clk_ratio * wr_clk_period;

            // Fill all FIFO entries
            for (int i = 0; i < __DEPTH; i++) begin
                exp_transaction = new("exp_transaction", i);
                env.driver.send(exp_transaction);
            end

            // Add one more (overflow) event, after configuring
            // driver in 'push' mode to allow overflow condition
            env.driver.set_tx_mode(std_verif_pkg::TX_MODE_PUSH);
            exp_transaction = new("exp_transaction", __DEPTH);
            env.driver.send(exp_transaction);

            // Read back all FIFO entries and compare.
            for (int i = 0; i < (__DEPTH); i++) begin
                exp_transaction = new("exp_transaction", i);
                if (!FWFT) wait(!empty);
                env.monitor.receive(got_transaction);

                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG( match == 1, msg );
            end
        `SVTEST_END


        //===================================
        // Test:
        //   _slow_to_fast_write_read
        //
        // Desc:
        //   - wr_clk runs slower than rd_clk (scaled by 'clk_ratio').
        //   - Cycles through all fifo entries (twice).
        //   - Each cycle writes, reads, and compares the returned value.
        //
        //===================================
        `SVTEST(_slow_to_fast_write_read)
            // Declarations
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Set clk frequencies
            clk_ratio = 2.75;  wr_clk_period = clk_ratio * rd_clk_period;

            // Send, receive and compare a FIFO entry.  Repeat 2 x DEPTH times.
            for (int i = 0; i < 2 * __DEPTH; i++) begin
                exp_transaction = new("exp_transaction", i);
                env.driver.send(exp_transaction);

                if (!FWFT) wait(!empty);
                env.monitor.receive(got_transaction);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG( match == 1, msg );
            end
        `SVTEST_END


        //===================================
        // Test:
        //   _slow_to_fast_fill_empty
        //
        // Desc:
        //   - wr_clk runs slower than rd_clk (scaled by 'clk_ratio').
        //   - Fills all fifo entries with unique values.
        //   - Then reads them all back and compares each value.
        //
        //===================================
        `SVTEST(_slow_to_fast_fill_empty)
            // Declarations
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Set clk frequencies
            clk_ratio = FWFT ? 1.1 : 2.5; wr_clk_period = clk_ratio * rd_clk_period;

            // Fill all FIFO entries
            for (int i = 0; i < __DEPTH; i++) begin
                exp_transaction = new("exp_transaction", i);
                env.driver.send(exp_transaction);
            end

            // Add one more (overflow) event, after configuring
            // driver in 'push' mode to allow overflow condition
            env.driver.set_tx_mode(std_verif_pkg::TX_MODE_PUSH);
            exp_transaction = new("exp_transaction", __DEPTH);
            env.driver.send(exp_transaction);
            @(cb_wr);

            // Read back all FIFO entries and compare.
            for (int i = 0; i < __DEPTH; i++) begin
                exp_transaction = new("exp_transaction", i);
                if (!FWFT) wait(!empty);
                env.monitor.receive(got_transaction);

                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG( match == 1, msg );
            end
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
            `FAIL_UNLESS(cb_rd.empty == 1);

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);
            @(cb_wr);

            // Check that empty is deasserted immediately (once write transaction is registered by FIFO)
            env.monitor._wait(FIFO_ASYNC_LATENCY);
            if (FWFT) env.monitor._wait(MEM_RD_LATENCY);
            `FAIL_UNLESS(cb_rd.empty == 0);

            // Receive transaction
            env.monitor.receive(got_transaction);

            // Check that empty is reasserted on next cycle
            @(cb_rd);
            `FAIL_UNLESS(cb_rd.empty == 1);
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
            `FAIL_UNLESS(cb_wr.full == 0);

            // Send DEPTH transactions
            for (int i = 0; i < __DEPTH; i++) begin
                if (FWFT && cb_wr.full) repeat (MEM_RD_LATENCY) @(cb_wr);
                `FAIL_UNLESS(cb_wr.full == 0);
                env.driver.send(exp_transaction);
            end

            // For FWFT FIFOs, send up to MEM_RD_LATENCY-1 additional transactions
            // to account for possiblity of additional entries in read pipeline
            if (FWFT) begin
                for (int i = 0; i < MEM_RD_LATENCY-1; i++) begin
                    if (full) repeat (MEM_RD_LATENCY) @(cb_wr);
                    if (full) break;
                    env.driver.send(exp_transaction);
                end
            end

            // Full should be asserted
            @(cb_wr);
            `FAIL_UNLESS(cb_wr.full == 1);

            // Receive single transaction
            if (!FWFT) wait (!empty);
            env.monitor.receive(got_transaction);
            @(cb_rd);

            // Allow read transaction to be registered by FIFO
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check that full is once again deasserted
            `FAIL_UNLESS(cb_wr.full == 0);
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
            int entries = 0;

            // Overflow should be deasserted immediately following init
            `FAIL_UNLESS(cb_wr.full == 0);
            `FAIL_UNLESS(cb_wr.oflow == 0);

            // Send DEPTH transactions
            for (int i = 0; i < __DEPTH; i++) begin
                if (FWFT && cb_wr.full) repeat (MEM_RD_LATENCY) @(cb_wr);
                // Full/overflow should be deasserted
                `FAIL_UNLESS(cb_wr.full == 0);
                `FAIL_UNLESS(cb_wr.oflow == 0);
                exp_transaction = new($sformatf("exp_transaction_%d", entries), entries);
                env.driver.send(exp_transaction);
                entries++;
            end

            // For FWFT FIFOs, send up to MEM_RD_LATENCY-1 additional transactions
            // to account for possiblity of additional entries in read pipeline
            if (FWFT) begin
                for (int i = 0; i < MEM_RD_LATENCY-1; i++) begin
                    if (full) repeat (MEM_RD_LATENCY) @(cb_wr);
                    if (full) break;
                    exp_transaction = new($sformatf("exp_transaction_%d", entries), entries);
                    env.driver.send(exp_transaction);
                    entries++;
                end
            end

            // After filling FIFO, full should be asserted (oflow should remain deasserted)
            @(cb_wr);
            `FAIL_UNLESS(cb_wr.full == 1);
            `FAIL_UNLESS(cb_wr.oflow == 0);

            // Send one more transaction (after putting driver in push mode to allow overflows)
            env.driver.set_tx_mode(std_verif_pkg::TX_MODE_PUSH);
            exp_transaction = new($sformatf("exp_transaction_%d", entries), entries);
            env.driver.send(exp_transaction);

            // This should trigger oflow on the same cycle
            `FAIL_UNLESS(cb_wr.oflow == 1);

            // Full should remain asserted, oflow should be deasserted on following cycle
            @(cb_wr);
            `FAIL_UNLESS(cb_wr.full == 1);
            `FAIL_UNLESS(cb_wr.oflow == 0);

            // Empty FIFO
            for (int i = 0; i < entries; i++) begin
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.monitor.receive(got_transaction);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG(
                    match == 1, msg
                );
            end

            // Send and receive one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", entries+1), entries+1);
            env.driver.send(exp_transaction);
            `FAIL_UNLESS(cb_wr.oflow == 0);

            if (!FWFT) wait (!empty);
            env.monitor.receive(got_transaction);
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG(
                match == 1, msg
            );

        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : fifo_async_unit_test



// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific FIFO configuration in a way
//  that maintains SVUnit compatibility
`define FIFO_ASYNC_UNIT_TEST(DEPTH, FWFT)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  fifo_async_unit_test #(DEPTH, FWFT) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask



// Standard 3-entry FIFO
module fifo_async_std_depth3_unit_test;
`FIFO_ASYNC_UNIT_TEST(3, 0)
endmodule

// Standard 8-entry FIFO
module fifo_async_std_depth8_unit_test;
`FIFO_ASYNC_UNIT_TEST(8, 0)
endmodule

// Standard 32-entry FIFO
module fifo_async_std_depth32_unit_test;
`FIFO_ASYNC_UNIT_TEST(32, 0)
endmodule

// Standard 385-entry FIFO (medium)
module fifo_async_std_depth385_unit_test;
`FIFO_ASYNC_UNIT_TEST(385, 0)
endmodule

// Standard 512-entry FIFO (medium)
module fifo_async_std_depth512_unit_test;
`FIFO_ASYNC_UNIT_TEST(512, 0)
endmodule



// FWFT 16-entry FIFO
module fifo_async_fwft_depth16_unit_test;
`FIFO_ASYNC_UNIT_TEST(16, 1)
endmodule

// FWFT 23-entry FIFO
module fifo_async_fwft_depth23_unit_test;
`FIFO_ASYNC_UNIT_TEST(23, 1)
endmodule

// FWFT 64-entry FIFO
module fifo_async_fwft_depth64_unit_test;
`FIFO_ASYNC_UNIT_TEST(64, 1)
endmodule

// FWFT 385-entry FIFO (medium)
module fifo_async_fwft_depth385_unit_test;
`FIFO_ASYNC_UNIT_TEST(385, 1)
endmodule

// FWFT 512-entry FIFO (medium)
module fifo_async_fwft_depth512_unit_test;
`FIFO_ASYNC_UNIT_TEST(512, 1)
endmodule
