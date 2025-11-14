`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 20ms

module sar_reassembly_unit_test;
    import svunit_pkg::svunit_testcase;
    import sar_verif_pkg::*;

    string name = "sar_reassembly_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  NUM_FRAME_BUFFERS = 2;
    localparam int  MAX_FRAME_SIZE    = 2**20;
    localparam int  MAX_SEGMENT_SIZE  = 16384;

    localparam int  BUF_ID_WID      = $clog2(NUM_FRAME_BUFFERS);
    localparam int  OFFSET_WID      = $clog2(MAX_FRAME_SIZE);
    localparam int  FRAME_SIZE_WID  = $clog2(MAX_FRAME_SIZE+1);
    localparam int  SEGMENT_LEN_WID = $clog2(MAX_SEGMENT_SIZE+1);
    localparam int  TIMER_WID       = 16;
    localparam int  MAX_FRAGMENTS   = 8192;

    localparam int  FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS);

    localparam type BUF_ID_T       = logic[BUF_ID_WID-1:0];       // (Type) Reassembly buffer (context) pointer
    localparam type OFFSET_T       = logic[OFFSET_WID-1:0];       // (Type) Offset in bytes describing location of segment within frame
    localparam type FRAME_SIZE_T   = logic[FRAME_SIZE_WID-1:0];   // (Type) Byte length of frame
    localparam type SEGMENT_LEN_T  = logic[SEGMENT_LEN_WID-1:0];  // (Type) Length in bytes of current segment 
    localparam type FRAGMENT_PTR_T = logic[FRAGMENT_PTR_WID-1:0]; // (Type) Coalesced fragment record pointer
    localparam type TIMER_T        = logic[TIMER_WID-1:0];        // (Type) Frame expiry timer
    localparam int  BURST_SIZE     = 8;

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

    logic         ms_tick;

    logic         frame_ready;
    logic         frame_valid;
    BUF_ID_T      frame_buf_id;
    OFFSET_T      frame_len;

    axi4l_intf    axil_if ();

    // Instantiation
    sar_reassembly        #(
        .NUM_FRAME_BUFFERS ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE    ( MAX_FRAME_SIZE ),
        .MAX_SEGMENT_SIZE  ( MAX_SEGMENT_SIZE ),
        .TIMER_WID         ( TIMER_WID ),
        .MAX_FRAGMENTS     ( MAX_FRAGMENTS ),
        .BURST_SIZE        ( BURST_SIZE )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Environment
    std_verif_pkg::basic_env env;

    axi4l_verif_pkg::axi4l_reg_agent reg_agent;
    sar_reassembly_reg_agent #(BUF_ID_T, OFFSET_T, FRAGMENT_PTR_T, TIMER_T) agent;

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Assign AXI-L clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Interfaces
    std_reset_intf reset_if (.clk(clk));

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = !srst;

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

        agent = new("reassembly_reg_agent", MAX_FRAGMENTS, reg_agent, 0);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        idle();

        // HW reset
        env.reset_dut();

        en <= 1'b1;

        axil_if._wait(50); // Allow time for initial ID allocation
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
    //   soft reset
    //===================================
    `SVTEST(soft_reset)
        agent.soft_reset();
    `SVTEST_END

    //===================================
    // Test:
    //   single-segment buffer
    //===================================
    `SVTEST(single_segment_buffer)
        BUF_ID_T _buf;
        SEGMENT_LEN_T _len;
        int cnt;
        // Randomize inputs
        void'(std::randomize(_buf));
        void'(std::randomize(_len));
        send_segment(
            .buf_id(_buf),
            .offset(0),
            .len(_len),
            .last(1)
        );
        // Expect completed frame
        do
            @(posedge clk);
        while (!frame_valid);
        `FAIL_UNLESS_EQUAL(frame_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frame_len, _len);

        // Read status from reg agent
        agent.state.check.get_buffer_done_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 1);
       
        // If state is properly cleaned up, should be no more notifications
        fork
            begin
                // Wait for full scan of flows
                @(posedge DUT.i_sar_reassembly_state.i_state_core.i_state_notify_fsm.scan_done);
                @(posedge DUT.i_sar_reassembly_state.i_state_core.i_state_notify_fsm.scan_done);
            end
            begin
                // Expect no valid frames
                forever @(posedge clk) `FAIL_IF_LOG(frame_valid, "Unexpected frame completion.");
            end
        join_any;
        disable fork;

        // Read status from reg agent
        agent.state.check.get_buffer_done_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 1);
        agent.cache.allocator.get_active_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 0);
    `SVTEST_END
  
    //===================================
    // Test:
    //   single-segment expiry
    //===================================
    `SVTEST(single_segment_expiry)
        BUF_ID_T _buf;
        SEGMENT_LEN_T _len;
        int exp_timeout;
        int got_timeout;
        int cnt;

        // Configure timeout
        exp_timeout = $urandom_range(100,200);

        agent.state.check.set_timeout(exp_timeout);
        agent.state.check.get_timeout(got_timeout);
        `FAIL_UNLESS_EQUAL(got_timeout, exp_timeout);

        // Randomize inputs
        void'(std::randomize(_buf));
        void'(std::randomize(_len));
        send_segment(
            .buf_id(_buf),
            .offset(0),
            .len(_len),
            .last(0)
        );
        // Wait for fragment state to be established
        do
            agent.cache.allocator.get_active_cnt(cnt);
        while (cnt < 1);

        // Advance current timer to edge of expiry
        repeat (exp_timeout-1) tick();

        // Flow should not be expired (wait for one full scan of memory)
        fork
            begin
                // Wait for full scan of flows
                @(posedge DUT.i_sar_reassembly_state.i_state_core.i_state_notify_fsm.scan_done);
                @(posedge DUT.i_sar_reassembly_state.i_state_core.i_state_notify_fsm.scan_done);
            end
            begin
                // Expect no valid frames
                forever @(posedge clk) `FAIL_IF_LOG(frame_valid, "Unexpected frame completion.");
            end
        join_any;
        disable fork;

        // Read status from reg agent
        agent.state.check.get_fragment_expired_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 0);

        // Advance current timer to force expiry
        tick();

        // Flow should expired (wait for one full scan of memory)
        fork
            begin
                // Wait for full scan of flows
                @(posedge DUT.i_sar_reassembly_state.i_state_core.i_state_notify_fsm.scan_done);
                @(posedge DUT.i_sar_reassembly_state.i_state_core.i_state_notify_fsm.scan_done);
            end
            begin
                // Expect no valid frames
                forever @(posedge clk) `FAIL_IF_LOG(frame_valid, "Unexpected frame completion.");
            end
        join_any;
        disable fork;

        // Read status from reg agent
        agent.state.check.get_fragment_expired_cnt(cnt);
        `FAIL_UNLESS_EQUAL(cnt, 1);

        
    `SVTEST_END

    `SVUNIT_TESTS_END


    //===================================
    // Tasks
    //===================================
    task idle();
        seg_valid <= 1'b0;
        frame_ready <= 1'b1;
        ms_tick <= 1'b0;
    endtask

    task send_segment(
        input BUF_ID_T  buf_id,
        input OFFSET_T offset,
        input SEGMENT_LEN_T len,
        input logic last
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

    task tick();
        ms_tick <= 1'b1;
        @(posedge clk);
        ms_tick <= 1'b0;
    endtask
 
endmodule
