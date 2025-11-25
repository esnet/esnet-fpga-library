`include "svunit_defines.svh"

module axi3_from_mem_adapter_unit_test;

    import svunit_pkg::svunit_testcase;
    import axi3_pkg::*;

    string name = "axi3_from_mem_adapter_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam axsize_t AXI_SIZE = SIZE_32BYTES;
    localparam int      AXI_ADDR_WID = 33;

    localparam longint MEM_SIZE = 2**AXI_ADDR_WID;

    localparam int  DATA_BYTES = axi3_pkg::get_word_size(AXI_SIZE);
    localparam int  DATA_WID = DATA_BYTES * 8;

    localparam mem_pkg::access_t   ACCESS_TYPE = mem_pkg::ACCESS_READ_WRITE;
    localparam mem_pkg::mem_type_t MEM_TYPE = mem_pkg::MEM_TYPE_HBM;


    localparam int NUM_CHANNELS = 16;
    localparam int ACTIVE_CHANNEL = 0;

    localparam int  MEM_ADDR_WID = AXI_ADDR_WID - $clog2(DATA_BYTES);
    localparam type MEM_ADDR_T = bit[MEM_ADDR_WID-1:0];

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;
    logic init_done;

    axi4l_intf axil_if ();

    mem_intf    #(.ADDR_WID(MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_if (.clk(clk));
    mem_wr_intf #(.ADDR_WID(MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));
    mem_rd_intf #(.ADDR_WID(MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(clk));

    axi3_intf #(.DATA_BYTE_WID(DATA_BYTES), .ADDR_WID(AXI_ADDR_WID), .ID_WID(6)) axi3_if [NUM_CHANNELS] (.aclk(clk));
    axi3_intf #(.DATA_BYTE_WID(DATA_BYTES), .ADDR_WID(AXI_ADDR_WID), .ID_WID(6)) __axi3_if (.aclk(clk));

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

    axi3_from_mem_adapter #(
        .SIZE ( AXI_SIZE ),
        .BASE_ADDR ( 8'h100 )
    ) DUT (
        .axi3_if ( __axi3_if ),
        .*
    );

    axi3_pipe_slr i_axi3_pipe_slr (
        .srst,
        .from_controller (__axi3_if),
        .to_peripheral   (axi3_if[ACTIVE_CHANNEL])
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
                axi3_intf_controller_term i_axi3_intf_controller_term (.to_peripheral (axi3_if[g_ch]));
            end : g__inactive
        end : g__ch
    endgenerate
    

    // Agent
    mem_proxy_verif_pkg::mem_proxy_agent agent;
    axi4l_verif_pkg::axi4l_reg_agent reg_agent;

    // Reset
    std_reset_intf reset_if (.clk);

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
        agent = new("mem_proxy_agent", DATA_WID, reg_agent);
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
            longint size;
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
            agent.get_size(size);
            `FAIL_UNLESS_EQUAL(size, MEM_SIZE);
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
            MEM_ADDR_T addr;
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
            data_t exp_data [MEM_ADDR_T];
            do begin
                MEM_ADDR_T __addr;
                data_t     __exp_data;
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

        //===================================
        // Test:
        //   write_burst
        //
        // Desc:
        //   Write a burst of data.
        //===================================
        `SVTEST(write_burst)
            localparam int BURST_SIZE = 1024;
            byte exp_data [BURST_SIZE];
            byte got_data [];
            MEM_ADDR_T addr;
            // Randomize access
            void'(std::randomize(addr));
            void'(std::randomize(exp_data));
            // Write burst of random data
            agent.write(addr, exp_data, error, timeout);
            // Read and check
            agent.read(addr, BURST_SIZE, got_data, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            foreach (got_data[i]) begin
                `FAIL_UNLESS_LOG(
                    got_data[i] === exp_data[i],
                    $sformatf("Read data mismatch at byte %0d for value stored at 0x%0x. Exp: 0x%0x, Got: 0x%0x.", i, addr, exp_data[i], got_data[i])
                );
            end
        `SVTEST_END

    `SVUNIT_TESTS_END

    task reset();
        bit timeout;
        reset_if.pulse();
        reset_if.wait_ready(timeout, 0);
    endtask

endmodule : axi3_from_mem_adapter_unit_test
