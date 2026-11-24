`include "svunit_defines.svh"

module sync_bus_unit_test #(
    parameter sync_pkg::handshake_mode_t HANDSHAKE_MODE = sync_pkg::HANDSHAKE_MODE_4PHASE,
    parameter time CLK_IN_PERIOD = 7ns,
    parameter time CLK_OUT_PERIOD = 11ns
);
    import svunit_pkg::svunit_testcase;

    string name = $sformatf("sync_bus_%0dphase_%0d_%0d_ut",
        HANDSHAKE_MODE == sync_pkg::HANDSHAKE_MODE_4PHASE ? 4 : 2,
        CLK_IN_PERIOD, CLK_OUT_PERIOD);
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
        .RST_VALUE ( RST_VALUE ),
        .HANDSHAKE_MODE ( HANDSHAKE_MODE )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    time clk_in_period = CLK_IN_PERIOD;
    time clk_out_period = CLK_OUT_PERIOD;

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
            bit source_changed_while_blocked = 0;

            fork begin
                fork
                    begin
                        DATA_T _data_in;
                        DATA_T held_data = RST_VALUE;
                        @(cb_in);
                        void'(std::randomize(_data_in));
                        cb_in.req_in <= 1'b1;
                        cb_in.data_in <= _data_in;
                        repeat (10000) begin
                            @(cb_in);
                            if (cb_in.mon_req_in && cb_in.rdy_in) begin
                                samples_in.push_back(_data_in);
                                held_data = _data_in;
                            end
                            // Vary inputs even while blocked; the accepted
                            // source payload must stay held until the next request.
                            void'(std::randomize(_data_in));
                            cb_in.data_in <= _data_in;
                            #1ps;
                            if (DUT.__sync_ff_bus_data_in !== held_data)
                                source_changed_while_blocked = 1;
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
            `FAIL_IF(source_changed_while_blocked);
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

// Delegate parameterized cases using the same SVUnit pattern as the FIFO tests.
`define SYNC_BUS_UNIT_TEST(MODE, IN_PERIOD, OUT_PERIOD) \
    import svunit_pkg::svunit_testcase; \
    svunit_testcase svunit_ut; \
    sync_bus_unit_test #(MODE, IN_PERIOD, OUT_PERIOD) test(); \
    function void build(); \
        test.build(); \
        svunit_ut = test.svunit_ut; \
    endfunction \
    function void __register_tests(); \
        test.__register_tests(); \
    endfunction \
    task run(); \
        test.run(); \
    endtask

module sync_bus_four_fast_source_unit_test;
    `SYNC_BUS_UNIT_TEST(sync_pkg::HANDSHAKE_MODE_4PHASE, 7ns, 11ns)
endmodule
module sync_bus_two_fast_source_unit_test;
    `SYNC_BUS_UNIT_TEST(sync_pkg::HANDSHAKE_MODE_2PHASE, 7ns, 11ns)
endmodule
module sync_bus_four_fast_dest_unit_test;
    `SYNC_BUS_UNIT_TEST(sync_pkg::HANDSHAKE_MODE_4PHASE, 13ns, 5ns)
endmodule
module sync_bus_two_fast_dest_unit_test;
    `SYNC_BUS_UNIT_TEST(sync_pkg::HANDSHAKE_MODE_2PHASE, 13ns, 5ns)
endmodule
module sync_bus_four_equal_clocks_unit_test;
    `SYNC_BUS_UNIT_TEST(sync_pkg::HANDSHAKE_MODE_4PHASE, 8ns, 8ns)
endmodule
module sync_bus_two_equal_clocks_unit_test;
    `SYNC_BUS_UNIT_TEST(sync_pkg::HANDSHAKE_MODE_2PHASE, 8ns, 8ns)
endmodule

`undef SYNC_BUS_UNIT_TEST
