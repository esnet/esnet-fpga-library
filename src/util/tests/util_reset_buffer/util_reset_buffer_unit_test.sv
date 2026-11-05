`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module util_reset_buffer_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "util_reset_buffer_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Clock and stimulus
    //===================================
    logic clk;
    logic clock_enable = 1'b0;
    logic srst_in = 1'b0;
    wire dut_clk = clk && clock_enable;
    wire [3:0] srst_out, srstn_out;
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // DUTs: stage depth and startup polarity
    //===================================
    for (genvar i = 0; i < 4; i++) begin : g_dut
        util_reset_buffer #(
            .STAGES(i < 2 ? 2 : 4),
            .ASSERT_ON_INIT(i % 2)
        ) DUT (
            .clk(dut_clk), .srst_in,
            .srst_out(srst_out[i]), .srstn_out(srstn_out[i])
        );
    end

    //===================================
    // Clocking and expected reset history
    //===================================
    clocking cb @(negedge clk);
        output clock_enable, srst_in;
        input srst_out, srstn_out;
    endclocking

    bit captured_init = 0;
    logic [3:0] initial_srst, initial_srstn;
    bit history[$];

    task automatic step(input bit reset);
        cb.srst_in <= reset;
        @(cb);
        history.push_front(reset);
        void'(history.pop_back());
        for (int i = 0; i < 4; i++) begin
            `FAIL_UNLESS_EQUAL(cb.srst_out[i], history[i < 2 ? 1 : 3]);
        end
        `FAIL_UNLESS_EQUAL(cb.srstn_out, ~cb.srst_out);
    endtask

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        @(cb);
        // Hold the DUT clocks off until startup values have been sampled.
        if (!captured_init) begin
            initial_srst = cb.srst_out;
            initial_srstn = cb.srstn_out;
            captured_init = 1;
        end
        cb.clock_enable <= 1'b1;
        cb.srst_in <= 1'b0;
        repeat (5) @(cb);
        history.delete();
        repeat (4) history.push_back(0);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(initial_state)
            `FAIL_UNLESS_EQUAL(initial_srst, 4'b1010);
            `FAIL_UNLESS_EQUAL(initial_srstn, 4'b0101);
        `SVTEST_END

        `SVTEST(reset_latency)
            repeat (6) step(1);
            repeat (6) step(0);
            step(1);
            repeat (6) step(0);
        `SVTEST_END

        `SVTEST(randomized)
            repeat (128) step($urandom_range(0, 1));
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : util_reset_buffer_unit_test
