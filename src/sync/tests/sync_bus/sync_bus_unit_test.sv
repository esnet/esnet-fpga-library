`include "svunit_defines.svh"

module sync_bus_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_bus_ut";
    svunit_testcase svunit_ut;

    localparam DATA_WID = 32;
    localparam type DATA_T = bit[DATA_WID-1:0];
    localparam int RST_VALUE = 32'h01234567;

    //===================================
    // DUT
    //===================================
    logic  clk_in;
    logic  rst_in;
    logic  rdy_in;
    logic  req_in;
    DATA_T data_in;

    logic  clk_out;
    logic  rst_out;
    logic  ack_out;
    DATA_T data_out;

    sync_bus #(
        .DATA_WID  ( DATA_WID ),
        .RST_VALUE ( RST_VALUE )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    time clk_in_period = $urandom_range(3,12)*1ns;
    time clk_out_period = $urandom_range(3,12)*1ns;

    `SVUNIT_CLK_GEN(clk_in, clk_in_period);
    `SVUNIT_CLK_GEN(clk_out, clk_out_period);

    // Sample the driven request independently of the output clockvar.
    wire mon_req_in = req_in;

    clocking cb_in @(posedge clk_in);
        output rst_in, req_in, data_in;
        input rdy_in, mon_req_in;
    endclocking

    clocking cb_out @(posedge clk_out);
        output rst_out;
        input ack_out, data_out;
    endclocking

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

        cb_in.req_in <= 1'b0;

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
    // Isolate each worker fork so cleanup cannot affect other test processes.
    // Check results after cleanup, including failure paths.
    `SVUNIT_TESTS_BEGIN

        `SVTEST(rst_in_value)
            bit unexpected_output = 0;
            cb_in.rst_in <= 1'b1;
            cb_in.req_in <= 1'b1;
            fork begin
                fork
                    begin
                        wait_for_sync();
                    end
                    begin
                        forever begin
                            // No events should be forwarded, due to input reset assertion
                            @(cb_out);
                            unexpected_output |= cb_out.ack_out;
                        end
                    end
                join_any
                disable fork;
            end join
            `FAIL_IF(unexpected_output);
        `SVTEST_END

        `SVTEST(rst_out_value)
            bit unexpected_output = 0;
            cb_out.rst_out <= 1'b1;
            cb_in.req_in <= 1'b1;
            fork begin
                fork
                    begin
                        wait_for_sync();
                    end
                    begin
                        forever begin
                            // No events should be forwarded, due to output reset assertion
                            @(cb_out);
                            unexpected_output |= cb_out.ack_out;
                        end
                    end
                join_any
                disable fork;
            end join
            `FAIL_IF(unexpected_output);
        `SVTEST_END

        `SVTEST(pass_value)
            bit received = 0;
            DATA_T received_data;
            DATA_T _data_in;
            void'(std::randomize(_data_in));
            
            // Send request
            @(cb_in);
            cb_in.req_in <= 1'b1;
            cb_in.data_in <= _data_in;

            do @(cb_in); while (!cb_in.rdy_in);
            cb_in.req_in <= 1'b0;
            cb_in.data_in <= 'x;

            fork begin
                fork
                    begin
                        wait_for_sync();
                        @(cb_out);
                    end
                    begin
                        @(cb_out iff cb_out.ack_out);
                        received_data = cb_out.data_out;
                        received = 1;
                    end
                join_any
                disable fork;
            end join
            `FAIL_UNLESS(received);
            `FAIL_UNLESS_EQUAL(received_data, _data_in);

        `SVTEST_END

        `SVTEST(backpressure)
            DATA_T samples_in [$];
            DATA_T samples_out [$];

            fork begin
                fork
                    begin
                        DATA_T _data_in;
                        @(cb_in);
                        void'(std::randomize(_data_in));
                        cb_in.req_in <= 1'b1;
                        cb_in.data_in <= _data_in;
                        repeat (10000) begin
                            @(cb_in);
                            if (cb_in.mon_req_in && cb_in.rdy_in) samples_in.push_back(_data_in);
                        end
                        cb_in.req_in <= 1'b0;
                        wait_for_sync();
                        @(cb_out);
                    end
                    begin
                        forever begin
                            @(cb_out);
                            if (cb_out.ack_out) samples_out.push_back(cb_out.data_out);
                        end
                    end
                join_any
                disable fork;
            end join

            // Check that list of output samples is identical
            // (matching length and order) to list of input samples
            `FAIL_UNLESS_EQUAL(samples_in.size(), samples_out.size());
            foreach (samples_in[i]) begin
                `FAIL_UNLESS_EQUAL(samples_in[i], samples_out[i]);
            end

        `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task reset();
        fork
            begin
                cb_in.rst_in <= 1'b1;
                repeat (8) @(cb_in);
                cb_in.rst_in <= 1'b0;
                @(cb_in);
            end
            begin
                cb_out.rst_out <= 1'b1;
                repeat (8) @(cb_out);
                cb_out.rst_out <= 1'b0;
                @(cb_out);
            end
        join
    endtask

    task wait_for_sync();
        repeat (2) @(cb_in);
        @(cb_in);
        repeat (sync_pkg::RETIMING_STAGES+1) @(cb_out);
        @(cb_out);
    endtask

endmodule
