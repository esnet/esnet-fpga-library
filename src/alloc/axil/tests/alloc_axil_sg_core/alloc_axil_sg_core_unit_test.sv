`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1s

module alloc_axil_sg_core_unit_test #(
    parameter int PTR_WID = 8,
    parameter bit RAM_MODEL = 0,
    parameter int N_ALLOC = 1
);
    import svunit_pkg::svunit_testcase;
    import alloc_verif_pkg::*;

    // Synthesize testcase name from parameters
    string name;
    if (N_ALLOC > 1) assign name = $sformatf("alloc_axil_sg_core_%0db_%0ds_ut", PTR_WID, N_ALLOC);
    else             assign name = $sformatf("alloc_axil_sg_core_%0db_ut", PTR_WID);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam int  BUFFER_SIZE = 1024;
    localparam type SIZE_T = logic[$clog2(BUFFER_SIZE)-1:0];
    localparam int  MAX_FRAME_SIZE = 16384;
    localparam type FRAME_SIZE_T = logic[$clog2(MAX_FRAME_SIZE+1)-1:0];
    localparam type META_T = logic;
    localparam int  CONTEXTS = 1;
    localparam int  Q_DEPTH = 8;
    localparam int  PREALLOC_DEPTH = CONTEXTS * (CONTEXTS + 2);

    localparam int  META_WID = $bits(META_T);

    localparam type DESC_T = alloc_pkg::alloc#(BUFFER_SIZE, PTR_WID, META_WID)::desc_t;
    localparam int  DESC_WID = $bits(DESC_T);

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   en;

    logic   init_done;

    logic        frame_valid [CONTEXTS];
    logic        frame_error;
    PTR_T        frame_ptr;
    FRAME_SIZE_T frame_size;

    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) scatter_if [CONTEXTS] (.clk);
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) gather_if  [CONTEXTS] (.clk);

    logic   recycle_req;
    logic   recycle_rdy;
    PTR_T   recycle_ptr;
    logic   recycle_ack;

    mem_wr_intf #(.ADDR_WID(PTR_WID), .DATA_WID(DESC_WID)) desc_mem_wr_if (.clk);
    mem_rd_intf #(.ADDR_WID(PTR_WID), .DATA_WID(DESC_WID)) desc_mem_rd_if (.clk);
    logic                                                  desc_mem_init_done;

    axi4l_intf axil_if ();

    alloc_axil_sg_core        #(
        .SCATTER_CONTEXTS ( CONTEXTS ),
        .GATHER_CONTEXTS  ( CONTEXTS ),
        .PTR_WID          ( PTR_WID ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_FRAME_SIZE ),
        .META_WID         ( META_WID ),
        .STORE_Q_DEPTH    ( Q_DEPTH ),
        .LOAD_Q_DEPTH     ( Q_DEPTH ),
        .N_ALLOC          ( N_ALLOC )
    ) DUT (.*);

    mem_ram_sdp #(
        .SPEC ( '{ADDR_WID: PTR_WID, DATA_WID: DESC_WID, ASYNC: 1'b0, RESET_FSM: 1'b0, OPT_MODE: mem_pkg::OPT_MODE_DEFAULT} ),
        .SIM__RAM_MODEL ( RAM_MODEL )
    ) i_mem_ram_sdp (
        .mem_wr_if ( desc_mem_wr_if ),
        .mem_rd_if ( desc_mem_rd_if )
    );

    assign desc_mem_init_done = desc_mem_wr_if.rdy;

    //===================================
    // Testbench
    //===================================
    // Assign clock (330MHz)
    `SVUNIT_CLK_GEN(clk, 1.67ns);

    // Assign AXI-L clock (100MHz);
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns); 

    std_reset_intf reset_if (.clk(clk));

    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent;
    alloc_reg_agent reg_agent;

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;
    assign en = init_done;

    initial axil_if.aresetn = 1'b0;
    always @(posedge axil_if.aclk or posedge srst) axil_if.aresetn <= !srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // AXI-L agent
        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;

        // Reg agent
        reg_agent = new("alloc_reg_agent", axil_reg_agent, 0);

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        int cnt;

        svunit_ut.setup();

        reset();

        recycle_req = 1'b0;

        // Wait for allocator queues to fill
        // (makes stats accounting easier later)
        do begin
            reg_agent.get_active_cnt(cnt);
        end while (cnt < PREALLOC_DEPTH);

    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
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
        `SVTEST(hard_reset)
        `SVTEST_END

        //===================================
        // Test:
        //   store/load single-buffer frame
        //
        // Desc: Allocate a single buffer, then
        //       load using received pointer
        //===================================
        `SVTEST(store_load_single)
            PTR_T  __ptr, __nxt_ptr;
            logic  __eof;
            logic  __err;
            SIZE_T exp_size, got_size;
            META_T exp_meta, got_meta;
            int    cnt;

            void'(std::randomize(exp_size));
            void'(std::randomize(exp_meta));

            store_req(0, __ptr);
            store(0, __ptr, .eof(1'b1), .size(exp_size), .meta(exp_meta), .err(1'b0));

            wait(frame_valid[0]);
    
            `FAIL_UNLESS_EQUAL(frame_ptr, __ptr);
            `FAIL_UNLESS_EQUAL(frame_size, exp_size);

            repeat(10) @(posedge clk);

            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH + 1);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH + 1);
            reg_agent.get_alloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);

            load_req(0, __ptr);
            load(0, __nxt_ptr, __eof, got_size, got_meta, __err);

            `FAIL_IF(__err);
            `FAIL_UNLESS(__eof);
            `FAIL_UNLESS_EQUAL(got_size, exp_size);
            `FAIL_UNLESS_EQUAL(got_meta, exp_meta);

            repeat(50) @(posedge clk);

            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH + 1);
            reg_agent.get_alloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 1);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);

        `SVTEST_END

        //===================================
        // Test:
        //   store/load multi-buffer frame
        //
        // Desc: Allocate all available pointers:
        //       - should return incrementing pointers
        //       - should finish successfully
        //       Deallocate all pointers:
        //       - should complete successfully
        //         (all pointers previously allocated)
        //===================================
        `SVTEST(store_load_multi)
            PTR_T  __ptr, __nxt_ptr;
            logic  __eof;
            logic  __err;
            int    __frame_size;
            SIZE_T __size;
            FRAME_SIZE_T exp_frame_size;
            META_T exp_meta, got_meta;
            PTR_T  __desc_chain [*];
            automatic int buffers = 0;
            int    cnt;

            // Randomize frame details
            void'(std::randomize(exp_meta));
            exp_frame_size = $urandom_range(BUFFER_SIZE + 1, MAX_FRAME_SIZE-1);

            __frame_size = exp_frame_size;
            while (__frame_size > 0) begin
                if (__frame_size < BUFFER_SIZE) begin
                    __eof = 1'b1;
                    __size = __frame_size;
                    __frame_size = 0;
                end else begin
                    __eof = 1'b0;
                    __size = 0;
                    __frame_size -= BUFFER_SIZE;
                end
                store_req(0, __ptr);
                store(0, __ptr, .eof(__eof), .size(__size), .meta(exp_meta), .err(1'b0));
                `INFO($sformatf("Stored %0d bytes at 0x%x (eof: %b, meta: 0x%x, err: %b)", __eof ? __size : BUFFER_SIZE, __ptr, __eof, exp_meta, 1'b0));
                buffers++;
            end

            wait(frame_valid[0]);
            `FAIL_UNLESS_EQUAL(frame_size, exp_frame_size);
            __ptr = frame_ptr;

            repeat(100) @(posedge clk);

            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH + buffers);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH + buffers);
            reg_agent.get_alloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);

            __frame_size = 0;
            __eof = 1'b0;
            load_req(0, __ptr);
            while (!__eof) begin
                load(0, __nxt_ptr, __eof, __size, got_meta, __err);
                `INFO($sformatf("Loaded %0d bytes from 0x%x (eof: %b, meta: 0x%x, err: %b)", __eof ? __size : BUFFER_SIZE, __nxt_ptr, __eof, exp_meta, 1'b0));
                `FAIL_IF(__err);
                `FAIL_UNLESS_EQUAL(got_meta, exp_meta);
                __frame_size += __eof ? __size : BUFFER_SIZE;
            end

            `FAIL_UNLESS_EQUAL(__frame_size, exp_frame_size);

            repeat(100) @(posedge clk);

            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, PREALLOC_DEPTH + buffers);
            reg_agent.get_alloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, buffers);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS_EQUAL(cnt, 0);

        `SVTEST_END

    `SVUNIT_TESTS_END

    task store_req(input int ctxt, output PTR_T ptr);
        scatter_if[0].store_req(ptr);
    endtask

    task store(input int ctxt, input PTR_T ptr, input logic eof=1'b0, input SIZE_T size=0, input META_T meta=0, input logic err=1'b0);
        scatter_if[0].store(ptr, eof, size, meta, err);
    endtask

    task load_req(input int ctxt, input PTR_T ptr);
        gather_if[0].load_req(ptr);
    endtask

    task load(input int ctxt, output PTR_T ptr, output logic eof, output SIZE_T size, output META_T meta, output logic err);
        gather_if[0].load(ptr, eof, size, meta, err);
    endtask

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

    task _wait(input int cycles);
        repeat(cycles) @(posedge clk);
    endtask

endmodule : alloc_axil_sg_core_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific configuration in a way
//  that maintains SVUnit compatibility
`define ALLOC_AXIL_SG_CORE_UNIT_TEST(PTR_WID,RAM_MODEL,N_ALLOC)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  alloc_axil_sg_core_unit_test#(PTR_WID,RAM_MODEL,N_ALLOC) test();\
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

// (Distributed RAM) 8-bit pointer allocator
module alloc_axil_sg_core_8b_unit_test;
`ALLOC_AXIL_SG_CORE_UNIT_TEST(8,0,1);
endmodule

// (Block RAM) 4096-entry, 12-bit pointer allocator
module alloc_axil_sg_core_12b_unit_test;
`ALLOC_AXIL_SG_CORE_UNIT_TEST(12,0,1);
endmodule

// (Block RAM) 65536-entry, 16-bit pointer allocator
module alloc_axil_sg_core_16b_unit_test;
`ALLOC_AXIL_SG_CORE_UNIT_TEST(16,1,1);
endmodule

// (Block RAM) 65536-entry, 16-bit pointer (2 slices) allocator
module alloc_axil_sg_core_16b_2s_unit_test;
`ALLOC_AXIL_SG_CORE_UNIT_TEST(16,1,2);
endmodule

// (Ultra RAM) 262144-entry, 18-bit pointer allocator
module alloc_axil_sg_core_18b_unit_test;
`ALLOC_AXIL_SG_CORE_UNIT_TEST(18,1,1);
endmodule



