`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1s

module alloc_bv_unit_test #(
    parameter int PTR_WID = 8,
    parameter bit ALLOC_FC = 1'b0,
    parameter bit DEALLOC_FC = 1'b1
);
    import svunit_pkg::svunit_testcase;

    // Synthesize testcase name from parameters
    string name = $sformatf("alloc_bv_%0db_ut", PTR_WID);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam int MAX_PTRS = 2**PTR_WID;

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   en;
    logic   scan_en;

    //logic [PTR_WID:0] PTRS = MAX_PTRS;

    logic   init_done;

    logic   alloc_req;
    logic   alloc_rdy;
    PTR_T   alloc_ptr;

    logic   dealloc_req;
    logic   dealloc_rdy;
    PTR_T   dealloc_ptr;

    alloc_mon_intf mon_if (.clk);

    alloc_bv #(
        .PTR_WID        ( PTR_WID ),
        .ALLOC_FC       ( ALLOC_FC ),
        .DEALLOC_FC     ( DEALLOC_FC ),
        .SIM__FAST_INIT ( 0 )
    ) DUT (.*);

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
    assign scan_en = init_done;

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
        alloc_idle();
        dealloc_idle();

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
        //   allocate/deallocate single pointer
        //
        // Desc: Allocate a single pointer:
        //       - ptr0 should be received, and stats should track.
        //       Deallocate the pointer:
        //       - should complete successfully since the pointer was
        //       previously allocated
        //===================================
        `SVTEST(alloc_dealloc_single)
            PTR_T __ptr;
            int cnt;

            alloc(__ptr);

            `FAIL_UNLESS_EQUAL(__ptr, 0);

            dealloc(__ptr);
        `SVTEST_END

        //===================================
        // Test:
        //   allocate/deallocate all pointers
        //
        // Desc: Allocate all available pointers:
        //       - should return incrementing pointers
        //       - should finish successfully
        //       Deallocate all pointers:
        //       - should complete successfully
        //         (all pointers previously allocated)
        //===================================
        `SVTEST(alloc_dealloc_all)
            PTR_T __ptr;
            int cnt;

            // Allocate all pointers (expect sequential allocation)
            for (int i = 0; i < MAX_PTRS; i++) begin
                alloc(__ptr);
                `FAIL_UNLESS_EQUAL(__ptr, i);
                _wait($urandom % 20);
            end
            _wait(20);
            // Should be no more available pointers
            `FAIL_IF(alloc_rdy == 1);
            
            // Deallocate all pointers
            for (int i = 0; i < MAX_PTRS; i++) begin
                dealloc(i);
            end
        `SVTEST_END

        //===================================
        // Test:
        //   deallocate_error
        //
        // Desc: Allocate pointer, then deallocate
        //       it:
        //       - should complete successfully
        //       - dealloc error should not be asserted
        //       Deallocate the same pointer again:
        //       - should fail since that pointer should
        //         already be deallocated
        //       - err_dealloc should be asserted, with
        //         proper pointer value reported
        //===================================
        `SVTEST(dealloc_error)
            localparam int __TC_NUM_PTRS = MAX_PTRS/4;
            const int NUM_ERRS = $urandom % __TC_NUM_PTRS;
            PTR_T __ptr [__TC_NUM_PTRS];
            int cnt;

            for (int i = 0; i < __TC_NUM_PTRS; i++) begin
                alloc(__ptr[i]);
            end

            // Shuffle list of pointers
            __ptr.shuffle();

            // Deallocate all pointers
            fork
                begin
                    foreach (__ptr[i]) begin
                        dealloc(__ptr[i]);
                    end
                end
                begin
                    wait(mon_if.dealloc_err);
                    `FAIL_IF_LOG(
                        mon_if.dealloc_err == 1,
                        $sformatf(
                            "Unexpected deallocation error for id[0x%x]",
                            mon_if.ptr
                        )
                    );
                end
            join_any
            disable fork;

            // Shuffle list of pointers again
            __ptr.shuffle();

            // Deallocate a subset of the pointers again; check for (expected) deallocation errors
            for (int i = 0; i < NUM_ERRS; i++) begin
                dealloc(__ptr[i]);

                // Should trigger deallocation error
                wait(mon_if.dealloc_err);
 
                // Check that pointer corresponding to failed deallocation is reported correctly
                `FAIL_UNLESS_LOG(
                    mon_if.ptr == __ptr[i],
                    $sformatf(
                        "Mismatch in deallocation error pointer. Exp: id[0x%x], Got: id[0x%x].",
                        __ptr[i],
                        mon_if.ptr
                    )
                );

                wait(!mon_if.dealloc_err);
               
            end
          
        `SVTEST_END

    `SVUNIT_TESTS_END

    // Tasks
    task alloc_idle();
        alloc_req <= 1'b0;
        @(posedge clk);
    endtask

    task dealloc_idle();
        dealloc_req <= 1'b0;
        @(posedge clk);
    endtask

    task alloc(output PTR_T ptr);
        alloc_req <= 1'b1;
        do @(posedge clk);
        while (!alloc_rdy);
        alloc_req <= 1'b0;
        ptr = alloc_ptr;
    endtask

    task dealloc(input PTR_T ptr);
        dealloc_req <= 1'b1;
        dealloc_ptr <= ptr;
        do @(posedge clk);
        while (!dealloc_rdy);
        dealloc_req <= 1'b0;
    endtask

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

    task _wait(input int cycles);
        repeat(cycles) @(posedge clk);
    endtask

endmodule : alloc_bv_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific configuration in a way
//  that maintains SVUnit compatibility
`define ALLOC_BV_UNIT_TEST(PTR_WID)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  alloc_bv_unit_test#(PTR_WID) test();\
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
module alloc_bv_8b_unit_test;
`ALLOC_BV_UNIT_TEST(8);
endmodule

// (Block RAM) 4096-entry, 12-bit pointer allocator
module alloc_bv_12b_unit_test;
`ALLOC_BV_UNIT_TEST(12);
endmodule

// (Block RAM) 65536-entry, 16-bit pointer allocator
module alloc_bv_16b_unit_test;
`ALLOC_BV_UNIT_TEST(16);
endmodule

// (Ultra RAM) 262144-entry, 18-bit pointer allocator
module alloc_bv_18b_unit_test;
`ALLOC_BV_UNIT_TEST(18);
endmodule



