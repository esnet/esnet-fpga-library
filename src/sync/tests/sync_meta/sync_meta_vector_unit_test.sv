`include "svunit_defines.svh"

module sync_meta_vector_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_meta_vector_ut";
    svunit_testcase svunit_ut;

    localparam RST_VALUE = 'x;
    localparam DATA_WID = 16;

    localparam type DATA_T = logic[DATA_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic clk_in;
    logic rst_in;
    logic clk_out;
    logic rst_out;

    DATA_T sig_in;
    DATA_T sig_out;

    sync_meta     #(
        .DATA_T    ( DATA_T ),
        .RST_VALUE ( RST_VALUE )
    ) DUT (
        .clk_in   ( clk_in ),
        .rst_in   ( rst_in ),
        .sig_in   ( sig_in ),
        .clk_out  ( clk_out ),
        .rst_out  ( rst_out ),
        .sig_out  ( sig_out )
    );

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
            DATA_T value_in;
            void'(std::randomize(value_in));

            rst_in <= 1'b1;

            sig_in <= value_in;
            wait_for_sync();

            `FAIL_UNLESS_LOG (
                sig_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: 0x%0x, Got: 0x%0x", RST_VALUE, sig_out)
            );
        `SVTEST_END

        `SVTEST(rst_out_value)
            DATA_T value_in;
            void'(std::randomize(value_in));

            rst_out <= 1'b1;

            sig_in <= value_in;
            wait_for_sync();

            `FAIL_UNLESS_LOG (
                sig_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: 0x%0x, Got: 0x%0x.", RST_VALUE, sig_out)
            );
        `SVTEST_END

        `SVTEST(pass_value)
            DATA_T value_in;
            void'(std::randomize(value_in));

            // Set input value
            sig_in <= value_in;

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                sig_out === value_in,
                $sformatf("Output value mismatch. Exp: 0x%0x, Got: 0x%0x.", value_in, sig_out)
            );

            // Change input value
            void'(std::randomize(value_in));

            @(posedge clk_in);
            sig_in <= value_in;

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                sig_out === value_in,
                $sformatf("Output value mismatch. Exp: 0x%0x, Got: 0x%0x.", value_in, sig_out)
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
