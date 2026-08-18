`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 1ms

module sar_verif_unit_test;
    import svunit_pkg::svunit_testcase;
    import sar_verif_pkg::*;

    string name = "sar_verif_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int BUF_ID_WID = 1;
    localparam int OFFSET_WID = 20;

    localparam type BUF_ID_T = logic [BUF_ID_WID-1:0];
    localparam type OFFSET_T = logic [OFFSET_WID-1:0];

    typedef sar_frame_transaction#(BUF_ID_T)             FRAME_T;
    typedef sar_segment_transaction#(BUF_ID_T, OFFSET_T) SEGMENT_T;

    //===================================
    // Clock (required by SVUnit infrastructure)
    //===================================
    logic clk;
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Components (recreated fresh in each setup())
    //===================================
    sar_sequencer#(BUF_ID_T, OFFSET_T) sequencer;
    sar_collector#(BUF_ID_T, OFFSET_T) collector;

    mailbox #(FRAME_T)   frame_inbox;
    mailbox #(SEGMENT_T) seg_pipe;
    mailbox #(FRAME_T)   frame_outbox;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    //===================================
    // Setup
    //===================================
    task setup();
        svunit_ut.setup();

        frame_inbox  = new();
        seg_pipe     = new();
        frame_outbox = new();

        sequencer = new("sar_sequencer");
        sequencer.inbox  = frame_inbox;
        sequencer.outbox = seg_pipe;

        collector = new("sar_collector");
        collector.inbox  = seg_pipe;
        collector.outbox = frame_outbox;

        sequencer.run();
        collector.run();
    endtask

    //===================================
    // Teardown
    //===================================
    task teardown();
        sequencer.stop();
        collector.stop();
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
    // Frame smaller than seg_len → one segment produced and
    // reassembled; data and buf_id preserved.
    //===================================
    `SVTEST(single_segment)
        FRAME_T sent, rcvd;
        string msg;
        sent = new("frame", BUF_ID_T'(1), 256);
        fill_frame(sent);
        sequencer.set_seg_len(512);
        frame_inbox.put(sent);
        frame_outbox.get(rcvd);
        `FAIL_UNLESS_LOG(sent.compare(rcvd, msg), msg);
    `SVTEST_END

    //===================================
    // Test: multi_segment
    // Frame spans multiple segments (sequential order);
    // all data reassembled correctly.
    //===================================
    `SVTEST(multi_segment)
        FRAME_T sent, rcvd;
        string msg;
        sent = new("frame", BUF_ID_T'(0), 1000);
        fill_frame(sent);
        sequencer.set_seg_len(300);   // 300 + 300 + 400
        frame_inbox.put(sent);
        frame_outbox.get(rcvd);
        `FAIL_UNLESS_LOG(sent.compare(rcvd, msg), msg);
    `SVTEST_END

    //===================================
    // Test: exact_segment
    // Frame length exactly equals seg_len → one segment, last=1.
    //===================================
    `SVTEST(exact_segment)
        FRAME_T sent, rcvd;
        string msg;
        sent = new("frame", BUF_ID_T'(0), 512);
        fill_frame(sent);
        sequencer.set_seg_len(512);
        frame_inbox.put(sent);
        frame_outbox.get(rcvd);
        `FAIL_UNLESS_LOG(sent.compare(rcvd, msg), msg);
    `SVTEST_END

    //===================================
    // Test: out_of_order_segments
    // Three segments injected directly to collector inbox in
    // non-sequential order; collector uses offset to reassemble.
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
        seg_pipe.put(seg);

        // Then segment 0 (offset=0)
        seg = new("seg0", BUF_ID_T'(0), OFFSET_T'(0), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++)
            seg.data[i] = expected.data[i];
        seg_pipe.put(seg);

        // Finally segment 1 (offset=300) — this completes the frame
        seg = new("seg1", BUF_ID_T'(0), OFFSET_T'(SEG_LEN), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++)
            seg.data[i] = expected.data[SEG_LEN + i];
        seg_pipe.put(seg);

        frame_outbox.get(rcvd);
        `FAIL_UNLESS_LOG(expected.compare(rcvd, msg), msg);
    `SVTEST_END

    //===================================
    // Test: two_frames_interleaved
    // Segments from two buf_ids interleaved in the collector inbox;
    // both frames reassembled independently and correctly.
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
        seg_pipe.put(seg);

        seg = new("b0", BUF_ID_T'(1), OFFSET_T'(0), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_b.data[i];
        seg_pipe.put(seg);

        seg = new("a1", BUF_ID_T'(0), OFFSET_T'(SEG_LEN), 1'b1, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_a.data[SEG_LEN + i];
        seg_pipe.put(seg);

        seg = new("b1", BUF_ID_T'(1), OFFSET_T'(SEG_LEN), 1'b0, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_b.data[SEG_LEN + i];
        seg_pipe.put(seg);

        seg = new("b2", BUF_ID_T'(1), OFFSET_T'(2*SEG_LEN), 1'b1, SEG_LEN);
        for (int i = 0; i < SEG_LEN; i++) seg.data[i] = expected_b.data[2*SEG_LEN + i];
        seg_pipe.put(seg);

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

endmodule : sar_verif_unit_test
