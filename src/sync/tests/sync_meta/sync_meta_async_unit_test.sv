`include "svunit_defines.svh"

module sync_meta_async_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_meta_async_ut";
    svunit_testcase svunit_ut;

    logic clk_out;
    logic rst_out;
    logic sig_in;
    logic sig_out;

    // No source clock; the unused source reset must not affect sampling.
    sync_meta #(.RST_VALUE(1'b0), .INPUT_REG(0)) DUT (
        .clk_in (1'b0),
        .rst_in (1'b1),
        .sig_in (sig_in),
        .clk_out(clk_out),
        .rst_out(rst_out),
        .sig_out(sig_out)
    );

    `SVUNIT_CLK_GEN(clk_out, 5ns);

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        sig_in = 1'b0;
        rst_out = 1'b1;
        repeat (2) @(posedge clk_out);
        @(negedge clk_out);
        rst_out = 1'b0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(rising_edge_without_source_clock)
            sig_in = 1'b1;
            for (int i = 1; i <= sync_pkg::RETIMING_STAGES; i++) begin
                @(posedge clk_out);
                #1ps;
                `FAIL_UNLESS(sig_out === (i == sync_pkg::RETIMING_STAGES))
            end
        `SVTEST_END

        `SVTEST(falling_edge_without_source_clock)
            sig_in = 1'b1;
            repeat (sync_pkg::RETIMING_STAGES) @(posedge clk_out);
            @(negedge clk_out);
            sig_in = 1'b0;
            for (int i = 1; i <= sync_pkg::RETIMING_STAGES; i++) begin
                @(posedge clk_out);
                #1ps;
                `FAIL_UNLESS(sig_out === (i != sync_pkg::RETIMING_STAGES))
            end
        `SVTEST_END

        `SVTEST(destination_reset)
            sig_in = 1'b1;
            repeat (sync_pkg::RETIMING_STAGES) @(posedge clk_out);
            #1ps;
            `FAIL_UNLESS(sig_out === 1'b1)
            @(negedge clk_out);
            rst_out = 1'b1;
            @(posedge clk_out);
            #1ps;
            `FAIL_UNLESS(sig_out === 1'b0)
            @(negedge clk_out);
            rst_out = 1'b0;
            repeat (sync_pkg::RETIMING_STAGES) @(posedge clk_out);
            #1ps;
            `FAIL_UNLESS(sig_out === 1'b1)
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule
