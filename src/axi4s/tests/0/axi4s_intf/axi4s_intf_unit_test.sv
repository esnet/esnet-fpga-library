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
                                   DUT_SELECT == 21 ? "axi4s_width_converter_le" : "undefined";

    string name = $sformatf("axi4s_intf_dut_%s_ut", dut_string);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 8;
    localparam type TID_T = logic[7:0];
    localparam type TDEST_T = logic[11:0];
    localparam type TUSER_T = logic[31:0];

    typedef axi4s_transaction#(TID_T,TDEST_T,TUSER_T) AXI4S_TRANSACTION_T;

    //===================================
    // DUT
    //===================================
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axis_in_if ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axis_out_if ();

    axi4l_intf  axil_to_probe ();
    axi4l_intf  axil_to_ovfl  ();
    axi4l_intf  axil_if ();

    axi4l_intf_controller_term axi4l_to_probe_controller_term (.axi4l_if(axil_to_probe));
    axi4l_intf_controller_term axi4l_to_ovfl_controller_term  (.axi4l_if(axil_to_ovfl));
    axi4l_intf_controller_term axi4l_if_controller_term       (.axi4l_if(axil_if));

    logic tvalid_check = 0;

    generate
      case (DUT_SELECT)
         0: axi4s_intf_connector DUT (   .axi4s_from_tx(axis_in_if), .   axi4s_to_rx(axis_out_if));
         1: axi4s_intf_pipe      DUT (.axi4s_if_from_tx(axis_in_if), .axi4s_if_to_rx(axis_out_if));
         2: axi4s_tready_pipe    DUT (.axi4s_if_from_tx(axis_in_if), .axi4s_if_to_rx(axis_out_if));
         3: axi4s_full_pipe      DUT (.axi4s_if_from_tx(axis_in_if), .axi4s_if_to_rx(axis_out_if));

         4: axi4s_fifo_sync  #(.DEPTH(  32)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
         5: axi4s_fifo_sync  #(.DEPTH( 512)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
         6: axi4s_fifo_sync  #(.DEPTH(8192)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));

         7: begin
                axi4s_fifo_async #(.DEPTH(  32)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
               `SVUNIT_CLK_GEN(axis_out_if.aclk, 1.0ns);  // slow to fast
                assign axis_out_if.aresetn = axis_in_if.aresetn;
            end

         8: begin
                axi4s_fifo_async #(.DEPTH( 512)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
               `SVUNIT_CLK_GEN(axis_out_if.aclk, 1.5ns);
                assign axis_out_if.aresetn = axis_in_if.aresetn;
            end

         9: begin
                axi4s_fifo_async #(.DEPTH(8192)) DUT (.axi4s_in(axis_in_if), .axi4s_out(axis_out_if));
               `SVUNIT_CLK_GEN(axis_out_if.aclk, 2.0ns);  // fast to slow
                assign axis_out_if.aresetn = axis_in_if.aresetn;
            end

         10: begin
                axi4s_pkt_fifo_async DUT ( .axi4s_in(axis_in_if), .axi4s_out(axis_out_if), .clk_out(axis_out_if.aclk),
                                           .flow_ctl_thresh('0), .flow_ctl(),
                                           .axil_to_probe(axil_to_probe), .axil_to_ovfl(axil_to_ovfl), .axil_if(axil_if) );

               `SVUNIT_CLK_GEN(axis_out_if.aclk, 2.0ns);  // fast to slow
            end

         11: begin
                assign tvalid_check = 1;

                axi4s_pkt_fifo_async #(.TX_THRESHOLD(512)) DUT (
                                           .axi4s_in(axis_in_if), .axi4s_out(axis_out_if), .clk_out(axis_out_if.aclk),
                                           .flow_ctl_thresh('0), .flow_ctl(),
                                           .axil_to_probe(axil_to_probe), .axil_to_ovfl(axil_to_ovfl), .axil_if(axil_if) );

               `SVUNIT_CLK_GEN(axis_out_if.aclk, 1.0ns);  // slow to fast
            end

         12: begin
                axi4s_pkt_fifo_sync DUT ( .srst(reset_if.reset), .axi4s_in(axis_in_if), .axi4s_out(axis_out_if),
                                          .axil_to_probe(axil_to_probe), .axil_to_ovfl(axil_to_ovfl), .axil_if(axil_if),
                                          .oflow() );
            end
         13: begin
                localparam type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};
                bit err; META_T meta;
                TID_T tid; TDEST_T tdest; TUSER_T tuser;

                packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) packet_if (.clk(axis_in_if.aclk), .srst(reset_if.reset));

                assign err = 1'b0;
                assign meta.tid = axis_in_if.tid;
                assign meta.tdest = axis_in_if.tdest;
                assign meta.tuser = axis_in_if.tuser;
                axi4s_to_packet_adapter #(.META_T(META_T)) DUT_0 (.axis_if(axis_in_if), .*);
                assign tid = packet_if.meta.tid;
                assign tdest = packet_if.meta.tdest;
                assign tuser = packet_if.meta.tuser;
                axi4s_from_packet_adapter #(TID_T, TDEST_T, TUSER_T) DUT_1 (.axis_if(axis_out_if), .*);
         end
         14 : begin
             axi4s_pipe #(.STAGES(2)) DUT (.from_tx ( axis_in_if ), .to_rx ( axis_out_if ));
         end
         15 : begin
             axi4s_pipe_auto DUT (.from_tx ( axis_in_if ), .to_rx ( axis_out_if ));
         end
         16 : begin
             axi4s_pipe_slr DUT (.from_tx ( axis_in_if ), .to_rx ( axis_out_if ));
         end
         17 : begin
             axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT (.from_tx ( axis_in_if ), .to_rx ( axis_out_if ));
         end
         18 : begin
            axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axis_if ();
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT1 (.from_tx ( axis_in_if ), .to_rx ( __axis_if ));
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT2 (.from_tx ( __axis_if ),  .to_rx ( axis_out_if ));
        end
        19 : begin
            axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axis_if ();
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT1 (.from_tx ( axis_in_if ), .to_rx ( __axis_if ));
            axi4s_pipe #(.STAGES(1)) DUT2 (.from_tx ( __axis_if ), .to_rx ( axis_out_if ));
        end
        20 : begin
            axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axis_if ();
            axi4s_pipe #(.STAGES(1)) DUT1 (.from_tx ( axis_in_if ), .to_rx ( __axis_if ));
            axi4s_pipe_slr #(.PRE_PIPE_STAGES(1), .POST_PIPE_STAGES(1)) DUT2 (.from_tx ( __axis_if ), .to_rx ( axis_out_if ));
        end
        21 : begin
            axi4s_intf #(.DATA_BYTE_WID(2*DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) __axis_if ();
            axi4s_width_converter #() DUT1 (.from_tx ( axis_in_if ), .to_rx (__axis_if ));
            axi4s_width_converter #() DUT2 (.from_tx (__axis_if ), .to_rx ( axis_out_if ));
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
    std_reset_intf reset_if (.clk(axis_in_if.aclk));
    assign axis_in_if.aresetn = !reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(axis_in_if.aclk, 1.5ns);

    // Checking logic
    logic pkt_pending, pkt_pending_ff;

    always @(posedge axis_out_if.aclk) begin
        if (!axis_out_if.aresetn)                          pkt_pending_ff <=  0;
        else if (axis_out_if.tvalid && axis_out_if.tready) pkt_pending_ff <=  pkt_pending_ff ? !axis_out_if.tlast : axis_out_if.sop;
    end

    assign pkt_pending = pkt_pending_ff || (axis_out_if.tvalid && axis_out_if.tready && axis_out_if.sop);

    logic tvalid_fail;
    always @(posedge axis_out_if.aclk) begin
        if (!axis_out_if.aresetn) tvalid_fail <= 0;
        else if (tvalid_check)    tvalid_fail <= tvalid_fail || (pkt_pending && axis_out_if.tready && !axis_out_if.tvalid);
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
        env.axis_in_vif = axis_in_if;
        env.axis_out_vif = axis_out_if;
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
            axis_in_if._wait(1);
        `SVTEST_END

        `SVTEST(one_packet_good)
            len = $urandom_range(64, 511);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2)
            env.monitor.set_tpause(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            env.monitor.set_tpause(2);
            env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            env.monitor.set_tpause(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            env.monitor.set_tpause(2);
            env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg ); `FAIL_IF_LOG( tvalid_fail, "Unexpected stall on axis_out_if.tvalid" );
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
            axis_in_if._wait(1000);
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
