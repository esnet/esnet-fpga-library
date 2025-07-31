`include "svunit_defines.svh"

module packet_q_core_unit_test #(
    parameter int NUM_INPUT_IFS = 1,
    parameter int NUM_OUTPUT_IFS = 1
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "packet_q_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  DATA_IN_BYTE_WID = 64;
    localparam int  NUM_MEM_WR_IFS = 2;

    localparam int  DATA_OUT_BYTE_WID = 64;
    localparam int  NUM_MEM_RD_IFS = 2;

    localparam int  MEM_DATA_BYTE_WID = 32;
    localparam int  MEM_DATA_WID = MEM_DATA_BYTE_WID * 8;

    localparam int  BUFFER_SIZE = 2048;
    localparam int  BUFFER_WORDS = BUFFER_SIZE / MEM_DATA_BYTE_WID;
    localparam int  PTR_WID = 10;
    localparam int  NUM_PTRS = 2**PTR_WID;
    localparam int  MEM_DEPTH = NUM_PTRS * BUFFER_WORDS;
    localparam int  ADDR_WID = $clog2(MEM_DEPTH);

    localparam int  PACKET_Q_CAPACITY = BUFFER_SIZE * NUM_PTRS;

    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam type META_T = logic[31:0];

    typedef packet#(META_T) PACKET_T;

    localparam type DESC_T = alloc_pkg::alloc#(BUFFER_SIZE, PTR_T, META_T)::desc_t;
    localparam int  DESC_WID = $bits(DESC_T);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    packet_intf #(.DATA_BYTE_WID(DATA_IN_BYTE_WID), .META_T(META_T)) packet_in_if [NUM_INPUT_IFS]   (.clk(clk), .srst(srst));

    mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(PTR_WID))  desc_mem_wr_if (.clk);
    mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) mem_wr_if [NUM_MEM_WR_IFS] (.clk);

    packet_descriptor_intf #(.ADDR_T(PTR_T), .META_T(META_T)) desc_in_if  [NUM_INPUT_IFS] (.clk);
    packet_descriptor_intf #(.ADDR_T(PTR_T), .META_T(META_T)) desc_out_if [NUM_OUTPUT_IFS] (.clk);

    mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(PTR_WID))  desc_mem_rd_if (.clk);
    mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) mem_rd_if [NUM_MEM_RD_IFS] (.clk);

    packet_intf #(.DATA_BYTE_WID(DATA_OUT_BYTE_WID), .META_T(META_T)) packet_out_if [NUM_OUTPUT_IFS] (.clk(clk), .srst(srst));

    logic mem_init_done;

    packet_q_core      #(
        .NUM_INPUT_IFS  ( NUM_INPUT_IFS ),
        .NUM_OUTPUT_IFS ( NUM_OUTPUT_IFS ),
        .NUM_MEM_WR_IFS ( NUM_MEM_WR_IFS ),
        .NUM_MEM_RD_IFS ( NUM_MEM_RD_IFS ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .PTR_T          ( PTR_T ),
        .SIM__FAST_INIT ( 0 ),
        .SIM__RAM_MODEL ( 0 )
    ) DUT (.*);

    //===================================
    // Memory
    //===================================
    localparam int NUM_MEM_CHANNELS = NUM_MEM_WR_IFS + NUM_MEM_RD_IFS + 1;
    localparam int AXI_ADDR_WID = $clog2(PACKET_Q_CAPACITY + NUM_PTRS);
    axi3_intf #(.DATA_BYTE_WID(MEM_DATA_BYTE_WID), .ADDR_WID(AXI_ADDR_WID)) axi3_if [NUM_MEM_CHANNELS] (.aclk(clk));
    axi3_mem_bfm #(
        .CHANNELS ( NUM_MEM_CHANNELS)
    ) i_axi3_mem_bfm (
        .axi3_if
    );

    for (genvar g_if = 0; g_if < NUM_MEM_WR_IFS; g_if++) begin : g_mem_wr_if
        mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) mem_rd_if__unused (.clk);
        axi3_from_mem_adapter #(
            .SIZE(axi3_pkg::SIZE_32BYTES)
        ) i_axi3_from_mem_adapter (
            .clk,
            .srst,
            .init_done (),
            .mem_wr_if ( mem_wr_if [g_if] ),
            .mem_rd_if ( mem_rd_if__unused ),
            .axi3_if   ( axi3_if[g_if] )
        );
        mem_rd_intf_controller_term i_mem_rd_intf_controller_term (.to_peripheral(mem_rd_if__unused));
    end
    for (genvar g_if = 0; g_if < NUM_MEM_RD_IFS; g_if++) begin : g_mem_rd_if
        mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(ADDR_WID)) mem_wr_if__unused (.clk);
        axi3_from_mem_adapter #(
            .SIZE(axi3_pkg::SIZE_32BYTES)
        ) i_axi3_from_mem_adapter (
            .clk,
            .srst,
            .init_done (),
            .mem_wr_if ( mem_wr_if__unused ),
            .mem_rd_if ( mem_rd_if[g_if] ),
            .axi3_if   ( axi3_if[NUM_MEM_WR_IFS + g_if] )
        );
        mem_wr_intf_controller_term i_mem_wr_intf_controller_term (.to_peripheral(mem_wr_if__unused));
    end

    axi3_from_mem_adapter #(
        .SIZE(axi3_pkg::SIZE_32BYTES),
        .BASE_ADDR ( PACKET_Q_CAPACITY )
    ) i_axi3_from_mem_adapter__desc (
        .clk,
        .srst,
        .init_done (),
        .mem_wr_if ( desc_mem_wr_if ),
        .mem_rd_if ( desc_mem_rd_if ),
        .axi3_if   ( axi3_if[NUM_MEM_WR_IFS + NUM_MEM_RD_IFS] )
    );

    generate
        for (genvar g_if = 0; g_if < NUM_INPUT_IFS; g_if++) begin : g__if
            packet_descriptor_fifo i_packet_descriptor_fifo (
                .from_tx ( desc_in_if[g_if] ),
                .to_rx   ( desc_out_if[g_if] )
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
    assign reset_if.ready = !srst;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

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
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2)
            //env.monitor.set_tpause(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            //env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            one_packet();
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_jumbo_packet)
            len = $urandom_range(2049, 9000);
            one_packet(.len(len));
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2)
            //env.monitor.set_tpause(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_twait_2)
            //env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
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

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

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
