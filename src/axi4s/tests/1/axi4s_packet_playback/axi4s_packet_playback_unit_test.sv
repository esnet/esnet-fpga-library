`include "svunit_defines.svh"

module axi4s_packet_playback_unit_test;

    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import axi4s_verif_pkg::*;
    import packet_verif_pkg::*;

    string name = "axi4s_packet_playback_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 64;
    localparam int DATA_WID = DATA_BYTE_WID * 8;
    localparam int TID_WID = 8;
    localparam int TDEST_WID = 12;
    localparam int TUSER_WID = 32;

    localparam type TID_T   = bit[TID_WID-1:0];
    localparam type TDEST_T = bit[TDEST_WID-1:0];
    localparam type TUSER_T = bit[TUSER_WID-1:0];
    localparam type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};
    localparam int PACKET_MEM_SIZE = 16384;

    localparam type PACKET_T = packet#(META_T);
    localparam type AXI4S_TRANSACTION_T = axi4s_transaction#(TID_T,TDEST_T,TUSER_T);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic en;

    axi4l_intf axil_if ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) axis_if (.aclk(clk), .aresetn(!srst));

    axi4s_packet_playback #(.PACKET_MEM_SIZE(PACKET_MEM_SIZE)) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Register agent
    axi4l_reg_agent reg_agent;

    // Environment
    std_verif_pkg::component_env#(PACKET_T,AXI4S_TRANSACTION_T) env;

    // Driver
    packet_playback_driver#(META_T) driver;

    // Monitor
    axi4s_monitor#(DATA_BYTE_WID,TID_T,TDEST_T,TUSER_T) monitor;

    // Model
    class packet_to_axi4s_model extends std_verif_pkg::model#(PACKET_T,AXI4S_TRANSACTION_T);
        function new(string name="packet_to_axi4s_model");
            super.new(name);
        endfunction
        protected task _process(input PACKET_T transaction);
            META_T meta;
            AXI4S_TRANSACTION_T axis_transaction;
            meta = transaction.get_meta();
            axis_transaction = axi4s_transaction#(TID_T,TDEST_T,TUSER_T)::create_from_bytes(
                .data (transaction.to_bytes()),
                .tid  (meta.tid),
                .tdest(meta.tdest),
                .tuser(meta.tuser)
            );
            _enqueue(axis_transaction);
        endtask
    endclass : packet_to_axi4s_model

    packet_to_axi4s_model model;

    // Scoreboard
    std_verif_pkg::event_scoreboard#(AXI4S_TRANSACTION_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !srst;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        // AXI-L agent
        reg_agent = new("axil_reg_agent");
        reg_agent.axil_vif = axil_if;

        // Driver
        driver = new("packet_playback_driver", PACKET_MEM_SIZE, DATA_WID, reg_agent);

        // Monitor
        monitor = new();
        monitor.axis_vif = axis_if;

        // Model
        model = new();

        // Scoreboard
        scoreboard = new();

        // Environment
        env = new("env");
        env.driver = driver;
        env.monitor = monitor;
        env.model = model;
        env.scoreboard = scoreboard;
        env.reset_vif = reset_if;
        env.register_subcomponent(reg_agent);
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
    bit error;
    bit timeout;
    int got_int;

    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 1500));
        automatic packet_raw#(META_T) packet;
        META_T meta;
        packet = new($sformatf("pkt_%0d", id), len);
        packet.randomize();
        void'(std::randomize(meta));
        packet.set_meta(meta);
        env.inbox.put(packet);
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(info)
            // Check packet memory size
            driver.read_mem_size(got_int);
            `FAIL_UNLESS_EQUAL(got_int, PACKET_MEM_SIZE);

            // Check metadata width
            driver.read_meta_width(got_int);
            `FAIL_UNLESS_EQUAL(got_int, $bits(META_T));
        `SVTEST_END

        `SVTEST(nop)
            driver.nop(error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
        `SVTEST_END

        `SVTEST(single_packet)
            len = $urandom_range(64, 256);
            one_packet();
            #100us`FAIL_IF_LOG(scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), 1);
        `SVTEST_END
/*
        `SVTEST(packet_burst)
            localparam int BURST_SIZE = 20;
            int len=$urandom_range(64, 1500);
            packet_raw#(META_T) packet;
            META_T meta;
            packet = new("pkt_0", len);
            packet.randomize();
            void'(std::randomize(meta));
            packet.set_meta(meta);
            for (int i = 0; i < BURST_SIZE; i++ ) begin
                scoreboard.exp_inbox.put(packet);
            end
            driver.send_burst(packet, BURST_SIZE);
            #100us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), BURST_SIZE);
        `SVTEST_END
*/
        `SVTEST(packet_stream)
            localparam NUM_PKTS = 50;
            for (int i = 0; i < NUM_PKTS; i++) begin
                one_packet(i);
            end
            fork
                begin
                    fork
                        begin
                            #10ms;
                        end
                        begin
                            do
                                #10us;
                            while(scoreboard.got_processed() < NUM_PKTS);
                            #10us;
                        end
                    join_any
                    disable fork;
                end
            join
            `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), NUM_PKTS);
        `SVTEST_END

        `SVTEST(pcap)
            driver.send_from_pcap("../../axi4s_packet_playback/test.pcap");
            // TODO: Add checks to make sure this actually works
        `SVTEST_END

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
