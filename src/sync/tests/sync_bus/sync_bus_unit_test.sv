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

        req_in = 1'b0;

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
            req_in = 1'b1;
            fork
                begin
                    wait_for_sync();
                end
                begin
                    forever begin
                        // No events should be forwarded, due to input reset assertion
                        @(posedge clk_out);
                        `FAIL_IF(ack_out);
                    end
                end
            join_any
        `SVTEST_END

        `SVTEST(rst_out_value)
            rst_out = 1'b1;
            req_in = 1'b1;
            fork
                begin
                    wait_for_sync();
                end
                begin
                    forever begin
                        // No events should be forwarded, due to output reset assertion
                        @(posedge clk_out);
                        `FAIL_IF(ack_out);
                    end
                end
            join_any
        `SVTEST_END

        `SVTEST(pass_value)
            DATA_T _data_in;
            void'(std::randomize(_data_in));
            
            // Send request
            @(posedge clk_in);
            req_in <= 1'b1;
            data_in <= _data_in;

            wait(rdy_in);
            @(posedge clk_in);
            req_in <= 1'b0;
            data_in <= 'x;

            fork
                begin
                    wait_for_sync();
                    @(posedge clk_out);
                    `FAIL_IF(1);
                end
                begin
                    wait(ack_out);
                    @(posedge clk_out);
                    `FAIL_UNLESS_EQUAL(data_out, _data_in);
                end
            join_any

        `SVTEST_END

        `SVTEST(backpressure)
            DATA_T samples_in [$];
            DATA_T samples_out [$];

            fork
                begin
                    DATA_T _data_in;
                    @(posedge clk_in);
                    void'(std::randomize(_data_in));
                    req_in <= 1'b1;
                    data_in <= _data_in;
                    repeat (10000) begin
                        @(posedge clk_in);
                        if (rdy_in) samples_in.push_back(_data_in);
                    end
                    req_in <= 1'b0;
                    wait_for_sync();
                    @(posedge clk_out);
                end
                begin
                    forever begin
                        @(posedge clk_out);
                        if (ack_out) samples_out.push_back(data_out);
                    end
                end
            join_any

            // Check that list of output samples is identical
            // (matching length and order) to list of input samples
            `FAIL_UNLESS_EQUAL(samples_in.size(), samples_out.size());
            foreach (samples_in[i]) begin
                `FAIL_UNLESS_EQUAL(samples_in[i], samples_out[i]);
            end

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

endmodule
