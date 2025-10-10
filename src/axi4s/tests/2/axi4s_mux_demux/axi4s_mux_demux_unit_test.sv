`include "svunit_defines.svh"

module axi4s_mux_demux_unit_test;

    import svunit_pkg::svunit_testcase;
    import axi4s_verif_pkg::*;

    string name = "axi4s_mux_demux_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int N = 3;
    localparam int SEL_WID = N > 1 ? $clog2(N) : 1;
    localparam int TARGET_PORT = 0;
    localparam int DATA_BYTE_WID = 64;
    localparam int DATA_WID = DATA_BYTE_WID * 8;
    localparam int TID_WID = SEL_WID;
    localparam int TDEST_WID = SEL_WID;
    localparam int TUSER_WID = 32;


    localparam type TID_T   = bit[TID_WID-1:0];
    localparam type TDEST_T = bit[TDEST_WID-1:0];
    localparam type TUSER_T = bit[TUSER_WID-1:0];

    typedef axi4s_transaction#(TID_T,TDEST_T,TUSER_T) AXI4S_TRANSACTION_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) from_tx [N] (.aclk(clk));
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axis_int  (.aclk(clk));
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) to_rx   [N] (.aclk(clk));

    axi4s_mux #(.N(N))        DUT_mux (.srst, .axi4s_in(from_tx), .axi4s_out(__axis_int));
    axi4s_intf_demux #(.N(N)) DUT_demux (.srst, .from_tx(__axis_int), .to_rx, .sel(__axis_int.tdest));

    //===================================
    // Testbench
    //===================================
    // Environment(s)
    axi4s_component_env#(DATA_BYTE_WID, TID_T, TDEST_T, TUSER_T) env [N];

    // Reset
    std_reset_intf reset_if [N] (.clk);
    assign srst = reset_if[0].reset;

    generate
        for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
            assign reset_if[g_if].ready = !srst;
            initial begin
                wait(env[g_if] != null);
                env[g_if].reset_vif = reset_if[g_if];
                env[g_if].axis_in_vif = from_tx[g_if];
                env[g_if].axis_out_vif = to_rx[g_if];
                env[g_if].build();
            end
        end : g__if
    endgenerate

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        // Environment
        for (int i = 0; i < N; i++) begin
            std_verif_pkg::wire_model#(AXI4S_TRANSACTION_T) model;
            std_verif_pkg::event_scoreboard#(AXI4S_TRANSACTION_T) scoreboard;
            model = new($sformatf("model[%0d]", i));
            scoreboard = new($sformatf("scoreboard[%0d]",i));
            env[i] = new($sformatf("env[%0d]", i), model, scoreboard);
        end
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        for (int i = 0; i < N; i++) do @(posedge clk); while (!env[i].is_built());

        // Start environment
        for (int i = 0; i < N; i++) env[i].run();
    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();

        // Stop environment
        for (int i = 0; i < N; i++) env[i].stop();

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

    task one_packet(input bit[SEL_WID-1:0] inport=0, int id=0, int len=$urandom_range(64, 511));
        AXI4S_TRANSACTION_T axis_transaction;
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;
        void'(std::randomize(tid));
        tdest = inport;
        void'(std::randomize(tuser));
        axis_transaction = new($sformatf("trans_%0d",id), len);
        axis_transaction.randomize();
        axis_transaction.set_tid(inport);
        axis_transaction.set_tdest(tdest);
        axis_transaction.set_tuser(tuser);
        env[inport].inbox.put(axis_transaction);
    endtask

    task packet_stream(input bit[SEL_WID-1:0] inport=0);
       for (int i = 0; i < 100; i++) begin
           one_packet(inport, i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(one_packet_good)
            len = $urandom_range(64, 511);
            for (int i = 0; i < N; i++) one_packet(i);
            #10us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2)
            for (int i = 0; i < N; i++) env[i].monitor.set_tpause(2);
            for (int i = 0; i < N; i++) one_packet(i);
            #10us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            for (int i = 0; i < N; i++) env[i].driver.set_twait(2);
            for (int i = 0; i < N; i++) one_packet(i);
            #10us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            for (int i = 0; i < N; i++) env[i].monitor.set_tpause(2);
            for (int i = 0; i < N; i++) env[i].driver.set_twait(2);
            for (int i = 0; i < N; i++) one_packet(i);
            #10us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            for (int i = 0; i < N; i++) packet_stream(i);
            #100us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            for (int i = 0; i < N; i++) env[i].monitor.set_tpause(2);
            for (int i = 0; i < N; i++) packet_stream(i);
            #100us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            for (int i = 0; i < N; i++) env[i].driver.set_twait(2);
            for (int i = 0; i < N; i++) packet_stream(i);
            #100us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            for (int i = 0; i < N; i++) env[i].monitor.set_tpause(2);
            for (int i = 0; i < N; i++) env[i].driver.set_twait(2);
            for (int i = 0; i < N; i++) packet_stream(i);
            #100us
            for (int i = 0; i < N; i++) `FAIL_IF_LOG( env[i].scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            AXI4S_TRANSACTION_T axis_transaction;
            AXI4S_TRANSACTION_T bad_transaction;
            // Create 'expected' transaction
            axis_transaction = new("trans_0");
            axis_transaction.randomize();
            env[0].model.inbox.put(axis_transaction);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_transaction = axis_transaction.dup("trans_0_bad");
            bad_byte_idx = $urandom % bad_transaction.size();
            bad_byte_data = 8'hFF ^ bad_transaction.get_byte(bad_byte_idx);
            bad_transaction.set_byte(bad_byte_idx, bad_byte_data);
            env[0].driver.inbox.put(bad_transaction);
            from_tx[0]._wait(1000);
            `FAIL_UNLESS_LOG(
                env[0].scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

        `SVTEST(finalize)
            for (int i = 0; i < N; i++) env[i].finalize();
        `SVTEST_END


    `SVUNIT_TESTS_END

endmodule : axi4s_mux_demux_unit_test
