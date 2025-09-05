`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 20ms

module sar_reassembly_cache_unit_test;
    import svunit_pkg::svunit_testcase;
    import sar_pkg::*;
    import sar_verif_pkg::*;

    string name = "sar_reassembly_cache_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  BUF_ID_WID      = 1;
    localparam int  OFFSET_WID      = 32;
    localparam int  SEGMENT_LEN_WID = 14;
    localparam int  MAX_FRAGMENTS   = 1024;

    localparam int  FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS);

    localparam type BUF_ID_T       = logic[BUF_ID_WID-1:0];       // (Type) Reassembly buffer (context) pointer
    localparam type OFFSET_T       = logic[OFFSET_WID-1:0];       // (Type) Offset in bytes describing location of segment within frame
    localparam type SEGMENT_LEN_T  = logic[SEGMENT_LEN_WID-1:0];  // (Type) Length in bytes of current segment 
    localparam type FRAGMENT_PTR_T = logic[FRAGMENT_PTR_WID-1:0]; // (Type) Coalesced fragment record pointer
    localparam int  BURST_SIZE     = 8;

    localparam type KEY_T = struct packed {BUF_ID_T buf_id; OFFSET_T offset;};
    localparam type VALUE_T = struct packed {FRAGMENT_PTR_T ptr; OFFSET_T offset;};

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
        .BUF_ID_WID       ( BUF_ID_WID ),
        .OFFSET_WID       ( OFFSET_WID ),
        .SEGMENT_LEN_WID  ( SEGMENT_LEN_WID ),
        .FRAGMENT_PTR_WID ( FRAGMENT_PTR_WID ),
        .BURST_SIZE       ( BURST_SIZE ),
        .SIM__FAST_INIT ( 1 )
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
        // Randomize inputs
        void'(std::randomize(_buf));
        void'(std::randomize(_offset));
        void'(std::randomize(_len));
        send_seg(
            .buf_id(_buf),
            .offset(_offset),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);
    `SVTEST_END

    `SVTEST(fragment_append)
        BUF_ID_T _buf;
        OFFSET_T _offset_start;
        OFFSET_T _offset;
        SEGMENT_LEN_T _len;
        // Randomize inputs
        void'(std::randomize(_buf));
        void'(std::randomize(_offset_start));
        void'(std::randomize(_len));
        send_seg(
            .buf_id(_buf),
            .offset(_offset_start),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);
        `FAIL_UNLESS_EQUAL(frag_offset_start, _offset_start);
        `FAIL_UNLESS_EQUAL(frag_offset_end, _offset_start + _len);

        _offset = _offset_start + _len;

        void'(std::randomize(_len));
        send_seg(
            .buf_id(_buf),
            .offset(_offset),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b0);
        `FAIL_UNLESS_EQUAL(frag_offset_start, _offset_start);
        `FAIL_UNLESS_EQUAL(frag_offset_end, _offset + _len);
    `SVTEST_END

    `SVTEST(fragment_prepend)
        BUF_ID_T _buf;
        OFFSET_T _offset;
        SEGMENT_LEN_T _len;
        // Randomize inputs
        void'(std::randomize(_buf));
        void'(std::randomize(_offset));
        void'(std::randomize(_len));
        send_seg(
            .buf_id(_buf),
            .offset(_offset),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        void'(std::randomize(_len));
        _offset = _offset - _len;
        send_seg(
            .buf_id(_buf),
            .offset(_offset),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b0);
    `SVTEST_END

    `SVTEST(fragment_merge)
        BUF_ID_T _buf;
        OFFSET_T _offset;
        OFFSET_T _offset_middle;
        SEGMENT_LEN_T _len;
        SEGMENT_LEN_T _len_middle;
        // Randomize inputs
        void'(std::randomize(_buf));
        void'(std::randomize(_offset));
        void'(std::randomize(_len));
        send_seg(
            .buf_id(_buf),
            .offset(_offset),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        _offset_middle = _offset + _len;
        void'(std::randomize(_len_middle));
        void'(std::randomize(_len));

        _offset = _offset_middle + _len_middle;
        send_seg(
            .buf_id(_buf),
            .offset(_offset),
            .len(_len)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b1);

        send_seg(
            .buf_id(_buf),
            .offset(_offset_middle),
            .len(_len_middle)
        );
        do
            @(posedge clk);
        while (!frag_valid);
        `FAIL_UNLESS_EQUAL(frag_buf_id, _buf);
        `FAIL_UNLESS_EQUAL(frag_init, 1'b0);
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
