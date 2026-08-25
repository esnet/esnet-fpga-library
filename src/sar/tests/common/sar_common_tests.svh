// Shared SAR testcases included by both sar_verif_unit_test and sar_packet_unit_test.
//
// Each including module must provide before the `include:
//   localparam int SEG_LEN  — default segment length (e.g. MAX_PKT_SIZE or 512)
//   seg_pkt_driver          — packet_intf_driver handle (for set_min_gap)
//   seg_pkt_monitor         — packet_intf_monitor handle (for set_stall_rate)
// And the standard sar testbench infrastructure:
//   env, fill_frame(), check()

//===================================
// Test: single_segment
// Frame smaller than seg_len → one segment.
//===================================
`SVTEST(single_segment)
    FRAME_T sent;
    sent = new("frame", BUF_ID_T'(0), 512);
    fill_frame(sent);
    env.sequencer.set_seg_len(SEG_LEN);
    env.inbox.put(sent);
    check(1, 100us);
`SVTEST_END

//===================================
// Test: single_segment_stall_monitor
// Same as single_segment but monitor applies back-pressure.
//===================================
`SVTEST(single_segment_stall_monitor)
    FRAME_T sent;
    seg_pkt_monitor.set_stall_rate(0.5);
    sent = new("frame", BUF_ID_T'(0), 512);
    fill_frame(sent);
    env.sequencer.set_seg_len(SEG_LEN);
    env.inbox.put(sent);
    check(1, 200us);
`SVTEST_END

//===================================
// Test: single_segment_gap_driver
// Same as single_segment but driver inserts inter-packet gap.
//===================================
`SVTEST(single_segment_gap_driver)
    FRAME_T sent;
    seg_pkt_driver.set_min_gap(2);
    sent = new("frame", BUF_ID_T'(0), 512);
    fill_frame(sent);
    env.sequencer.set_seg_len(SEG_LEN);
    env.inbox.put(sent);
    check(1, 100us);
`SVTEST_END

//===================================
// Test: single_segment_stall_and_gap
//===================================
`SVTEST(single_segment_stall_and_gap)
    FRAME_T sent;
    seg_pkt_monitor.set_stall_rate(0.5);
    seg_pkt_driver.set_min_gap(2);
    sent = new("frame", BUF_ID_T'(0), 512);
    fill_frame(sent);
    env.sequencer.set_seg_len(SEG_LEN);
    env.inbox.put(sent);
    check(1, 200us);
`SVTEST_END

//===================================
// Test: multi_segment
// Frame spans multiple segments.
//===================================
`SVTEST(multi_segment)
    FRAME_T sent;
    sent = new("frame", BUF_ID_T'(0), SEG_LEN * 3);
    fill_frame(sent);
    env.sequencer.set_seg_len(SEG_LEN);
    env.inbox.put(sent);
    check(1, 500us);
`SVTEST_END

//===================================
// Test: exact_segment
// Frame length exactly equals seg_len → one segment, last=1.
//===================================
`SVTEST(exact_segment)
    FRAME_T sent;
    sent = new("frame", BUF_ID_T'(0), SEG_LEN);
    fill_frame(sent);
    env.sequencer.set_seg_len(SEG_LEN);
    env.inbox.put(sent);
    check(1, 100us);
`SVTEST_END

//===================================
// Test: out_of_order_segments
// Three-segment frame with out_of_order enabled; collector reassembles
// correctly via offset placement.
//===================================
`SVTEST(out_of_order_segments)
    FRAME_T sent;
    sent = new("frame", BUF_ID_T'(0), 768);
    fill_frame(sent);
    sent.out_of_order = 1;
    env.sequencer.set_seg_len(256);
    env.inbox.put(sent);
    check(1, 200us);
`SVTEST_END

//===================================
// Test: two_frames_interleaved
// Two frames submitted simultaneously with interleave enabled; segments from
// both frames are emitted concurrently and both frames are reassembled.
//===================================
`SVTEST(two_frames_interleaved)
    FRAME_T frame_a, frame_b;
    frame_a = new("frameA", BUF_ID_T'(0), 384);
    frame_b = new("frameB", BUF_ID_T'(1), 384);
    fill_frame(frame_a);
    for (int i = 0; i < frame_b.data.size(); i++)
        frame_b.data[i] = byte'(255 - (i % 256));
    env.sequencer.set_seg_len(128);
    env.sequencer.set_interleave(1);
    env.inbox.put(frame_a);
    env.inbox.put(frame_b);
    check(2, 200us);
`SVTEST_END

//===================================
// Test: errored_frame
// Two clean frames interleaved with one errored frame; the errored frame
// is dropped by the model and never scored, so only two frames match.
//===================================
`SVTEST(errored_frame)
    FRAME_T clean_a, errored, clean_b;
    clean_a = new("clean_a", BUF_ID_T'(0), 256);
    fill_frame(clean_a);
    errored = new("errored", BUF_ID_T'(1), 384);
    fill_frame(errored);
    errored.error = 1;
    clean_b = new("clean_b", BUF_ID_T'(2), 256);
    for (int i = 0; i < clean_b.data.size(); i++)
        clean_b.data[i] = byte'(255 - (i % 256));
    env.sequencer.set_seg_len(128);
    env.inbox.put(clean_a);
    env.inbox.put(errored);
    env.inbox.put(clean_b);
    check(2, 200us);
`SVTEST_END

//===================================
// Test: frame_stream_100
// 100 sequential single-segment frames through the full stack.
//===================================
`SVTEST(frame_stream_100)
    FRAME_T sent[100];
    env.sequencer.set_seg_len(SEG_LEN);
    for (int i = 0; i < 100; i++) begin
        sent[i] = new($sformatf("frame_%0d", i), BUF_ID_T'(i % (1 << BUF_ID_WID)), 512);
        sent[i].randomize();
        env.inbox.put(sent[i]);
    end
    check(100, 2ms);
`SVTEST_END
