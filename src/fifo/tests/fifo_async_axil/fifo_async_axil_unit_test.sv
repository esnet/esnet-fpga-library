`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fifo_async_unit_test #(
    parameter int DEPTH = 3,
    parameter bit FWFT
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import fifo_verif_pkg::*;

    localparam string type_string = FWFT ? "fwft" : "std";

    // Synthesize testcase name from parameters
    string name = $sformatf("fifo_async_%s_depth%0d__ut", type_string, DEPTH);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type DATA_T = bit[31:0];
    localparam bit ASYNC = 1'b1;

    //===================================
    // Derived parameters
    //===================================
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

    axi4l_intf axil_if ();

    localparam FIFO_ASYNC_LATENCY = 6;  // 1 (bin2gray) + 3 (sync) + 1 (gray2bin) + 1 (phase delta)

    fifo_async_axil #(
        .DATA_T  ( DATA_T ),
        .DEPTH   ( DEPTH ),
        .FWFT    ( FWFT )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // 'Model'
    struct {
        int wr_ptr;
        int rd_ptr;
        bit fwft;
    } ctrl_model;

    tb_env #(DATA_T, FWFT) env;

    std_reset_intf reset_if (.clk(wr_clk));

    std_raw_intf #(DATA_T) wr_if (.clk(wr_clk));
    std_raw_intf #(DATA_T) rd_if (.clk(rd_clk));

    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent;
    fifo_ctrl_reg_agent ctrl_reg_agent;
    fifo_core_reg_agent core_reg_agent;

    // Assign reset interface
    assign wr_srst = reset_if.reset;
    assign rd_srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge wr_clk) reset_if.ready <= ~wr_srst;

    // Assign data interfaces
    assign wr = wr_if.valid;
    assign wr_data = wr_if.data;
    assign wr_if.ready = !full;

    assign rd = rd_if.ready;
/*
    always begin
       @(posedge rd_if.ready); 
       if (!empty) begin
          rd = 1'b1;
          @(posedge rd_clk); 
          rd = 1'b0;
       end else begin
          wait(!empty); 
          rd = 1'b1;
          @(posedge rd_clk); 
          rd = 1'b0;
       end
    end
*/
     assign rd_if.data = rd_data;
//    assign rd_if.valid = !empty;
    assign rd_if.valid = rd_ack;
   
    // Generate clocks
    real clk_ratio     = 1;
    real wr_clk_period = 5;
    real rd_clk_period = 5;

    initial wr_clk = 1'b0;
    always #(wr_clk_period) wr_clk = ~wr_clk;

    initial rd_clk = 1'b0;
    always #(rd_clk_period) rd_clk = ~rd_clk;

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    initial axil_if.aresetn = 1'b0;
    always @(posedge axil_if.aclk) axil_if.aresetn <= !reset_if.reset;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Build AXI-L reg agent
        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;

        core_reg_agent = new("core_agent", axil_reg_agent, 'h000);
        ctrl_reg_agent = new("ctrl_agent", axil_reg_agent, 'h100);

        // Create testbench environment
        env = new("tb_env", reset_if, wr_if, rd_if);
        env.connect();

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

        // Reset model
        ctrl_model_reset();

        ctrl_reg_agent.idle();
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
        //   ctrl info
        //
        // Desc: read info registers from
        //       FIFO controller regs and check
        //       against expected block
        //       parameterization.
        //
        //===================================
        `SVTEST(ctrl_info)
            int got_depth;
            bit got_async;

            ctrl_reg_agent.get_depth(got_depth);

            `FAIL_UNLESS_LOG(
                got_depth === DEPTH,
                $sformatf(
                    "Depth mismatch. Exp: %0d, Got: %0d.",
                    DEPTH,
                    got_depth
                )
            );

            ctrl_reg_agent.is_async(got_async);
            `FAIL_UNLESS_LOG(
                got_async === ASYNC,
                $sformatf(
                    "FIFO type (async) mismatch. Exp: %b, Got: %b.",
                    ASYNC,
                    got_async
                )
            );

        `SVTEST_END

        //===================================
        // Test:
        //   core info
        //
        // Desc: read info registers from
        //       FIFO core regs and check
        //       against expected block
        //       parameterization.
        //
        //===================================
        `SVTEST(core_info)
            int got_depth;
            bit got_async;

            core_reg_agent.get_depth(got_depth);

            `FAIL_UNLESS_LOG(
                got_depth === DEPTH,
                $sformatf(
                    "Depth mismatch. Exp: %0d, Got: %0d.",
                    DEPTH,
                    got_depth
                )
            );

            core_reg_agent.is_async(got_async);
            `FAIL_UNLESS_LOG(
                got_async === ASYNC,
                $sformatf(
                    "FIFO type (async) mismatch. Exp: %b, Got: %b.",
                    ASYNC,
                    got_async
                )
            );

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
            ctrl_model_write();

            // Wait
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check register status
            check_status();

            // Receive transaction
            wait(!empty); env.monitor.receive(got_transaction);
            ctrl_model_read();

            // Wait
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check register status
            check_status();

            // Compare transactions
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG( match == 1, msg );
        `SVTEST_END

        //===================================
        // Test:
        //   soft_reset
        //
        // Desc:
        //   - sends one item into FIFO
        //   - issue soft reset, check that 
        //     fifo state is reset
        //
        //===================================
        `SVTEST(_soft_reset)
            // Declarations
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);
            ctrl_model_write();

            // Send second transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);
            ctrl_model_write();

            // Wait
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check status as reported from regs
            check_status();

            // Receive transaction
            wait(!empty); env.monitor.receive(got_transaction);
            ctrl_model_read();

            // Wait
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check register status
            check_status();

            // Issue soft reset
            soft_reset();

            // Check status to confirm reset state
            check_status();

            // Send transaction again
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);

            // Update model
            ctrl_model_write();

            // Wait
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check status as reported from regs
            check_status();

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

                wait(!empty); env.monitor.receive(got_transaction); env.monitor._wait(1);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG( match == 1, msg );
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

            // Fill all FIFO entries, plus one overflow event i.e. DEPTH+1
            for (int i = 0; i < (__DEPTH+1); i++) begin
                exp_transaction = new("exp_transaction", i);
                env.driver.send(exp_transaction);
            end

            // Read back all FIFO entries and compare.
            for (int i = 0; i < (__DEPTH); i++) begin
                exp_transaction = new("exp_transaction", i);
                wait(!empty); env.monitor.receive(got_transaction);

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

                wait(!empty); env.monitor.receive(got_transaction);
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
        //   - Fills all fifo entries with unqique values.
        //   - Then reads them all back and compares each value.
        //
        //===================================
        `SVTEST(_slow_to_fast_fill_empty)
            // Declarations
            std_verif_pkg::raw_transaction#(DATA_T) got_transaction;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;

            // Set clk frequencies
            clk_ratio = 2.5;  wr_clk_period = clk_ratio * rd_clk_period;

            // Fill all FIFO entries, plus one overflow event i.e. DEPTH+1
            for (int i = 0; i < (__DEPTH+1); i++) begin
                exp_transaction = new("exp_transaction", i);
                env.driver.send(exp_transaction);
            end

            // Read back all FIFO entries and compare.
            for (int i = 0; i < (__DEPTH); i++) begin
                exp_transaction = new("exp_transaction", i);
                wait(!empty); env.monitor.receive(got_transaction);

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
            `FAIL_UNLESS(empty == 1);

            // Send transaction
            exp_transaction = new("exp_transaction", exp_item);
            env.driver.send(exp_transaction);

            // Check that empty is deasserted immediately (once write transaction is registered by FIFO)
            env.monitor._wait(FIFO_ASYNC_LATENCY);
            `FAIL_UNLESS(empty == 0);

            // Receive transaction
            wait(!empty); env.monitor.receive(got_transaction);

            // Check that empty is reasserted on next cycle
            `FAIL_UNLESS(empty == 1);
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
            `FAIL_UNLESS(full == 0);

            // Send DEPTH transactions
            for (int i = 0; i < __DEPTH; i++) begin
                env.driver.send(exp_transaction);
                ctrl_model_write();
                // Full should remain deasserted
                `FAIL_UNLESS(full == 0);
            end

            // Full should be asserted immediately (once write transaction is registered by FIFO)
            env.driver._wait(1);
            `FAIL_UNLESS(full == 1);

            // Check status
            check_status();

            // Receive single transaction
            wait(!empty); env.monitor.receive(got_transaction);
            ctrl_model_read();

            // Allow read transaction to be registered by FIFO
            env.driver._wait(FIFO_ASYNC_LATENCY);

            // Check that full is once again deasserted
            `FAIL_UNLESS(full == 0);

            // Check status
            check_status();
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

            // Put driver in 'push' mode to allow overflow conditions
            env.driver.set_tx_mode(std_verif_pkg::TX_MODE_PUSH);

            // Overflow should be deasserted immediately following init
            `FAIL_UNLESS(full == 0);
            `FAIL_UNLESS(oflow == 0);

            // Send DEPTH transactions
            for (int i = 0; i < __DEPTH; i++) begin
                // Full/overflow should be deasserted
                `FAIL_UNLESS(full == 0);
                `FAIL_UNLESS(oflow == 0);
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                env.driver.send(exp_transaction);
            end
            env.driver._wait(1);

            // After filling FIFO, full should be asserted (oflow should remain deasserted)
            `FAIL_UNLESS(full == 1);
            `FAIL_UNLESS(oflow == 0);

            // Send one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", __DEPTH), __DEPTH);
            env.driver.send(exp_transaction);

            // This should trigger oflow on the same cycle
            `FAIL_UNLESS(oflow == 1);

            // Full should remain asserted, oflow should be deasserted on following cycle
            env.driver._wait(1);
            `FAIL_UNLESS(full == 1);
            `FAIL_UNLESS(oflow == 0);

            // Empty FIFO
            for (int i = 0; i < __DEPTH; i++) begin
                exp_transaction = new($sformatf("exp_transaction_%d", i), i);
                wait(!empty); env.monitor.receive(got_transaction);
                match = exp_transaction.compare(got_transaction, msg);
                `FAIL_UNLESS_LOG(
                    match == 1, msg
                );
            end

            // Send and receive one more transaction
            exp_transaction = new($sformatf("exp_transaction_%d", __DEPTH), __DEPTH);
            env.driver.send(exp_transaction);
            `FAIL_UNLESS(oflow == 0);

            wait(!empty); env.monitor.receive(got_transaction);
            match = exp_transaction.compare(got_transaction, msg);
            `FAIL_UNLESS_LOG(
                match == 1, msg
            );

        `SVTEST_END

    `SVUNIT_TESTS_END

    task soft_reset();
        core_reg_agent.soft_reset();
        ctrl_model_reset();
    endtask

    task check_status();
        bit got_full;
        bit got_empty;
        int got_cnt;
        int got_ptr;
        // Check status
        ctrl_reg_agent.is_full(got_full);
        `FAIL_UNLESS_LOG(
            got_full === ctrl_model_full(),
            $sformatf(
                "Full flag mismatch. Exp: %0b, Got: %0b.",
                ctrl_model_full(),
                got_full
            )
        );
        ctrl_reg_agent.is_empty(got_empty);
        `FAIL_UNLESS_LOG(
            got_empty === ctrl_model_empty(),
            $sformatf(
                "Full flag mismatch. Exp: %0b, Got: %0b.",
                ctrl_model_empty(),
                got_empty
            )
        );
        ctrl_reg_agent.get_wr_ptr(got_ptr);
        `FAIL_UNLESS_LOG(
            got_ptr === ctrl_model_wr_ptr(),
            $sformatf(
                "Write pointer mismatch. Exp: %0x, Got: %0x.",
                ctrl_model.wr_ptr,
                got_ptr
            )
        );
        ctrl_reg_agent.get_rd_ptr(got_ptr);
        `FAIL_UNLESS_LOG(
            got_ptr === ctrl_model_rd_ptr(),
            $sformatf(
                "Read pointer mismatch. Exp: %0x, Got: %0x.",
                ctrl_model.rd_ptr,
                got_ptr
            )
        );
        ctrl_reg_agent.get_wr_count(got_cnt);
        `FAIL_UNLESS_LOG(
            got_cnt === ctrl_model_count(),
            $sformatf(
                "Write count mismatch. Exp: %0x, Got: %0x.",
                ctrl_model_count(),
                got_cnt
            )
        );
        ctrl_reg_agent.get_rd_count(got_cnt);
        `FAIL_UNLESS_LOG(
            got_cnt === ctrl_model_count(),
            $sformatf(
                "Read count mismatch. Exp: %0x, Got: %0x.",
                ctrl_model_count(),
                got_cnt
            )
        );
    endtask

    function automatic int ctrl_model_count();
        return ctrl_model.wr_ptr - ctrl_model.rd_ptr;
    endfunction

    function automatic void ctrl_model_reset();
        ctrl_model.wr_ptr = 0;
        ctrl_model.rd_ptr = 0;
        ctrl_model.fwft = 0;
    endfunction

    function automatic bit ctrl_model_write();
        if (!ctrl_model_full()) begin
            ctrl_model.wr_ptr++;
            if (FWFT && !ctrl_model.fwft) begin
                ctrl_model.rd_ptr++;
                ctrl_model.fwft = 1;
            end
            return 1'b0;
        end else return 1'b1; // Indicate overflow
    endfunction

    function automatic bit ctrl_model_read();
        if (FWFT && ctrl_model.fwft) begin
            if (!ctrl_model_empty()) ctrl_model.rd_ptr++;
            else                     ctrl_model.fwft = 0;
            return 1'b0;
        end else if (!ctrl_model_empty()) begin
            ctrl_model.rd_ptr++;
            return 1'b0;
        end else return 1'b1; // Indicate underflow
    endfunction

    function automatic int ctrl_model_wr_ptr();
        const int MEM_DEPTH = 2**$clog2(DEPTH);
        return ctrl_model.wr_ptr % MEM_DEPTH;
    endfunction

    function automatic int ctrl_model_rd_ptr();
        const int MEM_DEPTH = 2**$clog2(DEPTH);
        return ctrl_model.rd_ptr % MEM_DEPTH;
    endfunction

    function automatic bit ctrl_model_full();
        return (ctrl_model_count() == DEPTH);
    endfunction

    function automatic bit ctrl_model_empty();
        return (ctrl_model_count() == 0);
    endfunction

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
