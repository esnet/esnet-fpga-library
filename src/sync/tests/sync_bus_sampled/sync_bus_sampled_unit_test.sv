`include "svunit_defines.svh"

module sync_bus_sampled_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_bus_sampled_ut";
    svunit_testcase svunit_ut;

    localparam RST_VALUE = 'x;
    localparam DATA_WID = 16;

    localparam type DATA_T = logic[DATA_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic  clk_in;
    logic  rst_in;
    DATA_T data_in;
    logic  clk_out;
    logic  rst_out;
    DATA_T data_out;

    sync_bus_sampled #(
        .DATA_T    ( DATA_T ),
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
            DATA_T value_in;
            void'(std::randomize(value_in));

            rst_in <= 1'b1;

            data_in <= value_in;
            wait_for_sync();

            `FAIL_UNLESS_LOG (
                data_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: 0x%0x, Got: 0x%0x", RST_VALUE, data_out)
            );
        `SVTEST_END

        `SVTEST(rst_out_value)
            DATA_T value_in;
            void'(std::randomize(value_in));

            rst_out <= 1'b1;

            data_in <= value_in;
            wait_for_sync();

            `FAIL_UNLESS_LOG (
                data_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: 0x%0x, Got: 0x%0x.", RST_VALUE, data_out)
            );
        `SVTEST_END

        `SVTEST(pass_value)
            DATA_T value_in;
            void'(std::randomize(value_in));

            // Set input value
            data_in <= value_in;

            // Allow reset value to propagate
            wait_for_handshake();

            wait_for_sync();

            `FAIL_UNLESS_LOG(
                data_out === value_in,
                $sformatf("Output value mismatch. Exp: 0x%0x, Got: 0x%0x.", value_in, data_out)
            );

            // Change input value
            void'(std::randomize(value_in));

            @(posedge clk_in);
            data_in <= value_in;

            wait_for_handshake();

            `FAIL_UNLESS_LOG(
                data_out === value_in,
                $sformatf("Output value mismatch. Exp: 0x%0x, Got: 0x%0x.", value_in, data_out)
            );
        `SVTEST_END

        `SVTEST(pass_samples)

            DATA_T samples_in [$];
            DATA_T samples_out [$];

            fork
                begin
                    DATA_T _data_in;
                    repeat (10000) begin
                        void'(std::randomize(_data_in));
                        data_in <= _data_in;
                        @(posedge clk_in);
                        samples_in.push_back(_data_in);
                    end
                    wait_for_sync();
                end
                begin
                    // Allow reset value to propagate
                    wait_for_handshake();
                    forever begin
                        @(posedge clk_out);
                        if (samples_out.size() > 0) begin
                            if (samples_out[$] != data_out) samples_out.push_back(data_out);
                        end else samples_out.push_back(data_out);
                    end
                end
            join_any

            do begin
                DATA_T sample_in;
                DATA_T sample_out = samples_out.pop_front();
                do begin
                    sample_in = samples_in.pop_front();
                end while ((sample_in != sample_out) && (samples_in.size() > 0));
                `FAIL_IF_LOG(sample_in != sample_out, "Sampled output values do not represent an ordered subset of the input samples.");
            end while (samples_out.size() > 0);

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
        repeat (2) @(posedge clk_in);
        @(posedge clk_in);
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_out);
        @(posedge clk_out);
    endtask

    task wait_for_ack();
        @(posedge clk_out);
        @(posedge clk_out);
        repeat (sync_pkg::RETIMING_STAGES+1) @(posedge clk_in);
        @(posedge clk_in);
    endtask

    task wait_for_handshake();
        wait_for_sync(); // Request assert
        wait_for_ack();  // Ack assert
        wait_for_sync(); // Request deassert
        wait_for_ack();  // Ack deassert
    endtask;

endmodule
