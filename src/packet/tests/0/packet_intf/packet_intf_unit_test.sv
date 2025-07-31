`include "svunit_defines.svh"

module packet_intf_unit_test #(
    parameter string DUT_SELECT = "packet_intf_connector"
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = $sformatf("packet_intf_dut_%s_ut", DUT_SELECT);
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

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) from_tx (.clk, .srst);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) to_rx (.clk, .srst);


    generate
        case (DUT_SELECT)
            "packet_intf_connector": packet_intf_connector DUT (.*);
            "packet_fifo": packet_fifo #(.DEPTH (2048)) DUT (.packet_in_if(from_tx), .packet_out_if(to_rx));
            "packet_pipe_1st": packet_pipe #(.STAGES(1)) DUT (.*);
            "packet_pipe_4st": packet_pipe #(.STAGES(4)) DUT (.*);
            "packet_pipe_auto": packet_pipe_auto DUT (.*);
            "packet_pipe_slr": packet_pipe_slr DUT (.*);
            "packet_pipe_slr_p1_p1": packet_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT (.*);
            "packet_intf_width_converter": begin : g__packet_intf_width_converter
                packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID*8), .META_T(META_T)) __packet_if (.clk, .srst);
                packet_intf_width_converter DUT1 (.from_tx, .to_rx(__packet_if));
                packet_intf_width_converter DUT2 (.from_tx(__packet_if), .to_rx);
            end : g__packet_intf_width_converter
        endcase
    endgenerate


    //===================================
    // Testbench
    //===================================
    packet_component_env #(META_T) env;

    packet_intf_driver#(DATA_BYTE_WID, META_T) driver;
    packet_intf_monitor#(DATA_BYTE_WID, META_T) monitor;

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

        // Driver
        driver = new();
        driver.packet_vif = from_tx;

        // Monitor
        monitor = new();
        monitor.packet_vif = to_rx;

        model = new();
        scoreboard = new();

        env = new("env", driver, monitor, model, scoreboard);
        env.reset_vif = reset_if;
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
    localparam int NUM_PKTS = 100;
    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 511));
        packet_raw#(META_T) packet;
        META_T meta;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
        env.inbox.put(packet);
    endtask

    task packet_stream(int NUM = NUM_PKTS);
        for (int i = 0; i < NUM_PKTS; i++) begin
            one_packet(i);
        end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(one_packet_good)
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(one_packet_tpause_2)
            //env.monitor.set_tpause(2);
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            //env.driver.set_twait(2);
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            check(NUM_PKTS, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            //env.monitor.set_tpause(2);
            packet_stream();
            check(NUM_PKTS, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            //env.driver.set_twait(2);
            packet_stream();
            check(NUM_PKTS, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            packet_stream();
            check(NUM_PKTS, 100us);
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            packet_raw#(META_T) pkt;
            packet#(META_T) bad_pkt;
            // Create 'expected' transaction
            pkt = new();
            pkt.randomize();
            env.model.inbox.put(pkt);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_pkt = pkt.dup("trans_0_bad");
            bad_byte_idx = $urandom % bad_pkt.size();
            bad_byte_data = 8'hFF ^ bad_pkt.get_byte(bad_byte_idx);
            bad_pkt.set_byte(bad_byte_idx, bad_byte_data);
            env.driver.inbox.put(bad_pkt);
            #5us
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

    task check(input int EXPECTED, input time TIMEOUT);
        fork
            begin
                string msg;
                #(TIMEOUT);
                `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg);
                $display($sformatf("%d", env.scoreboard.got_processed()));
                `FAIL_IF_LOG(1, "Timeout waiting for expected transactions.");
            end
            begin
                string msg;
                int processed;
                do
                    #100ns;
                while ( env.scoreboard.got_processed() != EXPECTED );
                `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg);
                `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), EXPECTED);
            end
        join_any
        disable fork;
    endtask

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
`PACKET_UNIT_TEST("packet_intf_connector")
endmodule

module packet_fifo_unit_test;
`PACKET_UNIT_TEST("packet_fifo")
endmodule

module packet_pipe_1st_unit_test;
`PACKET_UNIT_TEST("packet_pipe_1st")
endmodule

module packet_pipe_4st_unit_test;
`PACKET_UNIT_TEST("packet_pipe_4st")
endmodule

module packet_pipe_auto_unit_test;
`PACKET_UNIT_TEST("packet_pipe_auto")
endmodule

module packet_pipe_slr_unit_test;
`PACKET_UNIT_TEST("packet_pipe_slr")
endmodule

module packet_pipe_slr_p1_p1_unit_test;
`PACKET_UNIT_TEST("packet_pipe_slr_p1_p1")
endmodule

module packet_intf_width_converter_unit_test;
`PACKET_UNIT_TEST("packet_intf_width_converter")
endmodule
