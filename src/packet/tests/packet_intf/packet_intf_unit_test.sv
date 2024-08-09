`include "svunit_defines.svh"

module packet_intf_unit_test #(
    parameter logic[2:0] DUT_SELECT = 0
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    localparam string dut_string = DUT_SELECT == 0 ? "packet_intf_connector" : 
                                                 1 ? "packet_fifo" :
                                                     "undefined";

    string name = $sformatf("packet_intf_dut_%s_ut", dut_string);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 8;
    localparam type META_T = logic[31:0];

    typedef packet#(META_T) PACKET_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) packet_in_if (.clk(clk), .srst(srst));
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) packet_out_if (.clk(clk), .srst(srst));


    generate
        case (DUT_SELECT)
            0: packet_intf_connector DUT (.from_tx(packet_in_if), .to_rx(packet_out_if));
            1: packet_fifo #(.DEPTH (16384)) DUT (.*);
        endcase
    endgenerate


    //===================================
    // Testbench
    //===================================
    packet_component_env #(
        DATA_BYTE_WID,
        META_T
    ) env;

    // Model
    std_verif_pkg::wire_model#(PACKET_T) model;
    std_verif_pkg::event_scoreboard#(PACKET_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !srst;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        model = new();
        scoreboard = new();

        env = new("env", model, scoreboard);
        env.reset_vif = reset_if;
        env.packet_in_vif = packet_in_if;
        env.packet_out_vif = packet_out_if;
        env.connect();

        env.set_debug_level(0);
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Reset environment
        env.reset();

        // Put interfaces in quiescent state
        env.idle();

        // Issue reset
        env.reset_dut();

        // Default settings for transmit and receive stall rate
        env.monitor.set_stall_rate(0.0);
        env.driver.set_stall_rate(0.0);

        // Start environment
        env.start();
    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();

        // Stop environment
        env.stop();
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

    task one_packet(int id=0, int len=$urandom_range(64, 511));
        packet_raw#(META_T) packet;
        META_T meta;
        packet = new($sformatf("pkt_%0d", id), len);
        packet.randomize();
        void'(std::randomize(meta));
        packet.set_meta(meta);
        env.inbox.put(packet);
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

        `SVTEST(one_packet_tpause_2)
            //env.monitor.set_tpause(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            //env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            //env.monitor.set_tpause(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            //env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            packet_raw#(META_T) packet;
            packet_raw#(META_T) bad_packet;
            // Create 'expected' transaction
            packet = new();
            packet.randomize();
            env.model.inbox.put(packet);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_packet = packet.clone("trans_0_bad");
            bad_byte_idx = $urandom % bad_packet.size();
            bad_byte_data = 8'hFF ^ bad_packet.get_byte(bad_byte_idx);
            bad_packet.set_byte(bad_byte_idx, bad_byte_data);
            env.driver.inbox.put(bad_packet);
            packet_in_if._wait(1000);
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule


// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific AXI4S DUT in a way
//  that maintains SVUnit compatibility
`define PACKET_UNIT_TEST(DUT_SELECT)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_intf_unit_test #(DUT_SELECT) test();\
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


module packet_intf_connector_unit_test;
`PACKET_UNIT_TEST(0)
endmodule

module packet_fifo_unit_test;
`PACKET_UNIT_TEST(1)
endmodule
