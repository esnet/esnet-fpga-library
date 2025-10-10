`include "svunit_defines.svh"

module axi4s_intf_unit_test #(
    parameter int DUT_SELECT = 0
);
    import svunit_pkg::svunit_testcase;
    import axi4s_verif_pkg::*;

    localparam string dut_string = DUT_SELECT ==  0 ? "axi4s_intf_connector" :
                                   DUT_SELECT ==  1 ? "axi4s_int_pipe" :
                                   DUT_SELECT ==  2 ? "axi4s_tready_pipe" :
                                   DUT_SELECT ==  3 ? "axi4s_full_pipe" :
                                   DUT_SELECT ==  4 ? "axi4s_fifo_sync_32d" :
                                   DUT_SELECT ==  5 ? "axi4s_fifo_sync_512d" :
                                   DUT_SELECT ==  6 ? "axi4s_fifo_sync_8192d" :
                                   DUT_SELECT ==  7 ? "axi4s_fifo_async_32d" :
                                   DUT_SELECT ==  8 ? "axi4s_fifo_async_512d" :
                                   DUT_SELECT ==  9 ? "axi4s_fifo_async_8192d" :
                                   DUT_SELECT == 10 ? "axi4s_pkt_fifo_async_default" :
                                   DUT_SELECT == 11 ? "axi4s_pkt_fifo_async_st_fwd" :
                                   DUT_SELECT == 12 ? "axi4s_pkt_fifo_sync" :
                                   DUT_SELECT == 13 ? "axi4s_packet_adapter" :
                                   DUT_SELECT == 14 ? "axi4s_pipe" :
                                   DUT_SELECT == 15 ? "axi4s_pipe_auto" :
                                   DUT_SELECT == 16 ? "axi4s_pipe_slr" :
                                   DUT_SELECT == 17 ? "axi4s_pipe_slr_p1_p1" :
                                   DUT_SELECT == 18 ? "axi4s_pipe_slr_b2b" :
                                   DUT_SELECT == 19 ? "axi4s_pipe_slr_to_pipe" :
                                   DUT_SELECT == 20 ? "axi4s_pipe_to_pipe_slr" :
                                   DUT_SELECT == 21 ? "axi4s_width_converter" : "undefined";

    string name = $sformatf("axi4s_intf_dut_%s_ut", dut_string);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 8;
    localparam type TID_T = bit[7:0];
    localparam type TDEST_T = bit[11:0];
    localparam type TUSER_T = bit[31:0];

    typedef axi4s_transaction#(TID_T,TDEST_T,TUSER_T) AXI4S_TRANSACTION_T;

    localparam int TID_WID = $bits(TID_T);
    localparam int TDEST_WID = $bits(TDEST_T);
    localparam int TUSER_WID = $bits(TUSER_T);

    //===================================
    // DUT
    //===================================
    logic aclk_in;
    logic aclk_out;
    logic aclk_out_gen;
    logic srst;
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) from_tx (.aclk(aclk_in));
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) to_rx   (.aclk(aclk_out));

    axi4l_intf  axil_to_probe ();
    axi4l_intf  axil_to_ovfl  ();
    axi4l_intf  axil_if ();

    axi4l_intf_controller_term axi4l_to_probe_controller_term (.axi4l_if(axil_to_probe));
    axi4l_intf_controller_term axi4l_to_ovfl_controller_term  (.axi4l_if(axil_to_ovfl));
    axi4l_intf_controller_term axi4l_if_controller_term       (.axi4l_if(axil_if));

    logic tvalid_check = 0;

    bit ASYNC = 0;

    generate
      case (DUT_SELECT)
         0: axi4s_intf_connector DUT (.*);
         1: axi4s_intf_pipe      DUT (.*);
         2: axi4s_tready_pipe    DUT (.*);
         3: axi4s_full_pipe      DUT (.*);

         4: axi4s_fifo_sync  #(.DEPTH(  32)) DUT (.*);
         5: axi4s_fifo_sync  #(.DEPTH( 512)) DUT (.*);
         6: axi4s_fifo_sync  #(.DEPTH(8192)) DUT (.*);

         7: begin
                axi4s_fifo_async #(.DEPTH(  32)) DUT (.from_tx_srst(srst), .to_rx_srst(srst), .*);
                assign ASYNC = 1;
               `SVUNIT_CLK_GEN(aclk_out_gen, 1.0ns);  // slow to fast
            end

         8: begin
                axi4s_fifo_async #(.DEPTH( 512)) DUT (.from_tx_srst(srst), .to_rx_srst(srst), .*);
                assign ASYNC = 1;
               `SVUNIT_CLK_GEN(aclk_out_gen, 1.5ns);
            end

         9: begin
                axi4s_fifo_async #(.DEPTH(8192)) DUT (.from_tx_srst(srst), .to_rx_srst(srst), .*);
                assign ASYNC = 1;
               `SVUNIT_CLK_GEN(aclk_out_gen, 2.0ns);  // fast to slow
            end

         10: begin
                axi4s_pkt_fifo_async DUT ( 
                                           .axi4s_in(from_tx), .axi4s_in_srst(srst), .axi4s_out(to_rx), .axi4s_out_srst(srst),
                                           .flow_ctl_thresh('0), .flow_ctl(),
                                           .axil_to_probe(axil_to_probe), .axil_to_ovfl(axil_to_ovfl), .axil_if(axil_if) );
                assign ASYNC = 1;
               `SVUNIT_CLK_GEN(aclk_out_gen, 2.0ns);  // fast to slow
            end

         11: begin
                assign tvalid_check = 1;

                axi4s_pkt_fifo_async #(.TX_THRESHOLD(512)) DUT (
                                           .axi4s_in(from_tx), .axi4s_in_srst(srst), .axi4s_out(to_rx), .axi4s_out_srst(srst),
                                           .flow_ctl_thresh('0), .flow_ctl(),
                                           .axil_to_probe(axil_to_probe), .axil_to_ovfl(axil_to_ovfl), .axil_if(axil_if) );
                assign ASYNC = 1;
               `SVUNIT_CLK_GEN(aclk_out_gen, 1.0ns);  // slow to fast
            end

         12: begin
                axi4s_pkt_fifo_sync DUT ( .srst, .axi4s_in(from_tx), .axi4s_out(to_rx),
                                          .axil_to_probe(axil_to_probe), .axil_to_ovfl(axil_to_ovfl), .axil_if(axil_if),
                                          .oflow() );
            end
         13: begin
                localparam type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};
                localparam int META_WID = $bits(META_T);
                bit err; META_T meta, packet_if_meta;
                TID_T tid; TDEST_T tdest; TUSER_T tuser;

                packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_if (.clk(from_tx.aclk));

                assign err = 1'b0;
                assign meta.tid = from_tx.tid;
                assign meta.tdest = from_tx.tdest;
                assign meta.tuser = from_tx.tuser;
                axi4s_to_packet_adapter #(.META_WID(META_WID)) DUT_0 (.axis_if(from_tx), .*);
                assign packet_if_meta = packet_if.meta;
                assign tid = packet_if_meta.tid;
                assign tdest = packet_if_meta.tdest;
                assign tuser = packet_if_meta.tuser;
                axi4s_from_packet_adapter #(.TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) DUT_1 (.axis_if(to_rx), .*);
        end
        14 : axi4s_pipe #(.STAGES(2)) DUT (.*);
        15 : axi4s_pipe_auto DUT (.*);
        16 : axi4s_pipe_slr DUT (.*);
        17 : axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT (.*);
        18 : begin
            axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axis_if (.aclk(aclk_in));
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT1 (.srst, .from_tx, .to_rx ( __axis_if ));
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT2 (.srst, .from_tx ( __axis_if ),  .to_rx);
        end
        19 : begin
            axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axis_if (.aclk(aclk_in));
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT1 (.srst, .from_tx, .to_rx ( __axis_if ));
            axi4s_pipe #(.STAGES(1)) DUT2 (.srst, .from_tx ( __axis_if ), .to_rx);
        end
        20 : begin
            axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axis_if (.aclk(aclk_in));
            axi4s_pipe #(.STAGES(1)) DUT1 (.srst, .from_tx, .to_rx ( __axis_if ));
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT2 (.srst, .from_tx ( __axis_if ), .to_rx);
        end
        21 : begin
            axi4s_intf #(.DATA_BYTE_WID(4*DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) __axis_if (.aclk(aclk_in));
            axi4s_width_converter #() DUT1 (.srst, .from_tx, .to_rx (__axis_if ));
            axi4s_width_converter #() DUT2 (.srst, .from_tx (__axis_if ), .to_rx);
        end
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
    std_reset_intf reset_if (.clk(from_tx.aclk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(aclk_in, 1.5ns);

    always_comb begin
        if (ASYNC) aclk_out = aclk_out_gen;
        else       aclk_out = aclk_in;
    end

    // Checking logic
    logic rx_sop;
    logic pkt_pending, pkt_pending_ff;

    initial rx_sop = 1'b1;
    always @(posedge to_rx.aclk) begin
        if (srst) rx_sop <= 1'b1;
        else begin
            if (to_rx.tvalid && to_rx.tready && to_rx.tlast) rx_sop <= 1'b1;
            else if (to_rx.tvalid && to_rx.tready)           rx_sop <= 1'b0;
        end
    end

    always @(posedge to_rx.aclk) begin
        if (srst)                              pkt_pending_ff <=  0;
        else if (to_rx.tvalid && to_rx.tready) pkt_pending_ff <=  pkt_pending_ff ? !to_rx.tlast : rx_sop;
    end

    assign pkt_pending = pkt_pending_ff || (to_rx.tvalid && to_rx.tready && rx_sop);

    logic tvalid_fail;
    always @(posedge to_rx.aclk) begin
        if (srst)              tvalid_fail <= 0;
        else if (tvalid_check) tvalid_fail <= tvalid_fail || (pkt_pending && to_rx.tready && !to_rx.tvalid);
    end

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        model = new();
        scoreboard = new();

        env = new("env", model, scoreboard);
        env.reset_vif = reset_if;
        env.axis_in_vif = from_tx;
        env.axis_out_vif = to_rx;
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

    AXI4S_TRANSACTION_T axis_transaction;

    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 511));
        axis_transaction = new($sformatf("trans_%0d",id), len);
        axis_transaction.randomize();
        env.inbox.put(axis_transaction);
    endtask

    task packet_stream();
       for (int i = 0; i < 100; i++) begin
           one_packet(i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
            from_tx._wait(1);
        `SVTEST_END

        `SVTEST(one_packet_good)
            len = $urandom_range(64, 511);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2)
            env.monitor.set_tpause(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            env.monitor.set_tpause(2);
            env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            env.monitor.set_tpause(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            env.monitor.set_tpause(2);
            env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on to_rx.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            AXI4S_TRANSACTION_T bad_transaction;
            // Create 'expected' transaction
            axis_transaction = new("trans_0");
            axis_transaction.randomize();
            env.model.inbox.put(axis_transaction);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_transaction = axis_transaction.dup("trans_0_bad");
            bad_byte_idx = $urandom % bad_transaction.size();
            bad_byte_data = 8'hFF ^ bad_transaction.get_byte(bad_byte_idx);
            bad_transaction.set_byte(bad_byte_idx, bad_byte_data);
            env.driver.inbox.put(bad_transaction);
            from_tx._wait(1000);
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
  function void __register_tests();\
    test.__register_tests();\
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

module axi4s_fifo_async_32d_unit_test;
`AXI4S_UNIT_TEST(7)
endmodule

module axi4s_fifo_async_512d_unit_test;
`AXI4S_UNIT_TEST(8)
endmodule

module axi4s_fifo_async_8192d_unit_test;
`AXI4S_UNIT_TEST(9)
endmodule

module axi4s_pkt_fifo_async_default_unit_test;
`AXI4S_UNIT_TEST(10)
endmodule

module axi4s_pkt_fifo_async_st_fwd_unit_test;
`AXI4S_UNIT_TEST(11)
endmodule

module axi4s_pkt_fifo_sync_unit_test;
`AXI4S_UNIT_TEST(12)
endmodule

module axi4s_packet_adapter_unit_test;
`AXI4S_UNIT_TEST(13)
endmodule

module axi4s_pipe_unit_test;
`AXI4S_UNIT_TEST(14)
endmodule

module axi4s_pipe_auto_unit_test;
`AXI4S_UNIT_TEST(15)
endmodule

module axi4s_pipe_slr_unit_test;
`AXI4S_UNIT_TEST(16)
endmodule

module axi4s_pipe_slr_p1_p1_unit_test;
`AXI4S_UNIT_TEST(17)
endmodule

module axi4s_pipe_slr_b2b_unit_test;
`AXI4S_UNIT_TEST(18)
endmodule

module axi4s_pipe_slr_to_pipe_unit_test;
`AXI4S_UNIT_TEST(19)
endmodule

module axi4s_pipe_to_pipe_slr_unit_test;
`AXI4S_UNIT_TEST(20)
endmodule

module axi4s_width_converter_unit_test;
`AXI4S_UNIT_TEST(21)
endmodule
