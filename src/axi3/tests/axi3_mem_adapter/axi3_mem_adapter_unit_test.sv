`include "svunit_defines.svh"

module axi3_mem_adapter_unit_test;

    import svunit_pkg::svunit_testcase;
    import mem_pkg::*;
    import axi3_pkg::*;
    import mem_proxy_verif_pkg::*;

    string name = "axi3_mem_adapter_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam type ADDR_T = logic[32:0];
    localparam int DATA_BYTE_WID = 32;
    localparam type DATA_T = logic[DATA_BYTE_WID*8-1:0];
    localparam ACCESS_TYPE = ACCESS_READ_WRITE;
    localparam MEM_TYPE = MEM_TYPE_HBM;

    localparam axsize_encoding_t AXI_SIZE = SIZE_32BYTES;

    localparam int NUM_CHANNELS = 16;
    localparam int ACTIVE_CHANNEL = 0;

    localparam int ADDR_WID = $bits(ADDR_T);
    localparam int SIZE = 2**ADDR_WID;
    localparam int DATA_WID = $bits(DATA_T);
    localparam int DATA_BYTES = DATA_BYTE_WID;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;
    logic init_done;

    axi4l_intf axil_if ();

    mem_intf    #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) mem_if (.clk(clk));
    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));
    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(clk));

    axi3_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .ADDR_WID(ADDR_WID), .ID_T(logic[5:0])) axi3_if [NUM_CHANNELS] ();

    mem_proxy       #(
        .ACCESS_TYPE ( ACCESS_TYPE ),
        .MEM_TYPE    ( MEM_TYPE )
    ) i_mem_proxy (
        .init_done (),
        .*
    );

    mem_sp_to_sdp_adapter i_mem_sp_to_sdp_adapter (
        .*
    );

    axi3_mem_adapter #(
        .SIZE ( AXI_SIZE )
    ) DUT (
        .axi3_if ( axi3_if[ACTIVE_CHANNEL] ),
        .*
    );

    //===================================
    // Testbench
    //===================================
    axi3_mem_bfm #(
        .CHANNELS ( NUM_CHANNELS ),
        .DEBUG    ( 0 )
    ) i_axi3_mem_bfm (
        .*
    );
    
    // Terminate unused AXI-3 channels
    generate
        for (genvar g_ch = 0; g_ch < NUM_CHANNELS; g_ch++) begin : g__ch
            if (g_ch == ACTIVE_CHANNEL) begin : g__active
                // No connection
            end : g__active
            else begin : g__inactive
                axi3_intf_controller_term i_axi3_intf_controller_term (.axi3_if (axi3_if[g_ch]));
            end : g__inactive
        end : g__ch
    endgenerate
    

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
        agent = new("mem_reg_agent", SIZE, DATA_WID, reg_agent);
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
            byte exp_data [DATA_BYTES];
            byte got_data [];
            // Randomize access
            void'(std::randomize(addr));
            void'(std::randomize(exp_data));
            // Write
            agent.write(addr, exp_data, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            // Read
            agent.read(addr, DATA_BYTES, got_data, error, timeout);
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
        //   writes_reads
        //
        // Desc:
        //   Write some large-ish number of random entries into the memory
        //   and then read them all back, checking that each transaction
        //   completes successfully, and with the expected data.
        //===================================
        `SVTEST(writes_reads)
            const int NUM_TRANSACTIONS = 500;
            typedef byte data_t [DATA_BYTES];
            data_t exp_data [ADDR_T];
            do begin
                ADDR_T __addr;
                data_t __exp_data;
                // Randomize access
                void'(std::randomize(__addr));
                void'(std::randomize(__exp_data));
                // Store address/data pair in expected value array
                exp_data[__addr] = __exp_data;
                // Write transaction to memory
                agent.write(__addr, __exp_data, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
            end while (exp_data.size() < NUM_TRANSACTIONS);

            foreach (exp_data[addr]) begin
                data_t got_data;
                agent.read(addr, DATA_BYTES, got_data, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                foreach (got_data[i]) begin
                    `FAIL_UNLESS_LOG(
                        got_data[i] === exp_data[addr][i],
                        $sformatf("Read data mismatch at byte %0d for value stored at 0x%0x. Exp: 0x%0x, Got: 0x%0x.", i, addr, exp_data[addr][i], got_data[i])
                    );
                end
            end
        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : axi3_mem_adapter_unit_test
