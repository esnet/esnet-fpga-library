`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1ms

module mem_ram_sdp_sync_unit_test #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit RESET_FSM = 1'b0,
    parameter bit RAM_MODEL = 1'b0
);
    import svunit_pkg::svunit_testcase;

    string rst_str = RESET_FSM ? "rst_" : "";
    string model_str = RAM_MODEL ? "model_" : "";

    // Synthesize testcase name from parameters
    string name = $sformatf("mem_ram_sdp_sync_a%0db_d%0db_%s%sut", ADDR_WID, DATA_WID, rst_str, model_str);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DEPTH = 2**ADDR_WID;

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

    logic   clk;
    logic   srst;

    logic   init_done;

    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(clk));

    mem_ram_sdp_sync #(
        .ADDR_WID  ( ADDR_WID ),
        .DATA_WID  ( DATA_WID ),
        .RESET_FSM ( RESET_FSM )
    ) DUT (.*);

    defparam DUT.i_mem_ram_sdp_core.SIM__RAM_MODEL = RAM_MODEL;

    //===================================
    // Testbench
    //===================================
    std_reset_intf reset_if (.clk(clk));

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

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

        wr_idle();
        rd_idle();
        
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
        // Desc:
        //===================================
        `SVTEST(reset)
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
            write(addr, exp_data);

            @(posedge clk);
        
            // Read
            read(addr, got_data);

            // Check
            `FAIL_UNLESS(got_data == exp_data);

        `SVTEST_END

    `SVUNIT_TESTS_END

    // Tasks
    task wr_idle();
        mem_wr_if.rst <= 1'b0;
        mem_wr_if.en  <= 1'b0;
        mem_wr_if.req <= 1'b0;
        @(posedge clk);
    endtask

    task rd_idle();
        mem_rd_if.rst <= 1'b0;
        mem_rd_if.en  <= 1'bx; // Unused
        mem_rd_if.req <= 1'b0;
        @(posedge clk);
    endtask

    task write(input addr_t addr, input data_t data);
        wait(mem_wr_if.rdy);
        mem_wr_if.en <= 1'b1;
        mem_wr_if.req <= 1'b1;
        mem_wr_if.addr <= addr;
        mem_wr_if.data <= data;
        @(posedge clk);
        mem_wr_if.en <= 1'b0;
        mem_wr_if.req <= 1'b0;
        mem_wr_if.addr <= 'x;
        mem_wr_if.data <= 'x;
        wait(mem_wr_if.ack);
    endtask

    task read(input addr_t addr, output data_t data);
        wait(mem_rd_if.rdy);
        mem_rd_if.req <= 1'b1;
        mem_rd_if.addr <= addr;
        @(posedge clk);
        mem_rd_if.req <= 1'b0;
        mem_rd_if.addr <= 'x;
        wait(mem_rd_if.ack);
        data = mem_rd_if.data;
    endtask

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : mem_ram_sdp_sync_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific mem_ram_sdp_sync configuration in a way
//  that maintains SVUnit compatibility
`define MEM_RAM_SDP_SYNC_UNIT_TEST(ADDR_WID,DATA_WID,RESET_FSM,RAM_MODEL)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  mem_ram_sdp_sync_unit_test #(ADDR_WID,DATA_WID,RESET_FSM,RAM_MODEL) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask

// (Distributed RAM) 256-entry, 32-bit
module mem_ram_sdp_sync_a8b_d32b_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(8,32,0,0);
endmodule

// (Distributed RAM) 256-entry, 32-bit, reset FSM
module mem_ram_sdp_sync_a8b_d32b_rst_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(8,32,1,0);
endmodule

// (Block RAM) 1024-entry, 32-bit
module mem_ram_sdp_sync_a10b_d32b_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(10,32,0,0);
endmodule

// (Block RAM) 1024-entry, 32-bit, reset FSM
module mem_ram_sdp_sync_a10b_d32b_rst_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(10,32,1,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit
module mem_ram_sdp_sync_a12b_d64b_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(12,64,0,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit, reset FSM
module mem_ram_sdp_sync_a12b_d64b_rst_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(12,64,1,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit, reset FSM, RAM model
module mem_ram_sdp_sync_a12b_d64b_rst_model_unit_test;
`MEM_RAM_SDP_SYNC_UNIT_TEST(12,64,1,1);
endmodule



