`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1s

module alloc_sg_core_unit_test #(
    parameter int PTR_WID = 8
);
    import svunit_pkg::svunit_testcase;

    // Synthesize testcase name from parameters
    string name = $sformatf("alloc_sg_core_%0db_ut", PTR_WID);

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

    localparam type DESC_T = alloc_pkg::alloc#(BUFFER_SIZE, PTR_T, META_T)::desc_t;
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

    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_T(PTR_T), .META_T(META_T)) scatter_if [CONTEXTS] (.clk, .srst);
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_T(PTR_T), .META_T(META_T)) gather_if  [CONTEXTS] (.clk, .srst);

    logic   recycle_req;
    logic   recycle_rdy;
    PTR_T   recycle_ptr;

    mem_wr_intf #(.ADDR_WID(PTR_WID), .DATA_WID(DESC_WID)) desc_mem_wr_if (.clk);
    mem_rd_intf #(.ADDR_WID(PTR_WID), .DATA_WID(DESC_WID)) desc_mem_rd_if (.clk);
    logic                                                  desc_mem_init_done;

    alloc_sg_core        #(
        .SCATTER_CONTEXTS ( CONTEXTS ),
        .GATHER_CONTEXTS  ( CONTEXTS ),
        .PTR_T            ( PTR_T ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_FRAME_SIZE )
    ) DUT (.*);

    mem_ram_sdp #(
        .SPEC ( '{ADDR_WID: PTR_WID, DATA_WID: DESC_WID, ASYNC: 1'b0, RESET_FSM: 1'b0, OPT_MODE: mem_pkg::OPT_MODE_DEFAULT} )
    ) i_mem_ram_sdp (
        .mem_wr_if ( desc_mem_wr_if ),
        .mem_rd_if ( desc_mem_rd_if )
    );

    assign desc_mem_init_done = desc_mem_wr_if.rdy;

    //===================================
    // Testbench
    //===================================
    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    std_reset_intf reset_if (.clk(clk));

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;
    assign en = init_done;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        reset();
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

            void'(std::randomize(exp_size));
            void'(std::randomize(exp_meta));

            store_req(0, __ptr);
            store(0, __ptr, .eof(1'b1), .size(exp_size), .meta(exp_meta), .err(1'b0));

            `FAIL_UNLESS_EQUAL(__ptr, 0);

            wait(frame_valid[0]);
    
            `FAIL_UNLESS_EQUAL(frame_ptr, __ptr);
            `FAIL_UNLESS_EQUAL(frame_size, exp_size);

            load_req(0, __ptr);
            load(0, __nxt_ptr, __eof, got_size, got_meta, __err);

            `FAIL_IF(__err);
            `FAIL_UNLESS(__eof);
            `FAIL_UNLESS_EQUAL(got_size, exp_size);
            `FAIL_UNLESS_EQUAL(got_meta, exp_meta);

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
            end

            wait(frame_valid[0]);
            `FAIL_UNLESS_EQUAL(frame_ptr, 0);
            `FAIL_UNLESS_EQUAL(frame_size, exp_frame_size);

            __ptr = frame_ptr;
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
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

    task _wait(input int cycles);
        repeat(cycles) @(posedge clk);
    endtask

endmodule : alloc_sg_core_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific configuration in a way
//  that maintains SVUnit compatibility
`define ALLOC_SG_CORE_UNIT_TEST(PTR_WID)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  alloc_sg_core_unit_test#(PTR_WID) test();\
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
module alloc_sg_core_8b_unit_test;
`ALLOC_SG_CORE_UNIT_TEST(8);
endmodule

// (Block RAM) 4096-entry, 12-bit pointer allocator
module alloc_sg_core_12b_unit_test;
`ALLOC_SG_CORE_UNIT_TEST(12);
endmodule

// (Block RAM) 65536-entry, 16-bit pointer allocator
module alloc_sg_core_16b_unit_test;
`ALLOC_SG_CORE_UNIT_TEST(16);
endmodule

// (Ultra RAM) 262144-entry, 18-bit pointer allocator
module alloc_sg_core_18b_unit_test;
`ALLOC_SG_CORE_UNIT_TEST(18);
endmodule



