`include "svunit_defines.svh"

module mem_proxy_unit_test;

    import svunit_pkg::svunit_testcase;
    import mem_pkg::*;
    import mem_proxy_verif_pkg::*;

    string name = "mem_proxy_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type ADDR_T = logic[7:0];
    localparam type DATA_T = logic[511:0];
    localparam access_t   ACCESS_TYPE = ACCESS_READ_WRITE;
    localparam mem_type_t MEM_TYPE = MEM_TYPE_SRAM;

    localparam int ADDR_WID = $bits(ADDR_T);
    localparam int DEPTH = 2**ADDR_WID;
    localparam int DATA_WID = $bits(DATA_T);
    localparam int DATA_BYTES = DATA_WID % 8 == 0 ? DATA_WID / 8 : DATA_WID / 8 + 1;
    localparam int SIZE = DEPTH * DATA_BYTES;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;
    logic init_done;

    axi4l_intf axil_if ();

    mem_intf #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) mem_if (.clk(clk));

    mem_proxy       #(
        .ACCESS_TYPE ( ACCESS_TYPE ),
        .MEM_TYPE    ( MEM_TYPE )
    ) DUT (
        .*
    );

    //===================================
    // Testbench
    //===================================
    // Memory (model)
    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: 0,
        RESET_FSM: 1,
        OPT_MODE: OPT_MODE_DEFAULT
    };

    mem_ram_sp         #(
        .SPEC           ( SPEC ),
        .SIM__FAST_INIT ( 0 ),
        .SIM__RAM_MODEL ( 1 )
    ) i_ram (
        .mem_if ( mem_if )
    );

    // Agent
    mem_proxy_agent agent;
    axi4l_verif_pkg::axi4l_reg_agent reg_agent;

    // Reset
    std_reset_intf reset_if (.clk(clk));

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    assign axil_if.aresetn = ~srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Build agent
        reg_agent = new();
        reg_agent.axil_vif = axil_if;
        agent = new("mem_proxy_agent", SIZE, DATA_WID, reg_agent);
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
    // Tests
    //===================================
    // (Common) variables
    bit error;
    bit timeout;

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
        `SVTEST(_reset)
        `SVTEST_END

        //===================================
        // Test:
        //   init
        //
        // Desc:
        //===================================
        `SVTEST(init)
            agent.wait_ready();
        `SVTEST_END

        //===================================
        // Test:
        //   info
        //
        // Desc:
        //   Read info register set and compare
        //   values against expected.
        //===================================
        `SVTEST(info)
            mem_pkg::mem_type_t _type;
            mem_pkg::access_t _access;
            int num;
            // Check memory type
            agent.get_type(_type);
            `FAIL_UNLESS_EQUAL(_type, MEM_TYPE);
            // Check access type
            agent.get_access(_access);
            `FAIL_UNLESS_EQUAL(_access, ACCESS_TYPE);
            // Check alignment
            agent.get_alignment(num);
            `FAIL_UNLESS_EQUAL(num, DATA_BYTES);
            // Check depth
            agent.get_depth(num);
            `FAIL_UNLESS_EQUAL(num, DEPTH);
            // Check size
            agent.get_size(num);
            `FAIL_UNLESS_EQUAL(num, SIZE);
            // Check min burst size
            agent.get_min_burst_size(num);
            `FAIL_UNLESS_EQUAL(num, DATA_BYTES);
            // Check max burst size
            agent.get_max_burst_size(num);
            `FAIL_UNLESS_EQUAL(num, DATA_BYTES*agent.get_max_burst_len());
        `SVTEST_END

        //===================================
        // Test:
        //   NOP
        //
        // Desc:
        //===================================
        `SVTEST(nop)
            agent.nop(error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
        `SVTEST_END

        //===================================
        // Test:
        //   write/read
        //
        // Desc:
        //===================================
        `SVTEST(write_read)
            ADDR_T addr;
            byte exp_data [64];
            byte got_data [];
            // Randomize access
            void'(std::randomize(addr));
            void'(std::randomize(exp_data));
            // Write
            agent.write(addr, exp_data, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Read
            agent.read(addr, 64, got_data, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Check
            foreach (got_data[i]) begin
                `FAIL_UNLESS_LOG(
                    got_data[i] === exp_data[i],
                    $sformatf("Read data mismatch at byte %0d. Exp: 0x%0x, Got: 0x%0x.", i, exp_data[i], got_data[i])
                );
            end
        `SVTEST_END

        //===================================
        // Test:
        //   write/read burst
        //
        // Desc:
        //===================================
        `SVTEST(write_read_burst)
            localparam int SIZE=4096;
            ADDR_T addr;
            byte exp_data [SIZE];
            byte got_data [];

            // Randomize access
            void'(std::randomize(exp_data));
            void'(std::randomize(addr));
            // Write
            agent.write(addr, exp_data, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Read
            agent.read(addr, SIZE, got_data, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Check
            foreach (got_data[i]) begin
                `FAIL_UNLESS_LOG(
                    got_data[i] === exp_data[i],
                    $sformatf("Read data mismatch at byte %0d. Exp: 0x%0x, Got: 0x%0x.", i, exp_data[i], got_data[i])
                );
            end
        `SVTEST_END


    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : mem_proxy_unit_test
