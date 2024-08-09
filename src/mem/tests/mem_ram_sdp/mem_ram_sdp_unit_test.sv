`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1ms

module mem_ram_sdp_unit_test #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit ASYNC = 0,
    parameter bit RESET_FSM = 1'b0,
    parameter bit RAM_MODEL = 1'b0,
    mem_pkg::opt_mode_t OPT_MODE = mem_pkg::OPT_MODE_TIMING
);
    import svunit_pkg::svunit_testcase;

    string rst_str = RESET_FSM ? "rst_" : "";
    string model_str = RAM_MODEL ? "model_" : "";

    // Synthesize testcase name from parameters
    string name = $sformatf("mem_ram_sdp_a%0db_d%0db_%s%sut", ADDR_WID, DATA_WID, rst_str, model_str);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DEPTH = 2**ADDR_WID;

    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: ASYNC,
        RESET_FSM: RESET_FSM,
        OPT_MODE: OPT_MODE
    };

    //===================================
    // Derived parameters
    //===================================

    //===================================
    // Typedefs
    //===================================
    typedef bit[ADDR_WID-1:0] addr_t;
    typedef bit[DATA_WID-1:0] data_t;

    //===================================
    // DUT
    //===================================
    logic wr_clk;
    logic rd_clk;

    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(wr_clk));
    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(rd_clk));

    mem_ram_sdp #(
        .SPEC           ( SPEC ),
        .SIM__RAM_MODEL ( RAM_MODEL )
    ) DUT (.*);

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

endmodule : mem_ram_sdp_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific mem_ram_sdp configuration in a way
//  that maintains SVUnit compatibility
`define MEM_RAM_SDP_SYNC_UNIT_TEST(ADDR_WID,DATA_WID,RESET_FSM,RAM_MODEL)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  mem_ram_sdp_unit_test #(ADDR_WID,DATA_WID,RESET_FSM,RAM_MODEL) test();\
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

// (Distributed RAM) 256-entry, 32-bit
module mem_ram_sdp_a8b_d32b_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(8,32,0,0);
endmodule

// (Distributed RAM) 256-entry, 32-bit, reset FSM
module mem_ram_sdp_a8b_d32b_rst_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(8,32,1,0);
endmodule

// (Block RAM) 1024-entry, 32-bit
module mem_ram_sdp_a10b_d32b_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(10,32,0,0);
endmodule

// (Block RAM) 1024-entry, 32-bit, reset FSM
module mem_ram_sdp_a10b_d32b_rst_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(10,32,1,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit
module mem_ram_sdp_a12b_d64b_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(12,64,0,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit, reset FSM
module mem_ram_sdp_a12b_d64b_rst_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(12,64,1,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit, reset FSM, RAM model
module mem_ram_sdp_a12b_d64b_rst_model_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(12,64,1,1);
endmodule



