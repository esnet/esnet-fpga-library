`include "svunit_defines.svh"

module sync_meta_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_meta_ut";
    svunit_testcase svunit_ut;

    localparam RST_VALUE = 1'b1;
    //===================================
    // DUT
    //===================================
    logic clk_in;
    logic rst_in;
    logic clk_out;
    logic rst_out;

    logic sig_in;
    logic sig_out;

    sync_meta #(
        .RST_VALUE ( RST_VALUE )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    time clk_in_period = $urandom_range(3,12)*1ns;
    time clk_out_period = $urandom_range(3,12)*1ns;

    `SVUNIT_CLK_GEN(clk_in, clk_in_period);
    `SVUNIT_CLK_GEN(clk_out, clk_out_period);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        reset();

    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();

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

        `SVTEST(rst_in_value)
            rst_in = 1'b1;

            sig_in = 1'b1;
            wait_for_sync();

            `FAIL_UNLESS_LOG (
                sig_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: %0b, Got: %0b.", RST_VALUE, sig_out)
            );
        `SVTEST_END

        `SVTEST(rst_out_value)
            rst_out = 1'b1;

            sig_in = 1'b1;
            wait_for_sync();

            `FAIL_UNLESS_LOG (
                sig_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: %0b, Got: %0b.", RST_VALUE, sig_out)
            );
        `SVTEST_END

        `SVTEST(pass_0_to_1)
            sig_in = 1'b0;

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                sig_out === 1'b0,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b0, sig_out)
            );
            #1ns;
            sig_in = 1'b1;

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                sig_out === 1'b1,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b1, sig_out)
            );
        `SVTEST_END

        `SVTEST(pass_1_to_0)
            sig_in = 1'b1;

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                sig_out === 1'b1,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b1, sig_out)
            );
            #1ns;
            sig_in = 1'b0;

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                sig_out === 1'b0,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b0, sig_out)
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        fork
            begin
                rst_in <= 1'b1;
                repeat (8) @(posedge clk_in);
                rst_in <= 1'b0;
                @(posedge clk_in);
            end
            begin
                rst_out <= 1'b1;
                repeat (8) @(posedge clk_out);
                rst_out <= 1'b0;
                @(posedge clk_out);
            end
        join
    endtask

    task wait_for_sync();
        @(posedge clk_in);
        @(posedge clk_in);
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_out);
        @(posedge clk_out);
    endtask

endmodule
