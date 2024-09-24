`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1ms

module mem_ram_sp_unit_test #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit RESET_FSM = 1'b0,
    parameter bit RAM_MODEL = 1'b0,
    mem_pkg::opt_mode_t OPT_MODE = mem_pkg::OPT_MODE_TIMING
);
    import svunit_pkg::svunit_testcase;

    string rst_str = RESET_FSM ? "rst_" : "";
    string model_str = RAM_MODEL ? "model_" : "";

    // Synthesize testcase name from parameters
    string name = $sformatf("mem_ram_sp_a%0db_d%0db_%s%s%sut", ADDR_WID, DATA_WID, rst_str, model_str);

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DEPTH = 2**ADDR_WID;

    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: 0,
        RESET_FSM: RESET_FSM,
        OPT_MODE: OPT_MODE
    };

    localparam type ADDR_T = bit[ADDR_WID-1:0];
    localparam type DATA_T = bit[DATA_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic clk;

    mem_intf #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) mem_if (.clk(clk));

    mem_ram_sp #(
        .SPEC           ( SPEC ),
        .SIM__RAM_MODEL ( RAM_MODEL )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    std_reset_intf reset_if (.clk(clk));

    // Assign reset interface
    assign mem_if.rst = reset_if.reset;
    assign reset_if.ready = mem_if.rdy;

    // Clock (100MHz)
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

        mem_if.idle();
        
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
            ADDR_T addr;
            DATA_T exp_data;
            DATA_T got_data;
    
            // Randomize transaction
            void'(std::randomize(addr)); 
            void'(std::randomize(exp_data)); 

            // Write
            mem_if.write(addr, exp_data);

            // Read (and check)
            mem_if.read(addr, got_data);
            `FAIL_UNLESS_EQUAL(exp_data, got_data);

        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : mem_ram_sp_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific mem_ram_sp configuration in a way
//  that maintains SVUnit compatibility
`define MEM_RAM_SP_UNIT_TEST(ADDR_WID,DATA_WID,RESET_FSM,RAM_MODEL)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  mem_ram_sp_unit_test #(ADDR_WID,DATA_WID,RESET_FSM,RAM_MODEL) test();\
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
module mem_ram_sp_a8b_d32b_unit_test;
`MEM_RAM_SP_UNIT_TEST(8,32,0,0);
endmodule

// (Distributed RAM) 256-entry, 32-bit, reset FSM
module mem_ram_sp_a8b_d32b_rst_unit_test;
`MEM_RAM_SP_UNIT_TEST(8,32,1,0);
endmodule

// (Distributed RAM) 256-entry, 32-bit
module mem_ram_sp_a8b_d32b_model_unit_test;
`MEM_RAM_SP_UNIT_TEST(8,32,0,1);
endmodule

// (Block RAM) 1024-entry, 32-bit
module mem_ram_sp_a10b_d32b_unit_test;
`MEM_RAM_SP_UNIT_TEST(10,32,0,0);
endmodule

// (Block RAM) 1024-entry, 32-bit, reset FSM
module mem_ram_sp_a10b_d32b_rst_unit_test;
`MEM_RAM_SP_UNIT_TEST(10,32,1,0);
endmodule

// (Block RAM) 1024-entry, 32-bit, RAM model
module mem_ram_sp_a10b_d32b_model_unit_test;
`MEM_RAM_SP_UNIT_TEST(10,32,0,1);
endmodule


// (Ultra RAM) 4096-entry, 64-bit
module mem_ram_sp_a12b_d64b_unit_test;
`MEM_RAM_SP_UNIT_TEST(12,64,0,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit, reset FSM
module mem_ram_sp_a12b_d64b_rst_unit_test;
`MEM_RAM_SP_UNIT_TEST(12,64,1,0);
endmodule

// (Ultra RAM) 4096-entry, 64-bit, reset FSM, RAM model
module mem_ram_sp_a12b_d64b_rst_model_unit_test;
`MEM_RAM_SP_UNIT_TEST(12,64,1,1);
endmodule


