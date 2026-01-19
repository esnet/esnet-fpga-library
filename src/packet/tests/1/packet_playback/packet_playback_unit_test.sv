`include "svunit_defines.svh"

module packet_playback_unit_test;

    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import packet_verif_pkg::*;

    string name = "packet_playback_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 64;
    localparam int DATA_WID = DATA_BYTE_WID * 8;
    localparam type META_T = logic[31:0];
    localparam int PACKET_MEM_SIZE = 16384;

    localparam int META_WID = $bits(META_T);

    typedef packet#(META_T) PACKET_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic en;

    axi4l_intf axil_if ();
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_if (.clk);

    packet_playback #(
        .PACKET_MEM_SIZE ( PACKET_MEM_SIZE ),
        .SIM__FAST_INIT  ( 0 ),
        .SIM__RAM_MODEL  ( 0 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Register agent
    axi4l_reg_agent reg_agent;

    // Environment
    packet_component_env #(META_T) env;

    // Driver
    packet_playback_driver#(META_T) driver;

    // Monitor
    packet_intf_monitor#(DATA_BYTE_WID,META_T) monitor;

    // Model
    std_verif_pkg::wire_model#(PACKET_T) model;

    // Scoreboard
    std_verif_pkg::event_scoreboard#(PACKET_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !srst;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    assign axil_if.aresetn = !srst;

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
        monitor.packet_vif = packet_if;

        // Model
        model = new();

        // Scoreboard
        scoreboard = new();

        // Environment
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

        monitor.set_stall_rate(0.2);
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
    bit error;
    bit timeout;
    int got_int;

    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(64, 1500));
        packet_raw#(META_T) packet;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
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

        `SVTEST(packet_burst)
            packet_raw#(META_T) packet;
            localparam int BURST_SIZE = 20;
            int len=$urandom_range(64, 1500);
            META_T meta;
            void'(std::randomize(meta));
            packet = new("pkt_0", len, meta);
            packet.randomize();
            for (int i = 0; i < BURST_SIZE; i++ ) begin
                scoreboard.exp_inbox.put(packet);
            end
            driver.send_burst(packet, BURST_SIZE, error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            #100us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), BURST_SIZE);
        `SVTEST_END

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
            driver.send_from_pcap("../../packet_playback/test.pcap");
            // TODO: Add checks to make sure this actually works
        `SVTEST_END

        `SVTEST(finalize)
            env.finalize();
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
