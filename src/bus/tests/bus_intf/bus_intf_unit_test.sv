`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module bus_intf_unit_test #(
    parameter string COMPONENT_NAME = "bus_intf"
);
    import svunit_pkg::svunit_testcase;
    import bus_verif_pkg::*;
    import tb_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("%s_ut", COMPONENT_NAME);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type DATA_T = logic[31:0];

    //===================================
    // DUT
    //===================================

    logic   clk;
    
    bus_intf #(DATA_T) from_tx (.clk(clk));
    bus_intf #(DATA_T) to_rx (.clk(clk));

    generate
        case (COMPONENT_NAME)
            "bus_intf_connector" : begin : g__bus_intf_connector
                bus_intf_connector #(DATA_T) DUT (.*);
            end : g__bus_intf_connector
            
            "bus_pipe_1st" : begin : g__bus_pipe
                bus_pipe #(DATA_T, .STAGES(1)) DUT (.*);
            end : g__bus_pipe

            "bus_pipe_4st" : begin : g__bus_pipe
                bus_pipe #(DATA_T, .STAGES(4)) DUT (.*);
            end : g__bus_pipe

            "bus_pipe_slr" : begin : g__bus_pipe_slr
                bus_pipe_slr #(DATA_T) DUT (.*);
            end : g__bus_pipe_slr

            "bus_pipe_slr_b2b" : begin : g__bus_pipe_slr_b2b
                bus_intf #(DATA_T) __bus_if (.clk);
                bus_pipe_slr #(DATA_T, 0, 1, 1) DUT1 (.from_tx, .to_rx (__bus_if));
                bus_pipe_slr #(DATA_T, 0, 1, 1) DUT2 (.from_tx (__bus_if), .to_rx);
            end : g__bus_pipe_slr_b2b

            "bus_pipe_auto" : begin : g__bus_pipe_auto
                bus_pipe_auto #(DATA_T) DUT (.*);
            end : g__bus_pipe_auto

            "bus_width_converter_le": begin : g__bus_width_converter_le
                localparam type __DATA_T = logic[$bits(DATA_T)*2-1:0];
                bus_intf #(__DATA_T) __bus_if (.clk);
                bus_width_converter #(DATA_T, __DATA_T, .BIGENDIAN(0)) DUT1 (.from_tx, .to_rx (__bus_if));
                bus_width_converter #(__DATA_T, DATA_T, .BIGENDIAN(0)) DUT2 (.from_tx (__bus_if), .to_rx);
                initial skip_single_item_tc = 1'b1;
            end : g__bus_width_converter_le

            "bus_width_converter_be": begin : g__bus_width_converter_be
                localparam type __DATA_T = logic[$bits(DATA_T)*2-1:0];
                bus_intf #(__DATA_T) __bus_if (.clk);
                bus_width_converter #(DATA_T, __DATA_T, .BIGENDIAN(1)) DUT1 (.from_tx, .to_rx (__bus_if));
                bus_width_converter #(__DATA_T, DATA_T, .BIGENDIAN(1)) DUT2 (.from_tx (__bus_if), .to_rx);
                initial skip_single_item_tc = 1'b1;
            end : g__bus_width_converter_be
        endcase
    endgenerate

    //===================================
    // Testbench
    //===================================
    tb_env #(DATA_T) env;

    std_reset_intf reset_if (.clk(clk));

    logic skip_single_item_tc = 0; // Option to skip single item testcase
                                   // (not valid for width conversion test suite)

    // Assign reset interface
    assign from_tx.srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~reset_if.reset;

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create testbench environment
        env = new("tb_env", reset_if, from_tx, to_rx);
        env.build();
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        
        // Start environment
        env.run();
    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        // Stop environment
        env.stop();

        svunit_ut.teardown();
    endtask

    task automatic send_one(int id=0);
        automatic std_verif_pkg::raw_transaction#(DATA_T) transaction;
        automatic DATA_T data;
        void'(std::randomize(data));
        transaction = new($sformatf("trans_%0d",id), data);
        transaction .randomize();
        env.inbox.put(transaction);
    endtask

    task automatic send_stream(int NUM=100);
       for (int i = 0; i < NUM; i++) begin
           send_one(i);
       end
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

        string msg;

        //===================================
        // Test:
        //   reset
        //
        // Desc:
        //   Reset and check for reset done
        //===================================
        `SVTEST(reset)
        `SVTEST_END
        //===================================
        // Test:
        //   single_item
        //
        // Desc:
        //   send one item and check
        //===================================
        `SVTEST(single_item)
            // Build transaction
            DATA_T exp_item = 'hABAB_ABAB;
            std_verif_pkg::raw_transaction#(DATA_T) exp_transaction;
            exp_transaction = new("exp_transaction", exp_item);
            // Send transaction
            env.inbox.put(exp_transaction);
            
            // Check transaction
            #15us
            if (skip_single_item_tc) return;
            `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), 1);
        `SVTEST_END
        //===================================
        // Test:
        //   stream
        //
        // Desc:
        //   send stream of packets
        //===================================
        `SVTEST(stream)
            localparam NUM = 1000;
            // Send stream of transactions
            send_stream(NUM);
            // Check
            #20us `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), 1000);
        `SVTEST_END
        //===================================
        // Test:
        //   stream_stalls
        //
        // Desc:
        //   send stream of packets with (randomized) transmit stalls
        //===================================
        `SVTEST(stream_stalls)
            localparam NUM = 1000;
            env.driver.enable_stalls();
            // Send stream of transactions
            send_stream(NUM);
            // Check
            #60us `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), 1000);
        `SVTEST_END

        //===================================
        // Test:
        //   stream_backpressure
        //
        // Desc:
        //   send stream of packets with (randomized) receive stalls
        //===================================
        `SVTEST(stream_backpressure)
            localparam NUM = 1000;
            env.monitor.enable_stalls();
            // Send stream of transactions
            send_stream(NUM);
            // Check
            #60us `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), 1000);
        `SVTEST_END

        //===================================
        // Test:
        //   stream_backpressure
        //
        // Desc:
        //   send stream of packets with (randomized) receive stalls
        //===================================
        `SVTEST(stream_max_rate)
            localparam NUM = 1000;
            env.driver.set_tx_mode(TX_MODE_PUSH);
            // Send stream of transactions
            send_stream(NUM);
            #60us 
            env.driver.set_tx_mode(TX_MODE_SEND);
            // Check
            `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), 1000);
        `SVTEST_END

        //===================================
        // Test:
        //   stream_random
        //
        // Desc:
        //   send stream of packets with (randomized) transmit and receive stalls
        //===================================
        `SVTEST(stream_random)
            localparam NUM = 1000;
            env.driver.enable_stalls();
            env.monitor.enable_stalls();
            // Send stream of transactions
            send_stream(NUM);
            // Check
            #100us `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), 1000);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : bus_intf_unit_test



// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific bus component configuration in a way
//  that maintains SVUnit compatibility
`define BUS_INTF_UNIT_TEST(COMPONENT_NAME)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  bus_intf_unit_test #(COMPONENT_NAME) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  function void __register_tests();\
    test.__register_tests();\
  endfunction\
  task run();\
    test.run();\
  endtask


// Back-to-back bus interface connector
module bus_intf_connector_unit_test;
    `BUS_INTF_UNIT_TEST("bus_intf_connector");
endmodule

// Bus pipeline component (1-stage)
module bus_pipe_1st_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_1st");
endmodule

// Bus pipeline component (4-stage)
module bus_pipe_4st_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_4st");
endmodule

// SLR crossing pipeline stage
module bus_pipe_slr_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_slr");
endmodule

// Back-to-back SLR crossing pipeline stage
module bus_pipe_slr_b2b_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_slr_b2b");
endmodule

// Auto-pipelining component
module bus_pipe_auto_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_auto");
endmodule

// Bus width converter (little-endian)
module bus_width_converter_le_unit_test;
    `BUS_INTF_UNIT_TEST("bus_width_converter_le");
endmodule

// Bus width converter (big-endian)
module bus_width_converter_be_unit_test;
    `BUS_INTF_UNIT_TEST("bus_width_converter_be");
endmodule





