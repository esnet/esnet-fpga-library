`include "svunit_defines.svh"

module axi4s_intf_unit_test #(
    parameter logic[2:0] DUT_SELECT = 0
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;
    import axi4s_verif_pkg::*;

    localparam string dut_string = DUT_SELECT == 0 ? "axi4s_intf_connector" :
                                   DUT_SELECT == 1 ? "axi4s_int_pipe" :
                                   DUT_SELECT == 2 ? "axi4s_tready_pipe" :
                                   DUT_SELECT == 3 ? "axi4s_full_pipe" :
                                   DUT_SELECT == 4 ? "axi4s_fifo_sync_32d" :
                                   DUT_SELECT == 5 ? "axi4s_fifo_sync_512d" :
                                   DUT_SELECT == 6 ? "axi4s_fifo_sync_8192d" : "undefined";

    string name = $sformatf("axi4s_intf_dut_%s_ut", dut_string);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 8;
    localparam type TID_T = bit;
    localparam type TDEST_T = bit;
    localparam type TUSER_T = bit;

    typedef axi4s_transaction#(TID_T,TDEST_T,TUSER_T) AXI4S_TRANSACTION_T;

    //===================================
    // DUT
    //===================================
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_in_if ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_out_if ();

    generate
      case (DUT_SELECT)
         0: axi4s_intf_connector DUT (.axi4s_from_tx(axis_in_if), .axi4s_to_rx(axis_out_if));

         1: axi4s_intf_pipe DUT (.axi4s_if_from_tx(axis_in_if), .axi4s_if_to_rx(axis_out_if));

         2: axi4s_tready_pipe DUT (.axi4s_if_from_tx(axis_in_if), .axi4s_if_to_rx(axis_out_if));

         3: axi4s_full_pipe DUT (.axi4s_if_from_tx(axis_in_if), .axi4s_if_to_rx(axis_out_if));

         4: axi4s_fifo_sync #(.DEPTH(32))   DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
         5: axi4s_fifo_sync #(.DEPTH(512))  DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
         6: axi4s_fifo_sync #(.DEPTH(8192)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
      endcase
   endgenerate


    //===================================
    // Testbench
    //===================================
    axi4s_component_env #(
        DATA_BYTE_WID,
        TID_T,
        TDEST_T,
        TUSER_T
    ) env;

    // Model
    std_verif_pkg::wire_model#(AXI4S_TRANSACTION_T) model;
    std_verif_pkg::event_scoreboard#(AXI4S_TRANSACTION_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(axis_in_if.aclk));
    assign axis_in_if.aresetn = !reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(axis_in_if.aclk, 1.5ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        model = new();
        scoreboard = new();

        env = new("env", model, scoreboard);
        env.reset_vif = reset_if;
        env.axis_in_vif = axis_in_if;
        env.axis_out_vif = axis_out_if;
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

        // Default settings for tpause and twait
        env.monitor.set_tpause(0);
        env.driver.set_twait(0);

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

    AXI4S_TRANSACTION_T axis_transaction;
    packet_raw packet;

    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 511));
       packet = new($sformatf("pkt_%0d", id), len);
       packet.randomize();
       axis_transaction = new($sformatf("trans_%0d",id), packet);
       env.inbox.put(axis_transaction);
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
            env.monitor.set_tpause(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            env.monitor.set_tpause(2);
            env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            env.monitor.set_tpause(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            env.monitor.set_tpause(2);
            env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            packet_raw bad_packet;
            AXI4S_TRANSACTION_T bad_axis_transaction;
            // Create 'expected' transaction
            packet = new();
            packet.randomize();
            axis_transaction = new("trans_0", packet);
            env.model.inbox.put(axis_transaction);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_packet = packet.clone("trans_0_bad");
            bad_byte_idx = $urandom % bad_packet.size();
            bad_byte_data = 8'hFF ^ bad_packet.get_byte(bad_byte_idx);
            bad_packet.set_byte(bad_byte_idx, bad_byte_data);
            bad_axis_transaction = new("trans_0_bad", bad_packet);
            env.driver.inbox.put(bad_axis_transaction);
            axis_in_if._wait(1000);
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
`define AXI4S_UNIT_TEST(DUT_SELECT)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  axi4s_intf_unit_test #(DUT_SELECT) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask


module axi4s_intf_connector_unit_test;
`AXI4S_UNIT_TEST(0)
endmodule

module axi4s_intf_pipe_unit_test;
`AXI4S_UNIT_TEST(1)
endmodule

module axi4s_tready_pipe_unit_test;
`AXI4S_UNIT_TEST(2)
endmodule

module axi4s_full_pipe_unit_test;
`AXI4S_UNIT_TEST(3)
endmodule

module axi4s_fifo_sync_32d_unit_test;
`AXI4S_UNIT_TEST(4)
endmodule

module axi4s_fifo_sync_512d_unit_test;
`AXI4S_UNIT_TEST(5)
endmodule

module axi4s_fifo_sync_8192d_unit_test;
`AXI4S_UNIT_TEST(6)
endmodule
