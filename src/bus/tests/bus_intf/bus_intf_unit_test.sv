`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module bus_intf_unit_test #(
    parameter string COMPONENT_NAME = "bus_intf"
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("%s_ut", COMPONENT_NAME);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type DATA_T = bit[31:0];

    //===================================
    // DUT
    //===================================

    logic   clk;
    
    bus_intf #(DATA_T) bus_if_from_tx (.clk(clk));
    bus_intf #(DATA_T) bus_if_to_rx (.clk(clk));

    generate
        case (COMPONENT_NAME)
            "bus_intf_connector" : begin : g__bus_intf_connector
                bus_intf_connector DUT (.*);
            end : g__bus_intf_connector
            
            "bus_pipe" : begin : g__bus_pipe
                bus_pipe #(.STAGES(4)) DUT (.*);
            end : g__bus_pipe

            "bus_pipe_slr" : begin : g__bus_pipe_slr
                bus_pipe_slr DUT (.*);
            end : g__bus_pipe_slr

            "bus_pipe_auto" : begin : g__bus_pipe_auto
                bus_pipe_auto DUT (.*);
            end : g__bus_pipe_auto
        endcase
    endgenerate

    //===================================
    // Testbench
    //===================================
    tb_env #(DATA_T) env;

    std_reset_intf reset_if (.clk(clk));

    // Assign reset interface
    assign bus_if_from_tx.srst = reset_if.reset;

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
        env = new("tb_env", reset_if, bus_if_from_tx, bus_if_to_rx);
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
            #15us `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
        `SVTEST_END
        //===================================
        // Test:
        //   stream
        //
        // Desc:
        //   send one item and check
        //===================================
        `SVTEST(stream)
            localparam NUM = 1000;
            // Send stream of transactions
            send_stream(NUM);
            // Check
            #15us `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
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

// Bus pipeline component
module bus_pipe_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe");
endmodule

// SLR crossing pipeline stage
module bus_pipe_slr_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_slr");
endmodule

// Auto-pipelining component
module bus_pipe_auto_unit_test;
    `BUS_INTF_UNIT_TEST("bus_pipe_auto");
endmodule


