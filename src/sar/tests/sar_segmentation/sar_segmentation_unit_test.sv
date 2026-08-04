`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 5ms

module sar_segmentation_unit_test;
    import svunit_pkg::svunit_testcase;
    import sar_verif_pkg::*;

    string name = "sar_segmentation_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int NUM_FRAME_BUFFERS = 4;
    localparam int MAX_FRAME_SIZE    = 65536;
    localparam int MAX_SEGMENT_LEN   = 16384;

    localparam int BUF_ID_WID      = $clog2(NUM_FRAME_BUFFERS);
    localparam int OFFSET_WID      = $clog2(MAX_FRAME_SIZE);
    localparam int FRAME_SIZE_WID  = $clog2(MAX_FRAME_SIZE+1);
    localparam int SEGMENT_LEN_WID = $clog2(MAX_SEGMENT_LEN+1);

    localparam type BUF_ID_T      = logic[BUF_ID_WID-1:0];
    localparam type OFFSET_T      = logic[OFFSET_WID-1:0];
    localparam type FRAME_SIZE_T  = logic[FRAME_SIZE_WID-1:0];
    localparam type SEGMENT_LEN_T = logic[SEGMENT_LEN_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic         clk;
    logic         srst;
    logic         en;
    logic         init_done;

    logic                  frame_ready;
    logic                  frame_valid;
    BUF_ID_T               frame_buf_id;
    FRAME_SIZE_T           frame_len;

    logic                  seg_ready;
    logic                  seg_valid;
    BUF_ID_T               seg_buf_id;
    OFFSET_T               seg_offset;
    SEGMENT_LEN_T          seg_len;
    logic                  seg_last;

    axi4l_intf axil_if ();

    sar_segmentation #(
        .NUM_FRAME_BUFFERS ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE    ( MAX_FRAME_SIZE ),
        .MAX_SEGMENT_LEN   ( MAX_SEGMENT_LEN )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    std_verif_pkg::basic_env env;

    axi4l_verif_pkg::axi4l_reg_agent reg_agent;
    sar_segmentation_reg_agent agent;

    std_reset_intf reset_if (.clk(clk));

    `SVUNIT_CLK_GEN(clk, 2.5ns);
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;
    assign axil_if.aresetn = !srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        env = new;
        env.reset_vif = reset_if;

        reg_agent = new("axil_reg_agent");
        reg_agent.axil_vif = axil_if;

        agent = new("segmentation_reg_agent", reg_agent, 0);
    endfunction

    //===================================
    // Setup
    //===================================
    task setup();
        svunit_ut.setup();

        idle();
        env.reset_dut();

        en <= 1'b1;
        agent.wait_ready();

        // Default: seg_ready always asserted
        seg_ready <= 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    //===================================
    // Test: reset
    // Verify init_done asserts after reset.
    //===================================
    `SVTEST(reset)
        `FAIL_UNLESS(init_done);
    `SVTEST_END

    //===================================
    // Test: single_segment_frame
    // frame_len < cfg_seg_len: one segment
    // with seg_len == frame_len (not cfg_seg_len).
    //===================================
    `SVTEST(single_segment_frame)
        FRAME_SIZE_T _frame_len;
        SEGMENT_LEN_T _seg_len_cfg;
        // Pick frame_len strictly less than the default cfg_seg_len (512)
        _frame_len = 100;
        submit_frame(.buf_id(0), .len(_frame_len));
        // Expect exactly one segment
        collect_seg();
        `FAIL_UNLESS_EQUAL(seg_buf_id, BUF_ID_T'(0));
        `FAIL_UNLESS_EQUAL(seg_offset, OFFSET_T'(0));
        `FAIL_UNLESS_EQUAL(seg_len, SEGMENT_LEN_T'(_frame_len));
        `FAIL_UNLESS(seg_last);
        // No further segments
        @(posedge clk);
        `FAIL_IF(seg_valid);
    `SVTEST_END

    //===================================
    // Test: exact_segment_frame
    // frame_len == cfg_seg_len: one segment,
    // seg_len == cfg_seg_len.
    //===================================
    `SVTEST(exact_segment_frame)
        FRAME_SIZE_T _frame_len;
        // Default cfg_seg_len = 512
        _frame_len = 512;
        submit_frame(.buf_id(0), .len(_frame_len));
        collect_seg();
        `FAIL_UNLESS_EQUAL(seg_len, SEGMENT_LEN_T'(512));
        `FAIL_UNLESS_EQUAL(seg_offset, OFFSET_T'(0));
        `FAIL_UNLESS(seg_last);
        @(posedge clk);
        `FAIL_IF(seg_valid);
    `SVTEST_END

    //===================================
    // Test: two_segment_frame
    // frame_len = cfg_seg_len + remainder.
    //===================================
    `SVTEST(two_segment_frame)
        localparam int CFG_SEG = 512;
        localparam int REMAINDER = 200;
        submit_frame(.buf_id(1), .len(CFG_SEG + REMAINDER));
        // First segment
        collect_seg();
        `FAIL_UNLESS_EQUAL(seg_buf_id, BUF_ID_T'(1));
        `FAIL_UNLESS_EQUAL(seg_offset, OFFSET_T'(0));
        `FAIL_UNLESS_EQUAL(seg_len, SEGMENT_LEN_T'(CFG_SEG));
        `FAIL_IF(seg_last);
        // Second segment (remainder)
        collect_seg();
        `FAIL_UNLESS_EQUAL(seg_offset, OFFSET_T'(CFG_SEG));
        `FAIL_UNLESS_EQUAL(seg_len, SEGMENT_LEN_T'(REMAINDER));
        `FAIL_UNLESS(seg_last);
        @(posedge clk);
        `FAIL_IF(seg_valid);
    `SVTEST_END

    //===================================
    // Test: many_segment_frame
    // frame_len = 4*cfg_seg_len + remainder:
    // 5 segments with correct offsets/lengths.
    //===================================
    `SVTEST(many_segment_frame)
        localparam int CFG_SEG = 512;
        localparam int N_FULL  = 4;
        localparam int REM     = 77;
        submit_frame(.buf_id(2), .len(N_FULL*CFG_SEG + REM));
        for (int i = 0; i < N_FULL; i++) begin
            collect_seg();
            `FAIL_UNLESS_EQUAL(seg_offset, OFFSET_T'(i * CFG_SEG));
            `FAIL_UNLESS_EQUAL(seg_len, SEGMENT_LEN_T'(CFG_SEG));
            `FAIL_IF(seg_last);
        end
        collect_seg();
        `FAIL_UNLESS_EQUAL(seg_offset, OFFSET_T'(N_FULL * CFG_SEG));
        `FAIL_UNLESS_EQUAL(seg_len, SEGMENT_LEN_T'(REM));
        `FAIL_UNLESS(seg_last);
    `SVTEST_END

    //===================================
    // Test: counter_increment
    // Verify dbg_cnt_frames_in and
    // dbg_cnt_segments_out increment.
    //===================================
    `SVTEST(counter_increment)
        int frames_cnt, segs_cnt;
        // Two frames: one 1-segment, one 2-segment
        submit_frame(.buf_id(0), .len(100));   // 1 seg
        repeat (5) @(posedge clk);
        submit_frame(.buf_id(1), .len(700));   // 2 segs (512 + 188)
        repeat (20) @(posedge clk);
        agent.get_frames_in_cnt(frames_cnt);
        agent.get_segments_out_cnt(segs_cnt);
        `FAIL_UNLESS_EQUAL(frames_cnt, 2);
        `FAIL_UNLESS_EQUAL(segs_cnt, 3);
    `SVTEST_END

    //===================================
    // Test: zero_seg_len_rejected
    // If cfg_seg_len is zero, frame_ready
    // must stay low (no hang, no segment).
    //===================================
    `SVTEST(zero_seg_len_rejected)
        sar_segmentation_reg_pkg::reg__config_t cfg;
        // Write seg_len = 0 via AXI-L
        cfg.seg_len = 0;
        agent.write__config(cfg);
        // Allow config to latch (happens in READY state, one cycle)
        repeat (5) @(posedge clk);
        // Assert frame; frame_ready must not go high
        frame_valid <= 1'b1;
        frame_buf_id <= 0;
        frame_len <= 100;
        repeat (10) @(posedge clk);
        `FAIL_IF_LOG(frame_ready, "frame_ready asserted with zero cfg_seg_len");
        frame_valid <= 1'b0;
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task idle();
        frame_valid <= 1'b0;
        frame_buf_id <= '0;
        frame_len <= '0;
        seg_ready <= 1'b1;
        en <= 1'b0;
    endtask

    // Submit a frame and wait for frame_ready handshake
    task submit_frame(input BUF_ID_T buf_id, input FRAME_SIZE_T len);
        frame_valid  <= 1'b1;
        frame_buf_id <= buf_id;
        frame_len    <= len;
        do @(posedge clk); while (!frame_ready);
        frame_valid <= 1'b0;
    endtask

    // Wait for one segment to be valid and accepted
    task collect_seg();
        do @(posedge clk); while (!(seg_valid && seg_ready));
    endtask

endmodule : sar_segmentation_unit_test
