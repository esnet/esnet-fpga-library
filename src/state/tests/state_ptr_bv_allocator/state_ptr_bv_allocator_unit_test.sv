`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 100ms

module state_ptr_bv_allocator_unit_test #(
    parameter int PTR_WID = 8,
    parameter bit ALLOC_FC = 1'b0,
    parameter bit DEALLOC_FC = 1'b1
);
    import svunit_pkg::svunit_testcase;
    import state_verif_pkg::*;

    // Synthesize testcase name from parameters
    string name = $sformatf("state_ptr_bv_allocator_%0db_ut", PTR_WID);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam int NUM_PTRS = 2**PTR_WID;

    //===================================
    // DUT
    //===================================

    logic   clk;
    logic   srst;

    logic   init_done;
    logic   en;

    logic   alloc_req;
    logic   alloc_rdy;
    PTR_T   alloc_ptr;

    logic   dealloc_req;
    logic   dealloc_rdy;
    PTR_T   dealloc_ptr;

    logic   err_alloc;
    logic   err_dealloc;
    PTR_T   err_ptr;

    axi4l_intf axil_if ();

    state_ptr_bv_allocator #(
        .PTR_T          ( PTR_T ),
        .ALLOC_FC       ( ALLOC_FC ),
        .DEALLOC_FC     ( DEALLOC_FC ),
        .SIM__FAST_INIT ( 0 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    // Assign AXI-L clock (62.5MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 8ns);

    std_reset_intf reset_if (.clk(clk));

    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent;
    state_ptr_allocator_reg_agent reg_agent;

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
        reg_agent = new("state_ptr_allocator_reg_agent", axil_reg_agent, 0);

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        reg_agent.idle();
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
        `SVTEST(reset)
        `SVTEST_END

        //===================================
        // Test:
        //   soft reset
        //
        // Desc: Assert soft reset via register
        //       interface and check that
        //       initialization completes
        //       successfully.
        //===================================
        `SVTEST(soft_reset)
            reg_agent.soft_reset();
        `SVTEST_END

        //===================================
        // Test:
        //   info check
        //
        // Desc: Read info register and check
        //       that contents match expected
        //       parameterization.
        //===================================
        `SVTEST(info_check)
            int size;
            reg_agent.get_size(size);
            `FAIL_UNLESS(size == NUM_PTRS);
        `SVTEST_END

        //===================================
        // Test:
        //   allocate/deallocate single pointer
        //
        // Desc: Allocate a single pointer:
        //       - ptr0 should be received, and stats should track.
        //       Deallocate the pointer:
        //       - should complete successfully since the pointer was
        //       previously allocated, and stacks should
        //===================================
        `SVTEST(alloc_dealloc_single)
            PTR_T __ptr;
            int cnt;

            alloc(__ptr);

            // Allow counters to update
            _wait(1);

            `FAIL_UNLESS(__ptr == 0);
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == 1);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == 1);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);

            dealloc(__ptr);

            // Wait for dealloc operation to complete
            _wait(20);

            `FAIL_UNLESS(__ptr == 0);
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == 1);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == 1);
        `SVTEST_END

        //===================================
        // Test:
        //   allocate/deallocate all pointers
        //
        // Desc: Allocate all available pointers:
        //       - should return incrementing pointers
        //       - should finish successfully
        //       - stats should track
        //       Deallocate all pointers:
        //       - should complete successfully
        //         (all pointers previously allocated)
        //       - stats should track
        //===================================
        `SVTEST(alloc_dealloc_all)
            PTR_T __ptr;
            int cnt;

            // Allocate all pointers (expect sequential allocation)
            for (int i = 0; i < NUM_PTRS; i++) begin
                alloc(__ptr);
                `FAIL_UNLESS(__ptr == i);
                _wait($urandom % 20);
            end
            // Allow counters to update
            _wait(1);
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == NUM_PTRS);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == NUM_PTRS);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);

            _wait(20);
            // Should be no more available pointers
            `FAIL_IF(alloc_rdy == 1);
            
            // Deallocate all pointers
            for (int i = 0; i < NUM_PTRS; i++) begin
                dealloc(i);
            end
            // Wait for dealloc operation to complete
            _wait(1000);
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == NUM_PTRS);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == NUM_PTRS);
        `SVTEST_END

        //===================================
        // Test:
        //   deallocate_error
        //
        // Desc: Allocate pointer, then deallocate
        //       it:
        //       - should complete successfully
        //       - stats should track
        //       - dealloc error should not be asserted
        //       Deallocate the same pointer again:
        //       - should fail since that pointer should
        //         already be deallocated
        //       - stats should not update
        //       - err_dealloc should be asserted, with
        //         proper pointer value reported
        //===================================
        `SVTEST(dealloc_error)
            localparam int __TC_NUM_PTRS = NUM_PTRS/4;
            const int NUM_ERRS = $urandom % __TC_NUM_PTRS;
            PTR_T __ptr [__TC_NUM_PTRS];
            int cnt;

            for (int i = 0; i < __TC_NUM_PTRS; i++) begin
                alloc(__ptr[i]);
            end

            // Allow counters to update
            _wait(1);
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == __TC_NUM_PTRS);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == __TC_NUM_PTRS);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);

            // Disable pointer allocation
            reg_agent.disable_allocation();

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
                    wait(err_dealloc);
                    `FAIL_IF_LOG(
                        err_dealloc == 1,
                        $sformatf(
                            "Unexpected deallocation error for ptr[0x%x]",
                            err_ptr
                        )
                    );
                end
            join_any
            disable fork;

            // Wait for dealloc operation to complete
            _wait(500);
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == __TC_NUM_PTRS);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == __TC_NUM_PTRS);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);

            // Shuffle list of pointers again
            __ptr.shuffle();

            // Deallocate a subset of the pointers again; check for (expected) deallocation errors
            for (int i = 0; i < NUM_ERRS; i++) begin
                dealloc(__ptr[i]);

                // Should trigger deallocation error
                wait(err_dealloc);
 
                // Check that pointer corresponding to failed deallocation is reported correctly
                `FAIL_UNLESS_LOG(
                    err_ptr == __ptr[i],
                    $sformatf(
                        "Mismatch in deallocation error pointer. Exp: ptr[0x%x], Got: ptr[0x%x].",
                        __ptr[i],
                        err_ptr
                    )
                );
                
                // Latch current status flags
                reg_agent.update_flags();
                // Check that deallocation error flag is set
                `FAIL_UNLESS_LOG(
                    reg_agent.is_dealloc_err() == 1,
                    "Deallocation error status flag not set"
                );

            end
            reg_agent.get_active_cnt(cnt);
            `FAIL_UNLESS(cnt == 0);
            reg_agent.get_alloc_cnt(cnt);
            `FAIL_UNLESS(cnt == __TC_NUM_PTRS);
            reg_agent.get_dealloc_cnt(cnt);
            `FAIL_UNLESS(cnt == __TC_NUM_PTRS);
            reg_agent.get_dealloc_err_cnt(cnt);
            `FAIL_UNLESS(cnt == NUM_ERRS);

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

endmodule : state_ptr_bv_allocator_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific configuration in a way
//  that maintains SVUnit compatibility
`define STATE_PTR_BV_ALLOCATOR_UNIT_TEST(PTR_WID)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  state_ptr_bv_allocator_unit_test#(PTR_WID) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask

// (Distributed RAM) 8-bit pointer allocator
module state_ptr_bv_allocator_8b_unit_test;
`STATE_PTR_BV_ALLOCATOR_UNIT_TEST(8);
endmodule

// (Block RAM) 4096-entry, 12-bit pointer allocator
module state_ptr_bv_allocator_12b_unit_test;
`STATE_PTR_BV_ALLOCATOR_UNIT_TEST(12);
endmodule

// (Block RAM) 65536-entry, 16-bit pointer allocator
module state_ptr_bv_allocator_16b_unit_test;
`STATE_PTR_BV_ALLOCATOR_UNIT_TEST(16);
endmodule


