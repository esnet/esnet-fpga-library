`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module util_pipe_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "util_pipe_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Clock and stimulus
    //===================================
    localparam int DATA_WID = 13;
    localparam logic [DATA_WID-1:0] RESET_VAL = 13'h15A5;
    logic clk;
    logic srst = 1'b1;
    logic [DATA_WID-1:0] data_in = '0;
    wire [DATA_WID-1:0] bypass_out, single_out, delayed_out;
    wire bit_out;
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // DUTs: bypass, registered, and delayed
    //===================================
    util_pipe #(.DATA_WID(DATA_WID), .PIPE_STAGES(0), .RESET_VAL(RESET_VAL)) DUT_bypass (
        .clk, .srst, .data_in, .data_out(bypass_out)
    );
    util_pipe #(.DATA_WID(DATA_WID), .PIPE_STAGES(1), .RESET_VAL(RESET_VAL)) DUT_single (
        .clk, .srst, .data_in, .data_out(single_out)
    );
    util_pipe #(.DATA_WID(DATA_WID), .PIPE_STAGES(4), .RESET_VAL(RESET_VAL)) DUT_delayed (
        .clk, .srst, .data_in, .data_out(delayed_out)
    );
    util_pipe #(.PIPE_STAGES(4)) DUT_bit (
        .clk, .srst, .data_in(data_in[0]), .data_out(bit_out)
    );

    //===================================
    // Clocking and expected transaction history
    //===================================
    // Drive on falling edges; sample results after the intervening rising edge.
    clocking cb @(negedge clk);
        output srst, data_in;
        input bypass_out, single_out, delayed_out, bit_out;
    endclocking

    logic [DATA_WID-1:0] history[$];

    task automatic step(input bit reset, input logic [DATA_WID-1:0] data);
        cb.srst <= reset;
        cb.data_in <= data;
        @(cb);
        if (reset) history.delete();
        else begin
            history.push_front(data);
            if (history.size() > 4) void'(history.pop_back());
        end
        `FAIL_UNLESS_EQUAL(cb.bypass_out, data);
        `FAIL_UNLESS_EQUAL(cb.single_out, reset ? RESET_VAL : data);
        `FAIL_UNLESS_EQUAL(cb.delayed_out, history.size() < 4 ? RESET_VAL : history[3]);
        `FAIL_UNLESS_EQUAL(cb.bit_out, history.size() < 4 ? 1'b0 : history[3][0]);
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
        step(1, '0);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(latency)
            for (int i = 0; i < 16; i++) step(0, i + 1);
        `SVTEST_END

        `SVTEST(reset_flush)
            repeat (6) step(0, '1);
            step(1, '1);
            repeat (6) step(0, '0);
            repeat (3) step(1, '1);
            repeat (6) step(0, '1);
        `SVTEST_END

        `SVTEST(randomized)
            repeat (128) step($urandom_range(0, 7) == 0, $urandom);
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : util_pipe_unit_test
