`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1s

module alloc_axil_ll_core_unit_test #(
    parameter int LIST_CONTEXTS = 16,
    parameter int PTR_WID = 8
);
    import svunit_pkg::svunit_testcase;
    import alloc_verif_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("alloc_axil_ll_core_%0dl_%0db_ut", LIST_CONTEXTS, PTR_WID);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam int MAX_PTRS = 2**PTR_WID;

    localparam int  META_WID = 32;
    localparam type META_T = logic[META_WID-1:0];

    localparam int  LIST_SEL_WID = LIST_CONTEXTS > 1 ? $clog2(LIST_CONTEXTS) : 1;
    localparam type LIST_SEL_T = logic[LIST_SEL_WID-1:0];

    localparam mem_pkg::spec_t  MEM_SPEC = '{
                                        ADDR_WID: PTR_WID,
                                        DATA_WID: 256,
                                        ASYNC: 1'b0,
                                        RESET_FSM: 1'b0,
                                        OPT_MODE: mem_pkg::OPT_MODE_DEFAULT
                                    };
    localparam int NUM_RD_TRANSACTIONS = mem_pkg::get_rd_latency(MEM_SPEC);

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   en;

    logic   init_done;

    logic                      store_req;
    logic                      store_rdy;
    logic   [LIST_SEL_WID-1:0] store_list_sel;
    logic   [META_WID-1:0]     store_meta;
    logic                      store_ack;
    logic                      store_nack;

    logic                      load_req;
    logic                      load_rdy;
    logic   [LIST_SEL_WID-1:0] load_list_sel;
    logic   [META_WID-1:0]     load_meta;
    logic                      load_ack;
    logic                      load_nack;

    mem_wr_intf #(.ADDR_WID(PTR_WID), .DATA_WID(256)) mem_wr_if (.clk);
    mem_rd_intf #(.ADDR_WID(PTR_WID), .DATA_WID(256)) mem_rd_if (.clk);
    logic mem_init_done;

    axi4l_intf axil_if ();

    alloc_axil_ll_core      #(
        .LIST_CONTEXTS       ( LIST_CONTEXTS ),
        .PTR_WID             ( PTR_WID ),
        .META_WID            ( META_WID ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS )
    ) DUT (.*);

    mem_ram_sdp #(
        .SPEC ( MEM_SPEC )
    ) i_mem_ram_sdp (
        .*
    );

    assign mem_init_done = mem_wr_if.rdy;

    //===================================
    // Testbench
    //===================================
    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    std_reset_intf reset_if (.clk(clk));

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;
    assign en = 1'b1;

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
        store_idle();
        load_idle();

        reset();
        @(posedge clk);
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
        //   allocate/deallocate single pointer
        //
        // Desc: Allocate a single pointer:
        //       - ptr0 should be received, and stats should track.
        //       Deallocate the pointer:
        //       - should complete successfully since the pointer was
        //       previously allocated
        //===================================
        `SVTEST(store_load_single)
            LIST_SEL_T __list;
            META_T __meta;

            void'(std::randomize(__list));
            void'(std::randomize(__meta));

            store(__list, __meta);
            wait(store_ack || store_nack);
            `FAIL_UNLESS(store_ack);
            `FAIL_IF(store_nack);

            load(__list, __meta);
            wait(load_ack || load_nack);
            `FAIL_UNLESS(load_ack);
            `FAIL_IF(load_nack);
        `SVTEST_END

    `SVUNIT_TESTS_END
    // Tasks
    task store_idle();
        store_req <= 1'b0;
        @(posedge clk);
    endtask

    task load_idle();
        load_req <= 1'b0;
        @(posedge clk);
    endtask

    task store(input LIST_SEL_T list, input META_T meta=0);
        store_req <= 1'b1;
        store_list_sel <= list;
        store_meta <= meta;
        do @(posedge clk);
        while (!store_rdy);
        store_req <= 1'b0;
    endtask

    task load(input LIST_SEL_T list, output META_T meta);
        load_req <= 1'b1;
        load_list_sel <= list;
        do @(posedge clk);
        while (!load_rdy);
        load_req <= 1'b0;
    endtask

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 0);
    endtask

    task _wait(input int cycles);
        repeat(cycles) @(posedge clk);
    endtask

endmodule : alloc_axil_ll_core_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific configuration in a way
//  that maintains SVUnit compatibility
`define ALLOC_AXIL_LL_CORE_UNIT_TEST(LIST_CONTEXTS,PTR_WID)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  alloc_axil_ll_core_unit_test#(LIST_CONTEXTS,PTR_WID) test();\
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
module alloc_axil_ll_core_16l_8b_unit_test;
`ALLOC_AXIL_LL_CORE_UNIT_TEST(16,8);
endmodule