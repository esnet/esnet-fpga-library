`include "svunit_defines.svh"

module axi4s_pad_unit_test;

    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;
    import axi4s_verif_pkg::*;

    string name = "axi4s_pad_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 64;
    localparam type TID_T = bit;
    localparam type TDEST_T = bit;
    localparam type TUSER_T = bit;

    typedef axi4s_transaction#(TID_T,TDEST_T,TUSER_T) AXI4S_TRANSACTION_T;

    //===================================
    // DUT
    //===================================
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_in_if ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_out_if ();

    axi4s_pad #(.BIGENDIAN(1)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));

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

    AXI4S_TRANSACTION_T  axis_transaction_in, axis_transaction_out;

    string msg;

    task one_packet(input int len=64);
       // Create 'input' transaction.
       axis_transaction_in = new("trans_0_in", len);
       axis_transaction_in.randomize();

       // Create 'output' transaction.
       if (len < 60) begin // output pkt is zero padded to 60B.
          axis_transaction_out = new("trans_0_out", .len(60));
          axis_transaction_out.randomize();
          for (int i=0;   i<len; i++) axis_transaction_out.set_byte(i, axis_transaction_in.get_byte(i));
          for (int i=len; i<60;  i++) axis_transaction_out.set_byte(i, 8'h00);
       end else begin // output pkt = input pkt.
          axis_transaction_out = axis_transaction_in.clone("trans_0_out");
       end

       // Put 'input' and 'output' transactions.
       env.model.inbox.put(axis_transaction_out);
       env.driver.inbox.put(axis_transaction_in);
    endtask

    task packet_stream();
       for (int i = 1; i < 256; i++) begin
           one_packet(i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg), msg );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
