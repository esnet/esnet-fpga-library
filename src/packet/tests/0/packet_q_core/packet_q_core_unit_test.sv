`include "svunit_defines.svh"

module packet_q_core_unit_test #(
    parameter int NUM_INPUT_IFS = 1,
    parameter int NUM_OUTPUT_IFS = 1
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = $sformatf("packet_q_core_%0din_%0dout_ut", NUM_INPUT_IFS, NUM_OUTPUT_IFS);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  DATA_IN_BYTE_WID = 64;
    localparam int  DATA_OUT_BYTE_WID = DATA_IN_BYTE_WID;
    localparam int  DATA_IN_WID = DATA_IN_BYTE_WID * 8;
    localparam int  DATA_OUT_WID = DATA_OUT_BYTE_WID * 8;

    localparam int  MEM_DATA_BYTE_WID = 32;
    localparam int  MEM_DATA_WID = MEM_DATA_BYTE_WID * 8;

    localparam int  NUM_MEM_WR_IFS_PER_INPUT  = DATA_IN_BYTE_WID  / MEM_DATA_BYTE_WID;
    localparam int  NUM_MEM_RD_IFS_PER_OUTPUT = DATA_OUT_BYTE_WID / MEM_DATA_BYTE_WID;
    localparam int  NUM_MEM_DATA_IFS = NUM_INPUT_IFS * NUM_MEM_WR_IFS_PER_INPUT;

    initial std_pkg::param_check(NUM_OUTPUT_IFS*NUM_MEM_RD_IFS_PER_OUTPUT, NUM_MEM_DATA_IFS, "NUM_MEM_RD_IFS");

    localparam int  BUFFER_SIZE = 2048;
    localparam int  BUFFER_WORDS = BUFFER_SIZE / MEM_DATA_BYTE_WID;
    localparam int  NUM_BUFFERS = 1024;
    localparam int  PTR_WID = $clog2(NUM_BUFFERS);
    localparam int  MEM_DEPTH = NUM_BUFFERS * BUFFER_WORDS;
    localparam int  ADDR_WID = $clog2(MEM_DEPTH);

    localparam int  MAX_PKT_SIZE = 9200;

    localparam int  PACKET_Q_CAPACITY = BUFFER_SIZE * NUM_BUFFERS;

    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam type META_T = logic[31:0];

    localparam int META_WID = $bits(META_T);

    typedef packet#(META_T) PACKET_T;

    localparam type DESC_T = alloc_pkg::alloc#(BUFFER_SIZE, PTR_WID, META_WID)::desc_t;
    localparam int  DESC_WID = $bits(DESC_T);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    packet_intf #(.DATA_BYTE_WID(DATA_IN_BYTE_WID), .META_WID(META_WID)) packet_in_if [NUM_INPUT_IFS]   (.clk);

    mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(PTR_WID))  desc_mem_wr_if (.clk);
    mem_wr_intf #(.DATA_WID(DATA_IN_WID),  .ADDR_WID(ADDR_WID)) mem_wr_if [NUM_INPUT_IFS] (.clk);
    mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) __mem_wr_if [NUM_MEM_DATA_IFS] (.clk);

    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_in_if  [NUM_INPUT_IFS] (.clk);
    packet_descriptor_intf #(.ADDR_WID(PTR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_out_if [NUM_OUTPUT_IFS] (.clk);

    mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(PTR_WID))  desc_mem_rd_if (.clk);
    mem_rd_intf #(.DATA_WID(DATA_OUT_WID), .ADDR_WID(ADDR_WID)) mem_rd_if [NUM_INPUT_IFS] (.clk);
    mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) __mem_rd_if [NUM_MEM_DATA_IFS] (.clk);

    packet_intf #(.DATA_BYTE_WID(DATA_OUT_BYTE_WID), .META_WID(META_WID)) packet_out_if [NUM_OUTPUT_IFS] (.clk);

    axi4l_intf axil_if ();

    logic mem_init_done;

    packet_q_core      #(
        .NUM_INPUT_IFS  ( NUM_INPUT_IFS ),
        .NUM_OUTPUT_IFS ( NUM_OUTPUT_IFS ),
        .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
        .NUM_BUFFERS    ( NUM_BUFFERS ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .MAX_RD_LATENCY ( 48 ),
        .MAX_BURST_LEN  ( 16 ),
        .N_ALLOC        ( 4 ),
        .N_GATHER       ( 4 ),
        .SIM__FAST_INIT ( 0 ),
        .SIM__RAM_MODEL ( 0 )
    ) DUT (.*);

    //===================================
    // Memory
    //===================================
    localparam int NUM_MEM_CHANNELS = NUM_MEM_DATA_IFS + 1;
    localparam int AXI_ADDR_WID = $clog2(PACKET_Q_CAPACITY + NUM_BUFFERS);
    axi3_intf #(.DATA_BYTE_WID(MEM_DATA_BYTE_WID), .ADDR_WID(AXI_ADDR_WID)) axi3_if [NUM_MEM_CHANNELS] (.aclk(clk));
    axi3_mem_bfm #(
        .CHANNELS ( NUM_MEM_CHANNELS),
        .WR_LATENCY ( 16 ),
        .RD_LATENCY ( 48 )
    ) i_axi3_mem_bfm (
        .srst,
        .axi3_if
    );

    // Per-input-port logic
    for (genvar g_if = 0; g_if < NUM_INPUT_IFS; g_if++) begin : g__input_if
        mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) __mem_wr_if__slice [NUM_MEM_WR_IFS_PER_INPUT] (.clk);

        // Distribute (wide) memory interfaces over multiple (narrow) interfaces (adapt 512-bit AXI-S interface to 256-bit AXI-3 HBM interface, for example)
        mem_wr_aggregate #(.N(NUM_MEM_WR_IFS_PER_INPUT)) i_mem_wr_aggregate (.from_controller(mem_wr_if[g_if]), .to_peripheral (__mem_wr_if__slice));

        // Connect memory interface in input slice to global interface pool
        for (genvar g_mem_if = 0; g_mem_if < NUM_MEM_WR_IFS_PER_INPUT; g_mem_if++) begin : g__mem_if
            mem_wr_intf_connector i_mem_wr_intf_connector (.from_controller(__mem_wr_if__slice[g_mem_if]), .to_peripheral(__mem_wr_if[g_if*NUM_MEM_WR_IFS_PER_INPUT + g_mem_if]));
        end : g__mem_if
    end : g__input_if

    // Per-output-port logic
    for (genvar g_if = 0; g_if < NUM_OUTPUT_IFS; g_if++) begin : g__output_if
        mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) __mem_rd_if__slice [NUM_MEM_RD_IFS_PER_OUTPUT] (.clk);

        // Distribute (wide) memory interfaces over multiple (narrow) interfaces (adapt 512-bit AXI-S interface to 256-bit AXI-3 HBM interface, for example)
        mem_rd_aggregate #(.N(NUM_MEM_RD_IFS_PER_OUTPUT)) i_mem_rd_aggregate (.from_controller(mem_rd_if[g_if]), .to_peripheral (__mem_rd_if__slice));

        // Connect memory interface in output slice to global interface pool
        for (genvar g_mem_if = 0; g_mem_if < NUM_MEM_RD_IFS_PER_OUTPUT; g_mem_if++) begin : g__mem_if
            mem_rd_intf_connector i_mem_rd_intf_connector (.from_controller(__mem_rd_if__slice[g_mem_if]), .to_peripheral(__mem_rd_if[g_if*NUM_MEM_RD_IFS_PER_OUTPUT + g_mem_if]));
        end : g__mem_if
    end : g__output_if

    // Convert memory interfaces to AXI-3
    for (genvar g_if = 0; g_if < NUM_MEM_DATA_IFS; g_if++) begin : g_mem_if
        axi3_from_mem_adapter #(
            .SIZE(axi3_pkg::SIZE_32BYTES),
            .BURST_SUPPORT ( 1 ),
            .WR_ID ( 2*g_if ),
            .RD_ID ( 2*g_if + 1)
        ) i_axi3_from_mem_adapter (
            .clk,
            .srst,
            .init_done (),
            .mem_wr_if ( __mem_wr_if [g_if] ),
            .mem_rd_if ( __mem_rd_if [g_if] ),
            .axi3_if   ( axi3_if[g_if] )
        );
    end
    
    axi3_from_mem_adapter #(
        .SIZE(axi3_pkg::SIZE_32BYTES),
        .BASE_ADDR ( PACKET_Q_CAPACITY ),
        .BURST_SUPPORT ( 0 ),
        .WR_ID ( NUM_MEM_DATA_IFS * 2 ),
        .RD_ID ( NUM_MEM_DATA_IFS * 2 )
    ) i_axi3_from_mem_adapter__desc (
        .clk,
        .srst,
        .init_done (),
        .mem_wr_if ( desc_mem_wr_if ),
        .mem_rd_if ( desc_mem_rd_if ),
        .axi3_if   ( axi3_if[NUM_MEM_DATA_IFS] )
    );

    generate
        for (genvar g_if = 0; g_if < NUM_INPUT_IFS; g_if++) begin : g__if
            packet_descriptor_fifo #(.DEPTH(512)) i_packet_descriptor_fifo (
                .from_tx      ( desc_in_if[g_if] ),
                .from_tx_srst ( srst ),
                .to_rx        ( desc_out_if[g_if] ),
                .to_rx_srst   ( srst )
            );
        end : g__if
    endgenerate

    assign mem_init_done = 1'b1;

    //===================================
    // Testbench
    //===================================
    packet_component_env #(META_T) env;

    packet_intf_driver#(DATA_IN_BYTE_WID, META_T) driver;
    packet_intf_monitor#(DATA_OUT_BYTE_WID, META_T) monitor;

    // Model
    std_verif_pkg::wire_model#(PACKET_T) model;
    std_verif_pkg::event_scoreboard#(PACKET_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign axil_if.aresetn = !reset_if.reset;
    assign reset_if.ready = !srst;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if (axil_if ));

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        // Driver
        driver = new();
        driver.packet_vif = packet_in_if[0];

        // Monitor
        monitor = new();
        monitor.packet_vif = packet_out_if[0];

        model = new();
        scoreboard = new();

        env = new("env", driver, monitor, model, scoreboard);
        env.reset_vif = reset_if;
        env.build();
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        monitor.set_stall_rate(0.0);
        driver.set_stall_rate(0.0);

        // Start environment
        env.run();
    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        // Stop environment
        env.stop();

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

    META_T meta;
    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 511));
        packet_raw#(META_T) packet;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
        env.inbox.put(packet);
    endtask

    task packet_stream();
       for (int i = 0; i < 100; i++) begin
           one_packet(i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(one_packet_good)
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(one_packet_bad)
            int bad_byte_idx;
            byte bad_byte_data;
            packet_raw#(META_T) pkt;
            packet#(META_T) bad_pkt;
            // Create 'expected' transaction
            pkt = new();
            pkt.randomize();
            env.model.inbox.put(pkt);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_pkt = pkt.dup("trans_0_bad");
            bad_byte_idx = $urandom % bad_pkt.size();
            bad_byte_data = 8'hFF ^ bad_pkt.get_byte(bad_byte_idx);
            bad_pkt.set_byte(bad_byte_idx, bad_byte_data);
            env.driver.inbox.put(bad_pkt);
            packet_in_if[0]._wait(1000);
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

        `SVTEST(one_packet_rx_stall)
            monitor.set_stall_rate(0.5);
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(one_packet_tx_stall)
            driver.set_stall_rate(0.5);
            one_packet();
            check(1, 10us);
        `SVTEST_END

       `SVTEST(one_packet_tx_rx_stall)
            monitor.set_stall_rate(0.5);
            driver.set_stall_rate(0.5);
            one_packet();
            check(1, 10us);
        `SVTEST_END

        `SVTEST(one_jumbo_packet)
            len = $urandom_range(2049, 9000);
            one_packet(.len(len));
            check(1, 10us);
        `SVTEST_END

        `SVTEST(packet_size_walk)
            int idx = 0;
            int offset = $urandom() % 64;
            monitor.set_stall_rate(0.1);
            driver.set_stall_rate(0.1);
            for (int len = 60; len <= 192; len++) begin
                one_packet(idx, len);
                idx++;
            end
            one_packet(idx, 256 + offset);
            idx++;
            one_packet(idx, 512 + offset);
            idx++;
            one_packet(idx, 1024 + offset);
            idx++;
            one_packet(idx, 1536 + offset);
            idx++;
            check(192-60+1+4, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_no_stall)
            packet_stream();
            check(100, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_rx_stall)
            monitor.set_stall_rate(0.1);
            packet_stream();
            check(100, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_tx_stall)
            driver.set_stall_rate(0.1);
            packet_stream();
            check(100, 100us);
        `SVTEST_END

        `SVTEST(packet_stream_tx_rx_stall)
            monitor.set_stall_rate(0.1);
            driver.set_stall_rate(0.1);
            packet_stream();
            check(100, 100us);
        `SVTEST_END

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

    task check(input int EXPECTED, input time TIMEOUT);
        fork
            begin
                string msg;
                #(TIMEOUT);
                `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg);
                $display($sformatf("%d", env.scoreboard.got_processed()));
                `FAIL_IF_LOG(1, "Timeout waiting for expected transactions.");
            end
            begin
                string msg;
                int processed;
                do
                    #100ns;
                while ( env.scoreboard.got_processed() != EXPECTED );
                `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg);
                `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), EXPECTED);
            end
        join_any
        disable fork;
    endtask

endmodule


// 'Boilerplate' unit test wrapper code
//  Builds unit test for a parameterized
//  packet_q_core instance that maintains
//  SVUnit compatibility
`define PACKET_Q_CORE_TEST(INPUT_IFS,OUTPUT_IFS)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_q_core_unit_test #(INPUT_IFS,OUTPUT_IFS) test();\
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


module packet_q_core_1in_1out_unit_test;
`PACKET_Q_CORE_TEST(1,1)
endmodule

module packet_q_core_2in_2out_unit_test;
`PACKET_Q_CORE_TEST(2,2)
endmodule
