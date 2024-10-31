`include "svunit_defines.svh"

module axi4s_packet_capture_unit_test;

    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import axi4s_verif_pkg::*;
    import packet_verif_pkg::*;

    string name = "axi4s_packet_capture_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 64;
    localparam int DATA_WID = DATA_BYTE_WID * 8;
    localparam type TID_T = bit[7:0];
    localparam type TDEST_T = bit[11:0];
    localparam type TUSER_T = bit[31:0];
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
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axis_if ();

    axi4s_packet_capture #(.PACKET_MEM_SIZE(PACKET_MEM_SIZE)) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Register agent
    axi4l_reg_agent reg_agent;

    // Environment
    std_verif_pkg::component_env#(AXI4S_TRANSACTION_T,PACKET_T) env;

    // Driver
    axi4s_driver#(DATA_BYTE_WID,TID_T,TDEST_T,TUSER_T) driver;

    // Monitor
    packet_capture_monitor#(META_T) monitor;

    // Model
    class axi4s_to_packet_model extends std_verif_pkg::model#(AXI4S_TRANSACTION_T,PACKET_T);
        function new(string name="axi4s_to_packet_model");
            super.new(name);
        endfunction
        protected task _process(input AXI4S_TRANSACTION_T transaction);
            META_T meta;
            packet_raw#(META_T) __packet;
            meta.tid = transaction.get_tid();
            meta.tdest = transaction.get_tdest();
            meta.tuser = transaction.get_tuser();
            __packet = packet_raw#(META_T)::create_from_bytes(
                .data (transaction.to_bytes()),
                .meta (meta),
                .err  (1'b0)
            );
            _enqueue(__packet);
        endtask
    endclass : axi4s_to_packet_model

    axi4s_to_packet_model model;

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

    assign axis_if.aclk = clk;
    assign axis_if.aresetn = !srst;

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        // AXI-L agent
        reg_agent = new("axil_reg_agent");
        reg_agent.axil_vif = axil_if;

        // Driver
        driver = new(.BIGENDIAN(1));
        driver.axis_vif = axis_if;

        // Monitor
        monitor = new("packet_capture_monitor", PACKET_MEM_SIZE, DATA_WID, reg_agent);

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
        env.connect();

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Reset environment
        env.reset();

        // Put interfaces in quiescent state
        env.idle();
        driver.idle();
        monitor.idle();

        // Issue reset
        env.reset_dut();
        reg_agent.reset();

        // Wait for memory initialization to complete
        monitor.enable();
        monitor.wait_ready();

        // Start environment
        env.start();

    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();

        // Stop environment
        env.stop();
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
        AXI4S_TRANSACTION_T transaction;
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;
        void'(std::randomize(tid));
        void'(std::randomize(tdest));
        void'(std::randomize(tuser));
        transaction = new($sformatf("trans_%0d", id), len, tid, tdest, tuser);
        transaction.randomize();
        env.inbox.put(transaction);
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(info)
            // Check packet memory size
            monitor.read_mem_size(got_int);
            `FAIL_UNLESS_EQUAL(got_int, PACKET_MEM_SIZE);

            // Check metadata width
            monitor.read_meta_width(got_int);
            `FAIL_UNLESS_EQUAL(got_int, $bits(META_T));
        `SVTEST_END

        `SVTEST(nop)
            monitor.nop(error, timeout);
            `FAIL_IF(error);
            `FAIL_IF(timeout);
        `SVTEST_END

        `SVTEST(single_packet)
            len = $urandom_range(64, 256);
            one_packet();
            `FAIL_IF(error);
            `FAIL_IF(timeout);
            fork
                begin
                    #1ms;
                end
                begin
                    do
                        #10us;
                    while(scoreboard.got_processed() < 1);
                    #10us;
                end
            join_any
            disable fork;
            `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), 1);
        `SVTEST_END

        `SVTEST(packet_stream)
            localparam NUM_PKTS = 50;
            for (int i = 0; i < NUM_PKTS; i++) begin
                one_packet(i);
            end
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
            `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), NUM_PKTS);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
