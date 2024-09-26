`include "svunit_defines.svh"

module packet_enqueue_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;


    string name = "packet_enqueue_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  DATA_BYTE_WID = 64;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam type META_T = logic[31:0];
    localparam int  BUFFER_WORDS = 16384;
    localparam int  ADDR_WID = $clog2(BUFFER_WORDS);
    localparam int  MIN_PKT_SIZE = 40;
    localparam int  MAX_PKT_SIZE = 1500;

    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam type PTR_T  = logic[ADDR_WID  :0];


    typedef packet#(META_T) PACKET_T;
    typedef packet_descriptor#(ADDR_T,META_T) PACKET_DESCRIPTOR_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_T(META_T)) packet_if (.clk(clk));

    PTR_T head_ptr;
    PTR_T tail_ptr;

    packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) descriptor_if (.clk(clk));
    packet_event_intf event_if (.clk(clk));

    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));

    packet_enqueue #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .BUFFER_WORDS ( BUFFER_WORDS ),
        .META_T    ( META_T ),
        .IGNORE_RDY ( 1 ),
        .MIN_PKT_SIZE ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE )
    ) DUT (
        .*
    );

    //===================================
    // Testbench
    //===================================
    assign mem_wr_if.rdy = 1'b1;
    always @(posedge clk) begin
        if (mem_wr_if.req && mem_wr_if.en) mem_wr_if.ack <= 1'b1;
        else                               mem_wr_if.ack <= 1'b0;
    end

    std_verif_pkg::component_env #(
        PACKET_T,
        PACKET_DESCRIPTOR_T
    ) env;

    // Driver/monitor
    packet_intf_driver#(DATA_BYTE_WID,META_T) driver;
    packet_descriptor_monitor#(ADDR_T,META_T) monitor;

    // Model
    packet_enqueue_model#(DATA_BYTE_WID,ADDR_T,META_T) model;
    std_verif_pkg::event_scoreboard#(PACKET_DESCRIPTOR_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(packet_if.clk));
    assign srst = reset_if.reset;

    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        driver = new();
        driver.packet_vif = packet_if;

        monitor = new();
        monitor.packet_descriptor_vif = descriptor_if;

        model = new("model", MIN_PKT_SIZE, MAX_PKT_SIZE);
        scoreboard = new();

        env = new("env");
        env.reset_vif = reset_if;
        env.driver = driver;
        env.monitor = monitor;
        env.model = model;
        env.scoreboard = scoreboard;
        env.connect();

        env.set_debug_level(0);
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

        tail_ptr = 1'b0;

        // Issue reset
        env.reset_dut();

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

    META_T meta;
    string msg;
    int len;

    task one_packet(int id=0, int len=$urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE));
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
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            one_packet(0, len);
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(err_packet)
            packet_raw#(META_T) packet;
            int id = 0;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            void'(std::randomize(meta));
            packet = new($sformatf("pkt_%0d", id), len, meta, 1'b1);
            packet.randomize();
            env.inbox.put(packet);
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(short_packet)
            len = MIN_PKT_SIZE - 1;
            one_packet(0, len);
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(long_packet)
            len = MAX_PKT_SIZE + 1;
            one_packet(0, len);
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(overflow)
            int words;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            len = 209;
            words = $ceil(len * 1.0 / DATA_BYTE_WID);
            tail_ptr = BUFFER_WORDS + (words - 1);
            driver._wait(2);
            model.set_tail_ptr(tail_ptr);
            one_packet(0, len);
            #10us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END

        `SVTEST(packet_stream_good)
            packet_stream();
            #100us `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
        `SVTEST_END


        `SVTEST(one_packet_bad)
            packet_raw#(META_T) packet;
            packet_raw#(META_T) bad_packet;
            // Create 'expected' transaction
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            void'(std::randomize(meta));
            packet = new("pkt_0", len, meta);
            packet.randomize();
            env.model.inbox.put(packet);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_packet = packet.clone("pkt_0_bad");
            bad_packet.set_meta(packet.get_meta()+1);
            env.driver.inbox.put(bad_packet);
            driver._wait(1000);
            `FAIL_UNLESS_LOG(
                scoreboard.report(msg),
                "Passed unexpectedly."
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
