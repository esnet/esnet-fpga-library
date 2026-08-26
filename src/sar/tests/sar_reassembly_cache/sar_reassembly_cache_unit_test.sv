`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 20ms

module sar_reassembly_cache_unit_test;
    import svunit_pkg::svunit_testcase;
    import sar_pkg::*;
    import sar_verif_pkg::*;
    import db_pkg::*;

    string name = "sar_reassembly_cache_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  NUM_FRAME_BUFFERS = 2;
    localparam int  MAX_FRAME_SIZE    = 2**20;
    localparam int  MAX_SEGMENT_SIZE  = 16384;

    localparam int  BUF_ID_WID      = $clog2(NUM_FRAME_BUFFERS);
    localparam int  OFFSET_WID      = $clog2(MAX_FRAME_SIZE);
    localparam int  SEGMENT_LEN_WID = $clog2(MAX_SEGMENT_SIZE+1);
    localparam int  MAX_FRAGMENTS   = 1024;

    localparam int  FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS);

    localparam type BUF_ID_T       = logic[BUF_ID_WID-1:0];       // (Type) Reassembly buffer (context) pointer
    localparam type OFFSET_T       = logic[OFFSET_WID-1:0];       // (Type) Offset in bytes describing location of segment within frame
    localparam type SEGMENT_LEN_T  = logic[SEGMENT_LEN_WID-1:0];  // (Type) Length in bytes of current segment 
    localparam type FRAGMENT_PTR_T = logic[FRAGMENT_PTR_WID-1:0]; // (Type) Coalesced fragment record pointer
    localparam int  BURST_SIZE     = 8;

    localparam type KEY_T = struct packed {BUF_ID_T buf_id; OFFSET_T offset;};
    localparam type VALUE_T = struct packed {FRAGMENT_PTR_T ptr; OFFSET_T offset; logic last;};

    localparam int KEY_WID  = $bits(KEY_T);
    localparam int VALUE_WID = $bits(VALUE_T);

    //===================================
    // DUT
    //===================================

    // Signals
    logic         clk;
    logic         srst;

    logic         en;

    logic         init_done;

    logic         seg_ready;
    logic         seg_valid;
    BUF_ID_T      seg_buf_id;
    OFFSET_T      seg_offset;
    SEGMENT_LEN_T seg_len;
    logic         seg_last;

    logic             frag_valid;
    logic             frag_init;
    BUF_ID_T          frag_buf_id;
    logic             frag_last;
    FRAGMENT_PTR_T    frag_ptr;
    OFFSET_T          frag_offset_start;
    OFFSET_T          frag_offset_end;

    logic             frag_merged;
    FRAGMENT_PTR_T    frag_merged_ptr;

    logic           frag_ptr_dealloc_rdy;
    logic           frag_ptr_dealloc_req;
    FRAGMENT_PTR_T  frag_ptr_dealloc_value;

    axi4l_intf axil_if ();

    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if__append  (.clk(clk));
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if__prepend (.clk(clk));
    
    // Instantiation
    sar_reassembly_cache #(
        .NUM_FRAME_BUFFERS ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE    ( MAX_FRAME_SIZE ),
        .MAX_SEGMENT_SIZE  ( MAX_SEGMENT_SIZE ),
        .MAX_FRAGMENTS     ( MAX_FRAGMENTS ),
        .BURST_SIZE        ( BURST_SIZE ),
        .SIM__FAST_INIT    ( 1 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::basic_env env;

    axi4l_verif_pkg::axi4l_reg_agent #() reg_agent;
    sar_reassembly_cache_reg_agent #(BUF_ID_T, OFFSET_T, FRAGMENT_PTR_T) agent;

    std_reset_intf reset_if (.clk);

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Assign AXI-L clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    assign axil_if.aresetn = !srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Testbench environment
        env = new;
        env.reset_vif = reset_if;

        // AXI-L agent
        reg_agent = new("axil_reg_agent");
        reg_agent.axil_vif = axil_if;

        agent = new("reassembly_cache_reg_agent", MAX_FRAGMENTS, reg_agent, 0);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        agent.idle();
        idle();

        // HW reset
        env.reset_dut();

        en = 1'b1;

        agent.wait_ready();
    endtask

    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
        /* Place Teardown Code Here */
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
    `SVUNIT_TESTS_BEGIN

    //===================================
    // Test:
    //   reset
    //
    // Desc: Assert reset and check that
    //       inititialization completes
    //       successfully.
    //       (Note) reset assertion/check
    //       is included in setup() task
    //===================================
    `SVTEST(reset)
    `SVTEST_END

    //===================================
    // Test:
    //   soft_reset
    //
    // Desc: Assert reset and check that
    //       inititialization completes
    //       successfully.
    //       (Note) reset assertion/check
    //       is included in setup() task
    //===================================
    `SVTEST(soft_reset)
        agent.soft_reset();
    `SVTEST_END


    //===================================
    // Test:
    //   axil_control
    //
    //===================================
    `SVTEST(info)
        int got_size;
        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, MAX_FRAGMENTS);
    `SVTEST_END

    //===================================
    // Test:
    //   single-segment buffer
    //===================================
    `SVTEST(fragment_create)
        BUF_ID_T _buf;
        OFFSET_T _offset;
        SEGMENT_LEN_T _len;
        int cnt;
        void'(std::randomize(_buf));
        void'(std::randomize(_offset));
        void'(std::randomize(_len));
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);
        // Counter checks
        agent.get_seg_rx_cnt(cnt);     `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_create_cnt(cnt);`FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_append_cnt(cnt);`FAIL_UNLESS_EQUAL(cnt, 0);
        agent.get_frag_merge_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 0);
    `SVTEST_END

    `SVTEST(fragment_append)
        BUF_ID_T _buf;
        OFFSET_T _offset_start;
        OFFSET_T _offset;
        SEGMENT_LEN_T _len;
        int cnt;
        void'(std::randomize(_buf));
        void'(std::randomize(_offset_start));
        void'(std::randomize(_len));
        send_seg(.buf_id(_buf), .offset(_offset_start), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);
        `FAIL_UNLESS_EQUAL(frag_offset_start, _offset_start);
        `FAIL_UNLESS_EQUAL(frag_offset_end, _offset_start + _len);

        _offset = _offset_start + _len;
        void'(std::randomize(_len));
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b0);
        `FAIL_UNLESS_EQUAL(frag_offset_start, _offset_start);
        `FAIL_UNLESS_EQUAL(frag_offset_end, _offset + _len);
        // Counter checks
        agent.get_seg_rx_cnt(cnt);      `FAIL_UNLESS_EQUAL(cnt, 2);
        agent.get_frag_create_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_append_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_prepend_cnt(cnt);`FAIL_UNLESS_EQUAL(cnt, 0);
        agent.get_frag_merge_cnt(cnt);  `FAIL_UNLESS_EQUAL(cnt, 0);
    `SVTEST_END

    `SVTEST(fragment_prepend)
        BUF_ID_T _buf;
        OFFSET_T _offset;
        SEGMENT_LEN_T _len;
        int cnt;
        void'(std::randomize(_buf));
        void'(std::randomize(_offset));
        void'(std::randomize(_len));
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        void'(std::randomize(_len));
        _offset = _offset - _len;
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b0);
        // Counter checks
        agent.get_frag_create_cnt(cnt);  `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_prepend_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_append_cnt(cnt);  `FAIL_UNLESS_EQUAL(cnt, 0);
        agent.get_frag_merge_cnt(cnt);   `FAIL_UNLESS_EQUAL(cnt, 0);
    `SVTEST_END

    `SVTEST(fragment_merge)
        BUF_ID_T _buf;
        OFFSET_T _offset;
        OFFSET_T _offset_middle;
        SEGMENT_LEN_T _len;
        SEGMENT_LEN_T _len_middle;
        int cnt;
        void'(std::randomize(_buf));
        void'(std::randomize(_offset));
        void'(std::randomize(_len));
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        _offset_middle = _offset + _len;
        void'(std::randomize(_len_middle));
        void'(std::randomize(_len));

        _offset = _offset_middle + _len_middle;
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        send_seg(.buf_id(_buf), .offset(_offset_middle), .len(_len_middle));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b0);
        // Counter checks: 2 creates + 1 merge
        agent.get_frag_create_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 2);
        agent.get_frag_merge_cnt(cnt);  `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.get_frag_append_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 0);
    `SVTEST_END

    //===================================
    // Test: allocator_exhaustion
    //
    // Desc: Fill the allocator to capacity
    //       and send one extra segment;
    //       verify it is silently dropped
    //       and counted by dbg_cnt_alloc_drop.
    //===================================
    `SVTEST(allocator_exhaustion)
        int cnt;
        // Use consecutive offsets on buf_id 0 so each segment creates
        // a new fragment (no append/prepend matches)
        for (int i = 0; i < MAX_FRAGMENTS; i++) begin
            send_seg(.buf_id(0), .offset(OFFSET_T'(i * 10)), .len(1));
            do @(posedge clk); while (!frag_valid);
        end
        // Allocator should now be full
        agent.allocator.get_active_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, MAX_FRAGMENTS);

        // One more segment — expect it to be accepted by the lookup pipeline
        // but silently dropped (no fragment pointer available)
        send_seg(.buf_id(0), .offset(OFFSET_T'(MAX_FRAGMENTS * 10)), .len(1));
        repeat (20) @(posedge clk);

        // Allocator count should be unchanged
        agent.allocator.get_active_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, MAX_FRAGMENTS);

        // Drop counter should be exactly 1
        agent.get_alloc_drop_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 1);
    `SVTEST_END


    //===================================
    // Test:
    //   cache_cleanup_after_expiry
    //
    // Desc: Create a fragment, then issue
    //       ctrl_if deletes for both its
    //       append and prepend hash table
    //       entries (simulating what the
    //       expiry path does). Verify that
    //       a subsequent segment at the same
    //       offset creates a new fragment
    //       (frag_init=1) rather than appending
    //       to a stale entry.
    //===================================
    `SVTEST(cache_cleanup_after_expiry)
        BUF_ID_T _buf;
        OFFSET_T _offset;
        SEGMENT_LEN_T _len;
        int cnt;
        void'(std::randomize(_buf));
        _offset = 100;  // non-zero so both append and prepend table entries are created
        _len = 500;

        // Create a fragment: append key = {buf, offset+len}, prepend key = {buf, offset}
        send_seg(.buf_id(_buf), .offset(_offset), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        // Simulate expiry cleanup: delete both hash table entries
        cache_delete_append (_buf, OFFSET_T'(_offset + _len));
        cache_delete_prepend(_buf, _offset);

        // Re-send at the same offset; a stale append entry would cause FRAGMENT_APPEND
        // (the new segment's offset matches the old fragment's end), not FRAGMENT_CREATE
        repeat (5) @(posedge clk);
        send_seg(.buf_id(_buf), .offset(OFFSET_T'(_offset + _len)), .len(_len));
        do @(posedge clk); while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        // Two creates total, no appends
        agent.get_frag_create_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 2);
        agent.get_frag_append_cnt(cnt); `FAIL_UNLESS_EQUAL(cnt, 0);
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    task idle();
        seg_valid <= 1'b0;
        frag_ptr_dealloc_req <= 1'b0;
        ctrl_if__append.req = 1'b0;
        ctrl_if__prepend.req = 1'b0;
    endtask

    // Issue COMMAND_UNSET on the append ctrl interface for {buf_id, offset}
    task cache_delete_append(input BUF_ID_T buf_id, input OFFSET_T offset);
        KEY_T key;
        bit _error;
        key.buf_id = buf_id;
        key.offset = offset;
        ctrl_if__append._set_key(key);
        ctrl_if__append.transact(COMMAND_UNSET, _error);
    endtask

    // Issue COMMAND_UNSET on the prepend ctrl interface for {buf_id, offset}
    task cache_delete_prepend(input BUF_ID_T buf_id, input OFFSET_T offset);
        KEY_T key;
        bit _error;
        key.buf_id = buf_id;
        key.offset = offset;
        ctrl_if__prepend._set_key(key);
        ctrl_if__prepend.transact(COMMAND_UNSET, _error);
    endtask

    task send_seg(
        input BUF_ID_T buf_id,
        input OFFSET_T offset,
        input SEGMENT_LEN_T len,
        input logic last = 1'b0
    );
        seg_valid <= 1'b1;
        seg_buf_id <= buf_id;
        seg_offset <= offset;
        seg_len <= len;
        seg_last <= last;
        do 
            @(posedge clk);
        while (!seg_ready);
        seg_valid <= 1'b0;
    endtask
 
endmodule
