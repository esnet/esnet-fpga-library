`include "svunit_defines.svh"

module packet_descriptor_intf_unit_test #(
    parameter logic[2:0] DUT_SELECT = 0
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    localparam string dut_string = DUT_SELECT == 0 ? "packet_descriptor_intf_connector" : "undefined";

    string name = $sformatf("packet_descriptor_intf_dut_%s_ut", dut_string);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type ADDR_T = bit[31:0];
    localparam type META_T = bit[15:0];

    typedef packet_descriptor#(ADDR_T,META_T) PACKET_DESCRIPTOR_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) packet_descriptor_in_if (.clk(clk));
    packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) packet_descriptor_out_if (.clk(clk));

    generate
      case (DUT_SELECT)
         0: packet_descriptor_intf_connector DUT (.from_tx(packet_descriptor_in_if), .to_rx(packet_descriptor_out_if));
      endcase
   endgenerate


    //===================================
    // Testbench
    //===================================
    std_verif_pkg::component_env #(
        PACKET_DESCRIPTOR_T,
        PACKET_DESCRIPTOR_T
    ) env;

    // Driver/monitor
    packet_descriptor_driver#(ADDR_T,META_T) driver;
    packet_descriptor_monitor#(ADDR_T,META_T) monitor;

    // Model
    std_verif_pkg::wire_model#(PACKET_DESCRIPTOR_T) model;
    std_verif_pkg::event_scoreboard#(PACKET_DESCRIPTOR_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        driver = new();
        driver.packet_descriptor_vif = packet_descriptor_in_if;

        monitor = new();
        monitor.packet_descriptor_vif = packet_descriptor_out_if;

        model = new();
        scoreboard = new();

        env = new("env");
        env.reset_vif = reset_if;
        env.driver = driver;
        env.monitor = monitor;
        env.model = model;
        env.scoreboard = scoreboard;
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

    string msg;
    int len;

    task one_packet(int id=0);
        PACKET_DESCRIPTOR_T packet_descriptor;
        packet_descriptor = new($sformatf("pkt_%0d", id));
        packet_descriptor.randomize();
        env.inbox.put(packet_descriptor);
    endtask

    task packet_stream();
       for (int i = 0; i < 100; i++) begin
           one_packet(i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(one_packet_good)
            len = $urandom_range(64, 511);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_bad)
            PACKET_DESCRIPTOR_T packet;
            PACKET_DESCRIPTOR_T bad_packet;
            // Create 'expected' transaction
            packet = new();
            packet.randomize();
            env.model.inbox.put(packet);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_packet = packet.dup("trans_0_bad");
            bad_packet.addr++;
            env.driver.inbox.put(bad_packet);
            packet_descriptor_in_if._wait(1000);
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule


// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific packet_descriptor_intf DUT in a way
//  that maintains SVUnit compatibility
`define PACKET_DESCRIPTOR_UNIT_TEST(DUT_SELECT)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_descriptor_intf_unit_test #(DUT_SELECT) test();\
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


module packet_descriptor_intf_connector_unit_test;
`PACKET_DESCRIPTOR_UNIT_TEST(0)
endmodule
