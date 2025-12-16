`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1ms

module mem_aggregate_base_unit_test #(
    parameter int ADDR_WID = 8,
    parameter int CONTROLLER_DATA_WID = 512,
    parameter int N = 2,
    parameter bit ASYNC = 0,
    parameter bit RESET_FSM = 1'b0
);
    import svunit_pkg::svunit_testcase;

    string async_str = ASYNC ? "async_" : "";
    string rst_str = RESET_FSM ? "rst_" : "";

    // Synthesize testcase name from parameters
    string name = $sformatf("mem_aggregate_%0db_d%0db_n%0d_%s%sut", ADDR_WID, CONTROLLER_DATA_WID, N, async_str, rst_str);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DEPTH = 2**ADDR_WID;
    localparam int PERIPHERAL_DATA_WID = CONTROLLER_DATA_WID / N;

    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: PERIPHERAL_DATA_WID,
        ASYNC: ASYNC,
        RESET_FSM: RESET_FSM,
        OPT_MODE: mem_pkg::OPT_MODE_DEFAULT
    };

    //===================================
    // Derived parameters
    //===================================

    //===================================
    // Typedefs
    //===================================
    typedef bit[ADDR_WID-1:0]            addr_t;
    typedef bit[CONTROLLER_DATA_WID-1:0] data_t;

    //===================================
    // DUT
    //===================================
    logic wr_clk;
    logic rd_clk;

    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(CONTROLLER_DATA_WID)) mem_wr_if                    (.clk(wr_clk));
    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(PERIPHERAL_DATA_WID)) mem_wr_if__to_peripheral [N] (.clk(wr_clk));

    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(CONTROLLER_DATA_WID)) mem_rd_if                    (.clk(rd_clk));
    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(PERIPHERAL_DATA_WID)) mem_rd_if__to_peripheral [N] (.clk(rd_clk));

    logic wr_req_oflow [N];
    logic wr_req_pending [N];
    logic wr_resp_oflow [N];
    logic wr_resp_pending [N];

    logic rd_req_oflow [N];
    logic rd_req_pending [N];
    logic rd_resp_oflow [N];
    logic rd_resp_pending [N];

    mem_wr_aggregate #(.N(N)) DUT__wr (
        .from_controller ( mem_wr_if ),
        .to_peripheral   ( mem_wr_if__to_peripheral ),
        .req_oflow       ( wr_req_oflow ),
        .req_pending     ( wr_req_pending ),
        .resp_oflow      ( wr_resp_oflow ),
        .resp_pending    ( wr_resp_pending )
    );

    mem_rd_aggregate #(.N(N)) DUT__rd (
        .from_controller ( mem_rd_if ),
        .to_peripheral   ( mem_rd_if__to_peripheral ),
        .req_oflow       ( rd_req_oflow ),
        .req_pending     ( rd_req_pending ),
        .resp_oflow      ( rd_resp_oflow ),
        .resp_pending    ( rd_resp_pending )
    );

    generate
        for (genvar i = 0; i < N; i++) begin : g__slice
            mem_ram_sdp #(
                .SPEC           ( SPEC ),
                .SIM__RAM_MODEL ( 1 )
            ) DUT (
                .mem_wr_if ( mem_wr_if__to_peripheral[i] ),
                .mem_rd_if ( mem_rd_if__to_peripheral[i] )
            );
        end : g__slice
    endgenerate

    //===================================
    // Testbench
    //===================================
    logic __rd_clk;
    std_reset_intf reset_if (.clk(wr_clk));

    // Assign reset interface
    assign mem_wr_if.rst = reset_if.reset;
    assign reset_if.ready = mem_wr_if.rdy;

    // Write clock (100MHz)
    `SVUNIT_CLK_GEN(wr_clk, 5ns);
    // Read clock (200MHz)
    `SVUNIT_CLK_GEN(__rd_clk, 2.5ns);

    generate
        if (ASYNC) assign rd_clk = __rd_clk;
        else       assign rd_clk = wr_clk;
    endgenerate

    assign mem_rd_if.rst = 1'b0;

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

        mem_wr_if.idle();
        mem_rd_if.idle();
        
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
        //   hard_reset
        //
        // Desc:
        //===================================
        `SVTEST(hard_reset)
        `SVTEST_END

        //===================================
        // Test:
        //
        // Desc:
        //===================================
        `SVTEST(write_read_single)
            addr_t addr = $urandom % DEPTH;
            data_t exp_data = $urandom;
            data_t got_data;
        
            // Write
            mem_wr_if.write(addr, exp_data);

            // Read
            mem_rd_if.read(addr, got_data);

            // Check
            `FAIL_UNLESS(got_data == exp_data);

        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : mem_aggregate_base_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific mem_ram_sdp configuration in a way
//  that maintains SVUnit compatibility
`define MEM_AGGREGATE_UNIT_TEST(ADDR_WID,DATA_WID,N,ASYNC,RESET_FSM)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  mem_aggregate_base_unit_test #(ADDR_WID,DATA_WID,N,ASYNC,RESET_FSM) test();\
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

// (Distributed RAM) 32-entry, 32-bit, 2-slice
module mem_aggregate_a5b_d32b_n2_unit_test;
`MEM_AGGREGATE_UNIT_TEST(5,32,2,0,0);
endmodule

// (Distributed RAM) 256-entry, 512-bit, 8-slice
module mem_aggregate_a8b_d512b_n8_unit_test;
`MEM_AGGREGATE_UNIT_TEST(8,512,8,0,0);
endmodule

// (Block RAM) 512-entry, 128-bit, 1-slice
module mem_aggregate_a9b_d128b_n1_unit_test;
`MEM_AGGREGATE_UNIT_TEST(9,128,1,0,0);
endmodule

// (Block RAM) 512-entry, 128-bit, 2-slice
module mem_aggregate_a9b_d128b_n2_unit_test;
`MEM_AGGREGATE_UNIT_TEST(9,128,2,0,0);
endmodule

// (Distributed RAM) 4096-entry, 32-bit, 4-slice
module mem_aggregate_a10b_d512b_n4_unit_test;
`MEM_AGGREGATE_UNIT_TEST(12,32,4,0,0);
endmodule


// (Distributed RAM) 32-entry, 32-bit, 2-slice (ASYNC)
module mem_aggregate_a5b_d32b_n2_async_unit_test;
`MEM_AGGREGATE_UNIT_TEST(5,32,2,1,0);
endmodule

// (Distributed RAM) 256-entry, 512-bit, 8-slice (ASYNC)
module mem_aggregate_a8b_d512b_n8_async_unit_test;
`MEM_AGGREGATE_UNIT_TEST(8,512,8,1,0);
endmodule

// (Block RAM) 512-entry, 128-bit, 1-slice (ASYNC)
module mem_aggregate_a9b_d128b_n1_async_unit_test;
`MEM_AGGREGATE_UNIT_TEST(9,128,1,1,0);
endmodule

// (Block RAM) 512-entry, 128-bit, 2-slice (ASYNC)
module mem_aggregate_a9b_d128b_n2_async_unit_test;
`MEM_AGGREGATE_UNIT_TEST(9,128,2,1,0);
endmodule

// (Distributed RAM) 4096-entry, 32-bit, 4-slice (ASYNC)
module mem_aggregate_a10b_d512b_n4_async_unit_test;
`MEM_AGGREGATE_UNIT_TEST(12,32,4,1,0);
endmodule

// (Block RAM) 512-entry, 128-bit, 2-slice (ASYNC, Reset FSM)
module mem_aggregate_a9b_d128b_n2_async_rst_unit_test;
`MEM_AGGREGATE_UNIT_TEST(9,128,2,1,1);
endmodule

