`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 5ms

module sar_packet_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;
    import sar_verif_pkg::*;

    string name = "sar_packet_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 64;
    localparam int META_WID = 1;
    localparam type META_T = bit[META_WID-1:0];

    localparam NUM_FRAME_BUFFERS = 128;
    localparam MAX_FRAME_SIZE = 65536;
    localparam MAX_PKT_SIZE = 16384;
    localparam TIMER_WID = 20;
    localparam MAX_FRAGMENTS = 1024;
    localparam BURST_SIZE = 8;

    localparam int BUF_ID_WID      = $clog2(NUM_FRAME_BUFFERS);
    localparam int OFFSET_WID      = $clog2(MAX_FRAME_SIZE);
    localparam int FRAME_SIZE_WID  = $clog2(MAX_FRAME_SIZE + 1);
    localparam int PKT_SIZE_WID    = $clog2(MAX_PKT_SIZE+1);
    localparam int ADDR_WID        = $clog2(NUM_FRAME_BUFFERS * MAX_FRAME_SIZE / DATA_BYTE_WID);
    localparam int SEG_META_WID    = BUF_ID_WID + OFFSET_WID + 1 + META_WID;

    localparam int FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS);

    localparam type BUF_ID_T        = logic [BUF_ID_WID-1:0];
    localparam type OFFSET_T        = logic [OFFSET_WID-1:0];
    localparam type SEG_META_T      = logic [SEG_META_WID-1:0];
    localparam type FRAGMENT_PTR_T  = logic [FRAGMENT_PTR_WID-1:0];
    localparam type TIMER_T         = logic [TIMER_WID-1:0];

    // Default segment length for shared testcases
    localparam int SEG_LEN = MAX_PKT_SIZE;

    typedef sar_frame_transaction#(BUF_ID_T) FRAME_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic axil_aclk;
    logic axil_aresetn;

    logic init_done__reassembly;
    logic init_done__segmentation;

    // Sideband signals for reassembly DUT input (driven by sar_segment_to_packet)
    logic [BUF_ID_WID-1:0] packet_buf_id_in;
    logic [OFFSET_WID-1:0] packet_offset_in;
    logic                  packet_last_in;

    // Sideband signals from segmentation DUT output (captured by sar_segment_from_packet)
    logic [BUF_ID_WID-1:0]   packet_buf_id_out;
    logic [OFFSET_WID-1:0]   packet_offset_out;
    logic [PKT_SIZE_WID-1:0] packet_size_out;
    logic                    packet_last_out;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_in_if  (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_out_if (.clk);

    // Wide-meta interfaces used by segment driver and monitor
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(SEG_META_WID)) seg_tx_if (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(SEG_META_WID)) seg_rx_if (.clk);

    axi4l_intf axil_if__reassembly ();
    axi4l_intf axil_if__segmentation ();

    logic ms_tick;

    logic                      frame_ready;
    logic                      frame_valid;
    logic [BUF_ID_WID-1:0]     frame_buf_id;
    logic [FRAME_SIZE_WID-1:0] frame_len;

    mem_wr_intf #(.DATA_WID(DATA_BYTE_WID*8), .ADDR_WID(ADDR_WID)) mem_wr_if (.clk);
    mem_rd_intf #(.DATA_WID(DATA_BYTE_WID*8), .ADDR_WID(ADDR_WID)) mem_rd_if (.clk);
    logic mem_init_done;

    // Shim: seg_tx_if (wide meta) → packet_in_if (narrow meta) + sideband
    sar_segment_to_packet #(
        .BUF_ID_WID   ( BUF_ID_WID ),
        .OFFSET_WID   ( OFFSET_WID ),
        .PKT_META_WID ( META_WID   )
    ) i_seg_to_pkt (
        .seg_if        ( seg_tx_if      ),
        .pkt_if        ( packet_in_if   ),
        .packet_buf_id ( packet_buf_id_in ),
        .packet_offset ( packet_offset_in ),
        .packet_last   ( packet_last_in   )
    );

    // Shim: packet_out_if (narrow meta) + sideband → seg_rx_if (wide meta)
    // clk/srst needed to latch sideband on first word (DUT may update before eop)
    sar_segment_from_packet #(
        .BUF_ID_WID   ( BUF_ID_WID ),
        .OFFSET_WID   ( OFFSET_WID ),
        .PKT_META_WID ( META_WID   )
    ) i_pkt_from_seg (
        .clk,
        .srst,
        .pkt_if        ( packet_out_if    ),
        .packet_buf_id ( packet_buf_id_out ),
        .packet_offset ( packet_offset_out ),
        .packet_last   ( packet_last_out   ),
        .seg_if        ( seg_rx_if         )
    );

    sar_packet_reassembly #(
        .NUM_FRAME_BUFFERS   ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE      ( MAX_FRAME_SIZE ),
        .MAX_PKT_SIZE        ( MAX_PKT_SIZE ),
        .TIMER_WID           ( TIMER_WID ),
        .MAX_FRAGMENTS       ( MAX_FRAGMENTS ),
        .BURST_SIZE          ( BURST_SIZE )
    ) DUT_reassembly (
        .clk,
        .srst,
        .init_done ( init_done__reassembly ),
        .packet_buf_id ( packet_buf_id_in ),
        .packet_offset ( packet_offset_in ),
        .packet_last   ( packet_last_in ),
        .packet_if     ( packet_in_if ),
        .axil_if       ( axil_if__reassembly ),
        .ms_tick,
        .frame_ready,
        .frame_valid,
        .frame_buf_id,
        .frame_len,
        .mem_wr_if,
        .mem_init_done
    );

    sar_packet_segmentation #(
        .NUM_FRAME_BUFFERS   ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE      ( MAX_FRAME_SIZE ),
        .MAX_PKT_SIZE        ( MAX_PKT_SIZE ),
        .MAX_RD_LATENCY      ( 64 )
    ) DUT_segmentation (
        .clk,
        .srst,
        .init_done ( init_done__segmentation ),
        .packet_buf_id ( packet_buf_id_out ),
        .packet_offset ( packet_offset_out ),
        .packet_size   ( packet_size_out ),
        .packet_last   ( packet_last_out ),
        .packet_if     ( packet_out_if ),
        .axil_if       ( axil_if__segmentation ),
        .frame_ready,
        .frame_valid,
        .frame_buf_id,
        .frame_len,
        .mem_rd_if,
        .mem_init_done
    );

    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_BYTE_WID*8,
        ASYNC: 1'b0,
        RESET_FSM: 1'b0,
        OPT_MODE: mem_pkg::OPT_MODE_DEFAULT
    };

    mem_ram_sdp #(
        .SPEC ( MEM_SPEC )
    ) ram (
        .mem_wr_if,
        .mem_rd_if
    );

    assign mem_init_done = 1'b1;

    //===================================
    // Testbench
    //===================================
    // AXI-L register agents
    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent__segmentation;
    sar_segmentation_reg_agent       seg_reg_agent;

    axi4l_verif_pkg::axi4l_reg_agent                                        axil_reg_agent__reassembly;
    sar_reassembly_reg_agent #(BUF_ID_T, OFFSET_T, FRAGMENT_PTR_T, TIMER_T) reassembly_reg_agent;
    packet_counters_reg_agent                                               pkt_cnt_reg_agent__reassembly;

    // Transport layer (concrete packet interface drivers)
    packet_intf_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) seg_pkt_driver;
    packet_intf_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) seg_pkt_monitor;

    // Frame-level environment
    sar_component_env #(BUF_ID_T, OFFSET_T, META_T) env;
    sar_model         #(BUF_ID_T)                   model;
    std_verif_pkg::event_scoreboard #(FRAME_T)       scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done__segmentation && init_done__reassembly;
    assign axil_aresetn = !srst;

    assign axil_if__reassembly.aresetn  = axil_aresetn;
    assign axil_if__segmentation.aresetn = axil_aresetn;

    // Assign clock (333 MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125 MHz)
    `SVUNIT_CLK_GEN(axil_aclk, 4ns);

    assign axil_if__reassembly.aclk  = axil_aclk;
    assign axil_if__segmentation.aclk = axil_aclk;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axil_reg_agent__segmentation = new("axil_reg_agent__segmentation");
        axil_reg_agent__segmentation.axil_vif = axil_if__segmentation;

        // Segmentation regs are at 0x1000 within sar_packet_segmentation's AXI-L space
        seg_reg_agent = new("seg_reg_agent", axil_reg_agent__segmentation, 'h1000);

        axil_reg_agent__reassembly = new("axil_reg_agent__reassembly");
        axil_reg_agent__reassembly.axil_vif = axil_if__reassembly;

        // Reassembly regs are at 0x4000 within sar_packet_reassembly's AXI-L space
        reassembly_reg_agent = new("reassembly_reg_agent", MAX_FRAGMENTS,
                                   axil_reg_agent__reassembly, 'h4000);
        // Packet counter regs are at 0x0000 within sar_packet_reassembly's AXI-L space
        pkt_cnt_reg_agent__reassembly = new("pkt_cnt_reg_agent__reassembly",
                                            axil_reg_agent__reassembly, 'h0000);

        seg_pkt_driver = new("seg_pkt_driver");
        seg_pkt_driver.packet_vif = seg_tx_if;

        seg_pkt_monitor = new("seg_pkt_monitor");
        seg_pkt_monitor.packet_vif = seg_rx_if;

        model      = new("sar_model");
        scoreboard = new("scoreboard");

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

        ms_tick = 0;

        // Pulses reset, waits for init_done__segmentation && init_done__reassembly,
        // then starts all subcomponents.
        env.run();

        // Configure segmentation DUT: set cfg_seg_len = MAX_PKT_SIZE so each output
        // frame produces exactly one segment, matching the sequencer's seg_len.
        // env.run() already guarantees init_done__segmentation=1 (READY state).
        begin
            sar_segmentation_reg_pkg::reg__config_t cfg;
            cfg.seg_len = MAX_PKT_SIZE;
            seg_reg_agent.write__config(cfg);
        end

        @(posedge clk);
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
    task tick();
        ms_tick <= 1'b1;
        @(posedge clk);
        ms_tick <= 1'b0;
    endtask

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

    //===================================
    // Test: reset
    // Verifies DUT comes out of reset cleanly (sar_packet only).
    //===================================
    `SVTEST(reset)
    `SVTEST_END

    `include "../common/sar_common_tests.svh"

    //===================================
    // Test: fragment_expiry
    // Exercises the ms_tick / expiry path end-to-end.
    // An errored (incomplete) frame leaves a fragment in the reassembly
    // cache; advancing the timer past cfg_timeout triggers expiry cleanup.
    // A subsequent clean frame on the same buf_id confirms stale cache
    // entries were removed.
    //===================================
    `SVTEST(fragment_expiry)
        FRAME_T errored_frame, clean_frame;
        int cnt;
        localparam int EXPIRY_TIMEOUT = 50;

        // Configure a short timeout so we don't need many ms_ticks
        reassembly_reg_agent.state.check.set_timeout(EXPIRY_TIMEOUT);

        // An errored frame: sequencer drops one segment, model discards it.
        // Incomplete segments land in the reassembly cache and stay there.
        errored_frame = new("errored", BUF_ID_T'(0), 256);
        fill_frame(errored_frame);
        errored_frame.error = 1;
        env.sequencer.set_seg_len(128);
        env.inbox.put(errored_frame);

        // Wait for at least one fragment pointer to be allocated
        do
            reassembly_reg_agent.cache.allocator.get_active_cnt(cnt);
        while (cnt < 1);

        // Advance timer past the configured timeout
        repeat (EXPIRY_TIMEOUT + 1) tick();

        // Allow expiry scan + deletion FSM to complete.
        // state_check scans MAX_FRAGMENTS (1024) entries, ~3 cycles each → ~3072 cycles/scan.
        // Two scans + deletion FSM overhead requires ~15000 cycles conservatively.
        repeat (15000) @(posedge clk);

        // Verify expired counter and allocator freed the pointer
        reassembly_reg_agent.get_expired_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 1);
        reassembly_reg_agent.cache.allocator.get_active_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 0);

        // Reassemble a clean frame on the same buf_id; stale hash entries
        // from the expired fragment would corrupt this if cleanup failed.
        clean_frame = new("clean", BUF_ID_T'(0), 512);
        fill_frame(clean_frame);
        env.sequencer.set_seg_len(SEG_LEN);

        @(posedge clk);
        env.inbox.put(clean_frame);
        check(1, 200us);
    `SVTEST_END

    //===================================
    // Test: counter_readback
    // Verifies that both DUTs increment their AXI-L debug counters
    // correctly after processing a batch of frames.
    //===================================
    `SVTEST(counter_readback)
        FRAME_T sent[5];
        int cnt;

        env.sequencer.set_seg_len(SEG_LEN);
        for (int i = 0; i < 5; i++) begin
            sent[i] = new($sformatf("frame_%0d", i), BUF_ID_T'(i), 512);
            fill_frame(sent[i]);
            env.inbox.put(sent[i]);
        end
        check(5, 500us);

        // Segmentation counters
        seg_reg_agent.get_frames_in_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 5);
        seg_reg_agent.get_segments_out_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 5);

        // Reassembly done counter
        reassembly_reg_agent.get_done_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 5);
    `SVTEST_END

    //===================================
    // Test: packet_err_dropped_and_counted
    // Directly drives a segment with pkt.err = 1 into sar_packet_reassembly.
    // Verifies the errored segment is dropped (not coalesced) and counted
    // by packet_counters.
    //===================================
    `SVTEST(packet_err_dropped_and_counted)
        sar_segment_transaction#(BUF_ID_T, OFFSET_T) err_seg;
        longint unsigned pkt_err_cnt, pkt_ok_cnt;
        int active_cnt;

        err_seg = new("err_seg", BUF_ID_T'(0), 0, 1'b1, 128, 1'b1);
        for (int i = 0; i < 128; i++) err_seg.data[i] = byte'(i);

        // Send errored segment
        env.driver.send(err_seg);
        repeat (100) @(posedge clk);

        // Verify fragment was not created/coalesced in reassembly cache
        reassembly_reg_agent.cache.allocator.get_active_cnt(active_cnt);
        `FAIL_UNLESS_EQUAL(active_cnt, 0);

        // Verify packet error counter incremented
        pkt_cnt_reg_agent__reassembly.get_pkt_err_count(pkt_err_cnt);
        `FAIL_UNLESS_EQUAL(pkt_err_cnt, 1);
        pkt_cnt_reg_agent__reassembly.get_pkt_ok_count(pkt_ok_cnt);
        `FAIL_UNLESS_EQUAL(pkt_ok_cnt, 0);
    `SVTEST_END

    //===================================
    // Test: soft_reset
    // Issues a software reset on both DUTs via AXI-L and verifies that
    // a frame can be processed correctly after recovery.
    //===================================
    `SVTEST(soft_reset)
        FRAME_T frame;
        sar_segmentation_reg_pkg::reg__config_t cfg;

        reassembly_reg_agent.soft_reset();
        seg_reg_agent.soft_reset();

        // Soft reset restores cfg_seg_len to default (512); reconfigure it
        cfg.seg_len = MAX_PKT_SIZE;
        seg_reg_agent.write__config(cfg);
        @(posedge clk);

        frame = new("frame", BUF_ID_T'(0), 512);
        fill_frame(frame);
        env.sequencer.set_seg_len(SEG_LEN);
        env.inbox.put(frame);
        check(1, 200us);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : sar_packet_unit_test
