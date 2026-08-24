`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 5ms

module sar_packet_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;
    import sar_verif_pkg::*;

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

    localparam int BUF_ID_WID      = $clog2(NUM_FRAME_BUFFERS);
    localparam int OFFSET_WID      = $clog2(MAX_FRAME_SIZE);
    localparam int FRAME_SIZE_WID  = $clog2(MAX_FRAME_SIZE + 1);
    localparam int PKT_SIZE_WID    = $clog2(MAX_PKT_SIZE+1);
    localparam int ADDR_WID        = $clog2(NUM_FRAME_BUFFERS * MAX_FRAME_SIZE / DATA_BYTE_WID);
    localparam int SEG_META_WID    = BUF_ID_WID + OFFSET_WID + 1 + META_WID;

    localparam type BUF_ID_T   = logic [BUF_ID_WID-1:0];
    localparam type OFFSET_T   = logic [OFFSET_WID-1:0];
    localparam type SEG_META_T = logic [SEG_META_WID-1:0];

    // Default segment length for shared testcases
    localparam int SEG_LEN = MAX_PKT_SIZE;

    typedef sar_frame_transaction#(BUF_ID_T) FRAME_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic axil_aclk;
    logic axil_aresetn;

    logic init_done__reassembly;
    logic init_done__segmentation;

    // Sideband signals for reassembly DUT input (driven by sar_segment_to_packet)
    logic [BUF_ID_WID-1:0] packet_buf_id_in;
    logic [OFFSET_WID-1:0] packet_offset_in;
    logic                  packet_last_in;

    // Sideband signals from segmentation DUT output (captured by sar_segment_from_packet)
    logic [BUF_ID_WID-1:0]   packet_buf_id_out;
    logic [OFFSET_WID-1:0]   packet_offset_out;
    logic [PKT_SIZE_WID-1:0] packet_size_out;
    logic                    packet_last_out;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_in_if  (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_out_if (.clk);

    // Wide-meta interfaces used by segment driver and monitor
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(SEG_META_WID)) seg_tx_if (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(SEG_META_WID)) seg_rx_if (.clk);

    axi4l_intf axil_if__reassembly ();
    axi4l_intf axil_if__segmentation ();

    logic ms_tick;

    logic                      frame_ready;
    logic                      frame_valid;
    logic [BUF_ID_WID-1:0]     frame_buf_id;
    logic [FRAME_SIZE_WID-1:0] frame_len;

    mem_wr_intf #(.DATA_WID(DATA_BYTE_WID*8), .ADDR_WID(ADDR_WID)) mem_wr_if (.clk);
    mem_rd_intf #(.DATA_WID(DATA_BYTE_WID*8), .ADDR_WID(ADDR_WID)) mem_rd_if (.clk);
    logic mem_init_done;

    // Shim: seg_tx_if (wide meta) → packet_in_if (narrow meta) + sideband
    sar_segment_to_packet #(
        .BUF_ID_WID   ( BUF_ID_WID ),
        .OFFSET_WID   ( OFFSET_WID ),
        .PKT_META_WID ( META_WID   )
    ) i_seg_to_pkt (
        .seg_if        ( seg_tx_if      ),
        .pkt_if        ( packet_in_if   ),
        .packet_buf_id ( packet_buf_id_in ),
        .packet_offset ( packet_offset_in ),
        .packet_last   ( packet_last_in   )
    );

    // Shim: packet_out_if (narrow meta) + sideband → seg_rx_if (wide meta)
    // clk/srst needed to latch sideband on first word (DUT may update before eop)
    sar_segment_from_packet #(
        .BUF_ID_WID   ( BUF_ID_WID ),
        .OFFSET_WID   ( OFFSET_WID ),
        .PKT_META_WID ( META_WID   )
    ) i_pkt_from_seg (
        .clk,
        .srst,
        .pkt_if        ( packet_out_if    ),
        .packet_buf_id ( packet_buf_id_out ),
        .packet_offset ( packet_offset_out ),
        .packet_last   ( packet_last_out   ),
        .seg_if        ( seg_rx_if         )
    );

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
    // AXI-L register agents
    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent__segmentation;
    sar_segmentation_reg_agent       seg_reg_agent;

    // Transport layer (concrete packet interface drivers)
    packet_intf_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) seg_pkt_driver;
    packet_intf_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(SEG_META_T)) seg_pkt_monitor;

    // Frame-level environment
    sar_component_env #(BUF_ID_T, OFFSET_T, META_T) env;
    sar_model         #(BUF_ID_T)                   model;
    std_verif_pkg::event_scoreboard #(FRAME_T)       scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done__segmentation && init_done__reassembly;
    assign axil_aresetn = !srst;

    assign axil_if__reassembly.aresetn  = axil_aresetn;
    assign axil_if__segmentation.aresetn = axil_aresetn;

    // Assign clock (333 MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125 MHz)
    `SVUNIT_CLK_GEN(axil_aclk, 4ns);

    assign axil_if__reassembly.aclk  = axil_aclk;
    assign axil_if__segmentation.aclk = axil_aclk;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axil_reg_agent__segmentation = new("axil_reg_agent__segmentation");
        axil_reg_agent__segmentation.axil_vif = axil_if__segmentation;

        // Segmentation regs are at 0x1000 within sar_packet_segmentation's AXI-L space
        seg_reg_agent = new("seg_reg_agent", axil_reg_agent__segmentation, 'h1000);

        seg_pkt_driver = new("seg_pkt_driver");
        seg_pkt_driver.packet_vif = seg_tx_if;

        seg_pkt_monitor = new("seg_pkt_monitor");
        seg_pkt_monitor.packet_vif = seg_rx_if;

        model      = new("sar_model");
        scoreboard = new("scoreboard");

        env = new("sar_component_env");
        env.reset_vif = reset_if;
        env.model = model;
        env.scoreboard = scoreboard;
        env.driver.pkt_driver  = seg_pkt_driver;
        env.monitor.pkt_monitor = seg_pkt_monitor;
        env.build();
    endfunction

    //===================================
    // Setup
    //===================================
    task setup();
        svunit_ut.setup();

        ms_tick = 0;

        // Pulses reset, waits for init_done__segmentation && init_done__reassembly,
        // then starts all subcomponents.
        env.run();

        // Configure segmentation DUT: set cfg_seg_len = MAX_PKT_SIZE so each output
        // frame produces exactly one segment, matching the sequencer's seg_len.
        // env.run() already guarantees init_done__segmentation=1 (READY state).
        begin
            sar_segmentation_reg_pkg::reg__config_t cfg;
            cfg.seg_len = MAX_PKT_SIZE;
            seg_reg_agent.write__config(cfg);
        end

        @(posedge clk);
    endtask

    //===================================
    // Teardown
    //===================================
    task teardown();
        env.stop();
        svunit_ut.teardown();
    endtask

    //===================================
    // Helpers
    //===================================
    task fill_frame(input FRAME_T frame);
        for (int i = 0; i < frame.data.size(); i++)
            frame.data[i] = byte'(i % 256);
    endtask

    task check(input int EXPECTED, input time TIMEOUT=500us);
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
                do
                    #100ns;
                while ( env.scoreboard.got_processed() != EXPECTED );
                `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg);
                `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), EXPECTED);
            end
        join_any
        disable fork;
    endtask

    `SVUNIT_TESTS_BEGIN

    //===================================
    // Test: reset
    // Verifies DUT comes out of reset cleanly (sar_packet only).
    //===================================
    `SVTEST(reset)
    `SVTEST_END

    `include "../common/sar_common_tests.svh"

    `SVUNIT_TESTS_END

endmodule : sar_packet_unit_test
