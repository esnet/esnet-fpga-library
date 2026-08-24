`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 5ms

module sar_verif_unit_test;
    import svunit_pkg::svunit_testcase;
    import sar_verif_pkg::*;
    import packet_verif_pkg::*;

    string name = "sar_verif_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int BUF_ID_WID    = 1;
    localparam int OFFSET_WID    = 20;
    localparam int DATA_BYTE_WID = 8;
    localparam int META_WID      = 16;
    localparam int SEG_META_WID  = BUF_ID_WID + OFFSET_WID + 1 + META_WID;

    localparam type BUF_ID_T   = logic [BUF_ID_WID-1:0];
    localparam type OFFSET_T   = logic [OFFSET_WID-1:0];
    localparam type META_T     = logic [META_WID-1:0];
    localparam type SEG_META_T = logic [SEG_META_WID-1:0];

    // Default segment length for shared testcases
    localparam int SEG_LEN = 512;

    typedef sar_frame_transaction#(BUF_ID_T) FRAME_T;

    //===================================
    // Clock (required by SVUnit infrastructure)
    //===================================
    logic clk;
    logic srst;

    `SVUNIT_CLK_GEN(clk, 5ns);

    std_reset_intf reset_if(.clk);

    assign srst = reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    //===================================
    // Packet interface — wire between segment driver and monitor
    //===================================
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID))     pkt_if (.clk(clk));
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(SEG_META_WID)) seg_if (.clk(clk));

    BUF_ID_T packet_buf_id;
    OFFSET_T packet_offset;
    logic    packet_last;

    // Shim: seg_tx_if (wide meta) → packet_in_if (narrow meta) + sideband
    sar_segment_to_packet #(
        .BUF_ID_WID   ( BUF_ID_WID ),
        .OFFSET_WID   ( OFFSET_WID ),
        .PKT_META_WID ( META_WID   )
    ) i_seg_to_pkt (.*);

    // Shim: packet_out_if (narrow meta) + sideband → seg_rx_if (wide meta)
    // clk/srst needed to latch sideband on first word (DUT may update before eop)
    sar_segment_from_packet #(
        .BUF_ID_WID   ( BUF_ID_WID ),
        .OFFSET_WID   ( OFFSET_WID ),
        .PKT_META_WID ( META_WID   )
    ) i_pkt_from_seg (.*);

    //===================================
    // Components
    //===================================
    sar_component_env #(BUF_ID_T, OFFSET_T, META_T) env;
    sar_model#(BUF_ID_T) model;
    std_verif_pkg::event_scoreboard#(FRAME_T) scoreboard;

    // Concrete packet interface driver/monitor (named to match shared testcases)
    packet_intf_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) seg_pkt_driver;
    packet_intf_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) seg_pkt_monitor;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        model = new("sar_model");
        scoreboard = new("scoreboard");

        seg_pkt_driver = new("seg_pkt_driver");
        seg_pkt_driver.packet_vif = seg_if;

        seg_pkt_monitor = new("seg_pkt_monitor");
        seg_pkt_monitor.packet_vif = seg_if;

        env = new("sar_component_env");
        env.reset_vif = reset_if;
        env.model = model;
        env.scoreboard = scoreboard;
        env.driver.pkt_driver  = seg_pkt_driver;
        env.monitor.pkt_monitor = seg_pkt_monitor;
        env.build();
    endfunction

    //===================================
    // Setup
    //===================================
    task setup();
        svunit_ut.setup();

        // Reset driver/monitor state that persists across tests
        seg_pkt_driver.set_min_gap(0);
        seg_pkt_monitor.set_stall_rate(0.0);

        env.run();
    endtask

    //===================================
    // Teardown
    //===================================
    task teardown();
        env.stop();
        svunit_ut.teardown();
    endtask

    //===================================
    // Helpers
    //===================================
    task fill_frame(input FRAME_T frame);
        for (int i = 0; i < frame.data.size(); i++)
            frame.data[i] = byte'(i % 256);
    endtask

    task check(input int EXPECTED, input time TIMEOUT=500us);
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
                do
                    #100ns;
                while ( env.scoreboard.got_processed() != EXPECTED );
                `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg);
                `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), EXPECTED);
            end
        join_any
        disable fork;
    endtask

    `SVUNIT_TESTS_BEGIN

    `include "../common/sar_common_tests.svh"

    `SVUNIT_TESTS_END

endmodule : sar_verif_unit_test
