`include "svunit_defines.svh"

module sar_packet_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "sar_packet_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 64;
    localparam int META_WID = 1;
    localparam type META_T = bit[META_WID-1:0];

    localparam NUM_FRAME_BUFFERS = 128;
    localparam MAX_FRAME_SIZE = 65536;
    localparam MAX_PKT_SIZE = 16384;
    localparam TIMER_WID = 20;
    localparam MAX_FRAGMENTS = 1024;
    localparam BURST_SIZE = 8;

    localparam int BUF_ID_WID = $clog2(NUM_FRAME_BUFFERS);
    localparam int OFFSET_WID = $clog2(MAX_FRAME_SIZE);
    localparam int FRAME_SIZE_WID = $clog2(MAX_FRAME_SIZE + 1);
    localparam int PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1);
    localparam int ADDR_WID = $clog2(NUM_FRAME_BUFFERS * MAX_FRAME_SIZE / DATA_BYTE_WID);

    typedef packet#(META_T) PACKET_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic axil_aclk;
    logic axil_aresetn;
    
    logic init_done__reassembly;
    logic init_done__segmentation;

    logic [BUF_ID_WID-1:0] packet_buf_id_in;
    logic [OFFSET_WID-1:0] packet_offset_in;
    logic                  packet_last_in;
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),  .META_WID(META_WID)) packet_in_if (.clk);

    axi4l_intf axil_if__reassembly ();
    axi4l_intf axil_if__segmentation ();

    logic ms_tick;

    logic                      frame_ready;
    logic                      frame_valid;
    logic [BUF_ID_WID-1:0]     frame_buf_id;
    logic [FRAME_SIZE_WID-1:0] frame_len;

    logic [BUF_ID_WID-1:0]   packet_buf_id_out;
    logic [OFFSET_WID-1:0]   packet_offset_out;
    logic [PKT_SIZE_WID-1:0] packet_size_out;
    logic                    packet_last_out;
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID),  .META_WID(META_WID)) packet_out_if (.clk);

    mem_wr_intf #(.DATA_WID(DATA_BYTE_WID*8), .ADDR_WID(ADDR_WID)) mem_wr_if (.clk);
    mem_rd_intf #(.DATA_WID(DATA_BYTE_WID*8), .ADDR_WID(ADDR_WID)) mem_rd_if (.clk);
    logic mem_init_done;

    sar_packet_reassembly #(
        .NUM_FRAME_BUFFERS   ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE      ( MAX_FRAME_SIZE ),
        .MAX_PKT_SIZE        ( MAX_PKT_SIZE ),
        .TIMER_WID           ( TIMER_WID ),
        .MAX_FRAGMENTS       ( MAX_FRAGMENTS ),
        .BURST_SIZE          ( BURST_SIZE )
    ) DUT_reassembly (
        .clk,
        .srst,
        .init_done ( init_done__reassembly ),
        .packet_buf_id ( packet_buf_id_in ),
        .packet_offset ( packet_offset_in ),
        .packet_last   ( packet_last_in ),
        .packet_if     ( packet_in_if ),
        .axil_if       ( axil_if__reassembly ),
        .ms_tick,
        .frame_ready,
        .frame_valid,
        .frame_buf_id,
        .frame_len,
        .mem_wr_if,
        .mem_init_done
    );

    sar_packet_segmentation #(
        .NUM_FRAME_BUFFERS   ( NUM_FRAME_BUFFERS ),
        .MAX_FRAME_SIZE      ( MAX_FRAME_SIZE ),
        .MAX_PKT_SIZE        ( MAX_PKT_SIZE ),
        .MAX_RD_LATENCY      ( 64 )
    ) DUT_segmentation (
        .clk,
        .srst,
        .init_done ( init_done__segmentation ),
        .packet_buf_id ( packet_buf_id_out ),
        .packet_offset ( packet_offset_out ),
        .packet_size   ( packet_size_out ),
        .packet_last   ( packet_last_out ),
        .packet_if     ( packet_out_if ),
        .axil_if       ( axil_if__segmentation ),
        .frame_ready,
        .frame_valid,
        .frame_buf_id,
        .frame_len,
        .mem_rd_if,
        .mem_init_done
    );


    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_BYTE_WID*8,
        ASYNC: 1'b0,
        RESET_FSM: 1'b0,
        OPT_MODE: mem_pkg::OPT_MODE_DEFAULT
    };

    mem_ram_sdp #(
        .SPEC ( MEM_SPEC )
    ) ram (
        .mem_wr_if,
        .mem_rd_if
    );

    assign mem_init_done = 1'b1;

    //===================================
    // Testbench
    //===================================
    packet_component_env #(META_T) env;

    packet_intf_driver#(DATA_BYTE_WID, META_T) driver;
    packet_intf_monitor#(DATA_BYTE_WID, META_T) monitor;

    // Model
    std_verif_pkg::wire_model#(PACKET_T) model;
    std_verif_pkg::event_scoreboard#(PACKET_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !srst;
    assign axil_aresetn = !srst;

    assign axil_if__reassembly.aresetn = axil_aresetn;
    assign axil_if__segmentation.aresetn = axil_aresetn;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_aclk, 4ns);

    assign axil_if__reassembly.aclk = axil_aclk;
    assign axil_if__segmentation.aclk = axil_aclk;

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        // Driver
        driver = new();
        driver.packet_vif = packet_in_if;

        // Monitor
        monitor = new();
        monitor.packet_vif = packet_out_if;

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

        packet_buf_id_in = 0;
        packet_offset_in = 0;
        packet_last_in = 1;
        ms_tick = 0;

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

    task one_packet(int id=0, int len=512);
        packet_raw#(META_T) packet;
        packet = new($sformatf("pkt_%0d", id), len);
        packet.randomize();
        env.inbox.put(packet);
    endtask

    task packet_stream();
       for (int i = 0; i < 100; i++) begin
           one_packet(i);
           packet_buf_id_in++;
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(one_packet_good)
            one_packet();
            #50us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2)
            //env.monitor.set_tpause(2);
            one_packet();
            #50us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_twait_2)
            //env.driver.set_twait(2);
            one_packet();
            #50us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(one_packet_tpause_2_twait_2)
            //env.monitor.set_tpause(2);
            //env.driver.set_twait(2);
            one_packet();
            #50us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
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
            packet_in_if._wait(1000);
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : sar_packet_unit_test
