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
    logic clk;
    logic srst;
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_in_if (.aclk(clk));
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_out_if (.aclk(clk));

    axi4s_pad #() DUT (.srst, .axi4s_in(axis_in_if), .axi4s_out(axis_out_if));

    //===================================
    // Testbench
    //===================================
    axi4s_component_env #(
        DATA_BYTE_WID,
        TID_T,
        TDEST_T,
        TUSER_T
    ) env;

    class axi4s_pad_model#(parameter int MIN_PKT_SIZE=60) extends std_verif_pkg::model#(AXI4S_TRANSACTION_T,AXI4S_TRANSACTION_T);
        function new(string name="axi4s_pad_model");
            super.new(name);
        endfunction
        protected task _process(input AXI4S_TRANSACTION_T transaction);
            AXI4S_TRANSACTION_T padded_transaction;
            if (transaction.size() < MIN_PKT_SIZE) begin
                padded_transaction = new(
                    .name($sformatf("trans_%0d_out", num_input_transactions())), .len(MIN_PKT_SIZE),
                    .tid(transaction.get_tid()), .tdest(transaction.get_tdest()), .tuser(transaction.get_tuser())
                );
                for (int i = 0; i < transaction.size(); i++) padded_transaction.set_byte(i, transaction.get_byte(i));
                for (int i = transaction.size(); i < MIN_PKT_SIZE; i++) padded_transaction.set_byte(i, 8'h0);
                _enqueue(padded_transaction);
            end else _enqueue(transaction);
        endtask
    endclass

    // Model
    axi4s_pad_model model;
    std_verif_pkg::event_scoreboard#(AXI4S_TRANSACTION_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(axis_in_if.aclk));
    assign reset_if.ready = !reset_if.reset;
    assign srst = reset_if.reset;

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
        env.axis_in_vif = axis_in_if;
        env.axis_out_vif = axis_out_if;
        env.build();

        env.set_debug_level(0);
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

    // Create and send input transaction
    task automatic one_packet(input int len=64);
        AXI4S_TRANSACTION_T  axis_transaction_in;
        axis_transaction_in = new("trans_0_in", len);
        axis_transaction_in.randomize();
        env.inbox.put(axis_transaction_in);
    endtask

    task automatic packet_stream();
       for (int i = 1; i < 256; i++) begin
           one_packet(i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG(scoreboard.report(msg), msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), 255);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
