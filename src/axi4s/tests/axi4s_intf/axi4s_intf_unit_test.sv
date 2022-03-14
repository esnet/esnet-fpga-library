`include "svunit_defines.svh"

module axi4s_intf_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;
    import axi4s_verif_pkg::*;

    string name = "axi4s_intf_ut";
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
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_if ();

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
    std_reset_intf reset_if (.clk(axis_if.aclk));
    assign axis_if.aresetn = !reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(axis_if.aclk, 1.5ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        model = new();
        scoreboard = new();

        env = new("env", model, scoreboard);
        env.reset_vif = reset_if;
        env.axis_in_vif = axis_if;
        env.axis_out_vif = axis_if;
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

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(one_packet_good)
            AXI4S_TRANSACTION_T axis_transaction;
            packet_raw packet;
            
            packet = new();
            packet.randomize();
            axis_transaction = new("trans_0", packet);
            env.inbox.put(axis_transaction);
            #10us
            `FAIL_IF_LOG(
                scoreboard.report(msg),
                msg
            );
        `SVTEST_END

        `SVTEST(packet_stream)
            AXI4S_TRANSACTION_T axis_transaction;
            packet_raw packet;
            
            for (int i = 0; i < 1000; i++) begin
                packet = new();
                packet.randomize();
                axis_transaction = new($sformatf("trans_%0d", i), packet);
                env.inbox.put(axis_transaction);
            end
            #100us
            `FAIL_IF_LOG(
                scoreboard.report(msg),
                msg
            );
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            packet_raw packet;
            packet_raw bad_packet;
            AXI4S_TRANSACTION_T axis_transaction;
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
            axis_if._wait(1000);
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
