`include "svunit_defines.svh"

module packet_aggregate_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "packet_aggregate_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int NUM_INPUTS = 3;
    localparam int DATA_IN_BYTE_WID = 16;

    localparam int DATA_OUT_BYTE_WID = 64;
    localparam type META_T = logic[31:0];

    localparam int CTXT_WID = $clog2(NUM_INPUTS);
    localparam type CTXT_T = logic[CTXT_WID-1:0];

    typedef packet#(META_T) PACKET_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    packet_intf #(.DATA_BYTE_WID(DATA_IN_BYTE_WID),  .META_T(META_T)) packet_in_if  [NUM_INPUTS] (.clk, .srst);
    packet_intf #(.DATA_BYTE_WID(DATA_OUT_BYTE_WID), .META_T(META_T)) packet_out_if              (.clk, .srst);

    packet_event_intf event_in_if  [NUM_INPUTS] (.clk);
    packet_event_intf event_out_if (.clk);

    CTXT_T ctxt_sel;
    logic  ctxt_list_append_rdy;
    logic  ctxt_out_valid;
    CTXT_T ctxt_out;

    packet_aggregate #(
        .NUM_INPUTS   ( NUM_INPUTS )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    packet_component_env #(META_T) env;

    for (genvar g_input = 1; g_input < NUM_INPUTS; g_input++) begin : g__input
        packet_intf_tx_term i_packet_intf_tx_term (.to_rx (packet_in_if[g_input]));
    end : g__input

    packet_intf_driver#(DATA_IN_BYTE_WID, META_T) driver;
    packet_intf_monitor#(DATA_OUT_BYTE_WID, META_T) monitor;

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
        driver.packet_vif = packet_in_if[0];

        // Monitor
        monitor = new();
        monitor.packet_vif = packet_out_if;

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

    META_T meta;
    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 511));
        packet_raw#(META_T) packet;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
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
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_63B)
            one_packet(.len(63));
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_64B)
            one_packet(.len(64));
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_65B)
            one_packet(.len(65));
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
            packet_in_if[0]._wait(1000);
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
