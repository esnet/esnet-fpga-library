`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 1ms

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
    localparam int SEG_META_WID  = BUF_ID_WID + OFFSET_WID + 1;

    localparam type BUF_ID_T   = logic [BUF_ID_WID-1:0];
    localparam type OFFSET_T   = logic [OFFSET_WID-1:0];
    localparam type SEG_META_T = logic [SEG_META_WID-1:0];

    typedef sar_frame_transaction#(BUF_ID_T)             FRAME_T;
    typedef sar_segment_transaction#(BUF_ID_T, OFFSET_T) SEGMENT_T;

    //===================================
    // Clock (required by SVUnit infrastructure)
    //===================================
    logic clk;
    `SVUNIT_CLK_GEN(clk, 5ns);

    std_reset_intf reset_if(.clk);

    assign reset_if.ready = !reset_if.reset;

    //===================================
    // Packet interface — wire between segment driver and monitor
    //===================================
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(SEG_META_WID)) pkt_if (.clk(clk));

    //===================================
    // Components
    //===================================
    sar_component_env #(BUF_ID_T, OFFSET_T) env;

    packet_intf_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) pkt_if_driver;
    packet_intf_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) pkt_if_monitor;

    std_verif_pkg::wire_model#(FRAME_T) model;
    std_verif_pkg::event_scoreboard#(FRAME_T) scoreboard;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        model = new("model");
        scoreboard = new("scoreboard");

        pkt_if_driver = new("packet_if_driver");
        pkt_if_driver.packet_vif = pkt_if;

        pkt_if_monitor = new("packet_if_monitor");
        pkt_if_monitor.packet_vif = pkt_if;

        env = new("sar_component_env");
        env.reset_vif = reset_if;
        env.model = model;
        env.scoreboard = scoreboard;
        env.driver.pkt_driver = pkt_if_driver;
        env.monitor.pkt_monitor = pkt_if_monitor;
        env.build();
    endfunction

    //===================================
    // Setup
    //===================================
    task setup();
        svunit_ut.setup();

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
    // Helper: fill frame bytes with a sequential pattern
    //===================================
    task fill_frame(input FRAME_T frame);
        for (int i = 0; i < frame.data.size(); i++)
            frame.data[i] = byte'(i % 256);
    endtask

    `SVUNIT_TESTS_BEGIN

    //===================================
    // Test: single_segment
    // Frame smaller than seg_len → one segment; full stack exercised.
    //===================================
    `SVTEST(single_segment)
        FRAME_T sent, rcvd;
        string msg;
        sent = new("frame", BUF_ID_T'(1), 256);
        fill_frame(sent);
        env.sequencer.set_seg_len(512);
        env.inbox.put(sent);
        check(1);
    `SVTEST_END

    //===================================
    // Test: multi_segment
    // Frame spans multiple segments; full stack exercised.
    //===================================
    `SVTEST(multi_segment)
        FRAME_T sent, rcvd;
        string msg;
        sent = new("frame", BUF_ID_T'(0), 1000);
        fill_frame(sent);
        env.sequencer.set_seg_len(300);   // 300 + 300 + 400
        env.inbox.put(sent);
        check(1);
    `SVTEST_END

    //===================================
    // Test: exact_segment
    // Frame length exactly equals seg_len → one segment, last=1; full stack.
    //===================================
    `SVTEST(exact_segment)
        FRAME_T sent, rcvd;
        string msg;
        sent = new("frame", BUF_ID_T'(0), 512);
        fill_frame(sent);
        env.sequencer.set_seg_len(512);
        env.inbox.put(sent);
        check(1);
    `SVTEST_END

    //===================================
    // Test: out_of_order_segments
    // Three segments injected directly into seg_out (bypassing packet_intf)
    // in non-sequential order; collector uses offset to reassemble.
    //===================================
    `SVTEST(out_of_order_segments)
        localparam int SEG_LEN   = 300;
        localparam int FRAME_LEN = SEG_LEN * 3;
        FRAME_T expected, rcvd;
        SEGMENT_T seg;
        string msg;

        expected = new("expected", BUF_ID_T'(0), FRAME_LEN);
        fill_frame(expected);

        // Send segment 2 first (carries last=1, offset=600)
        seg = new("seg2", BUF_ID_T'(0), OFFSET_T'(2*SEG_LEN), 1'b1, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++)
            seg.data[i] = expected.data[2*SEG_LEN + i];
        seg_out.put(seg);

        // Then segment 0 (offset=0)
        seg = new("seg0", BUF_ID_T'(0), OFFSET_T'(0), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++)
            seg.data[i] = expected.data[i];
        seg_out.put(seg);

        // Finally segment 1 (offset=300) — this completes the frame
        seg = new("seg1", BUF_ID_T'(0), OFFSET_T'(SEG_LEN), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++)
            seg.data[i] = expected.data[SEG_LEN + i];
        seg_out.put(seg);

        frame_outbox.get(rcvd);
        `FAIL_UNLESS_LOG(expected.compare(rcvd, msg), msg);
    `SVTEST_END

    //===================================
    // Test: two_frames_interleaved
    // Segments from two buf_ids injected directly into seg_out in interleaved
    // order; both frames reassembled independently and correctly.
    //===================================
    `SVTEST(two_frames_interleaved)
        localparam int SEG_LEN = 200;
        FRAME_T expected_a, expected_b, tmp;
        FRAME_T rcvd_a, rcvd_b;
        SEGMENT_T seg;
        string msg;

        expected_a = new("frameA", BUF_ID_T'(0), SEG_LEN*2);
        expected_b = new("frameB", BUF_ID_T'(1), SEG_LEN*3);

        fill_frame(expected_a);
        for (int i = 0; i < expected_b.data.size(); i++)
            expected_b.data[i] = byte'(255 - (i % 256));

        // A[0], B[0], A[1/last], B[1], B[2/last]
        seg = new("a0", BUF_ID_T'(0), OFFSET_T'(0), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_a.data[i];
        seg_out.put(seg);

        seg = new("b0", BUF_ID_T'(1), OFFSET_T'(0), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_b.data[i];
        seg_out.put(seg);

        seg = new("a1", BUF_ID_T'(0), OFFSET_T'(SEG_LEN), 1'b1, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_a.data[SEG_LEN + i];
        seg_out.put(seg);

        seg = new("b1", BUF_ID_T'(1), OFFSET_T'(SEG_LEN), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_b.data[SEG_LEN + i];
        seg_out.put(seg);

        seg = new("b2", BUF_ID_T'(1), OFFSET_T'(2*SEG_LEN), 1'b1, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_b.data[2*SEG_LEN + i];
        seg_out.put(seg);

        // Collect both frames; match by buf_id (A completes before B)
        frame_outbox.get(tmp);
        if (tmp.buf_id === BUF_ID_T'(0)) begin
            rcvd_a = tmp;
            frame_outbox.get(rcvd_b);
        end else begin
            rcvd_b = tmp;
            frame_outbox.get(rcvd_a);
        end

        `FAIL_UNLESS_LOG(expected_a.compare(rcvd_a, msg), msg);
        `FAIL_UNLESS_LOG(expected_b.compare(rcvd_b, msg), msg);
    `SVTEST_END

    `SVUNIT_TESTS_END

    task check(input int EXPECTED, input time TIMEOUT=100us);
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
endmodule : sar_verif_unit_test
