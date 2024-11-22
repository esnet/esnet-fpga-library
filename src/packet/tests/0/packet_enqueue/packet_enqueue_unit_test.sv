`include "svunit_defines.svh"

module packet_enqueue_unit_test #(
    parameter bit DROP_ERRORED = 1'b1
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    localparam string drop_errored_str = DROP_ERRORED ? "_err_drops" : "_no_err_drops";

    string name = $sformatf("packet_enqueue%s_ut", drop_errored_str);
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

    packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) wr_descriptor_if (.clk(clk));
    packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) rd_descriptor_if (.clk(clk));
    packet_event_intf event_if (.clk(clk));

    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));

    packet_enqueue #(
        .IGNORE_RDY ( 1 ),
        .DROP_ERRORED ( DROP_ERRORED ),
        .MIN_PKT_SIZE ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE )
    ) DUT (
        .*
    );

    //===================================
    // Testbench
    //===================================
    // Memory stand-in
    assign mem_wr_if.rdy = 1'b1;
    always @(posedge clk) begin
        if (mem_wr_if.req && mem_wr_if.en) mem_wr_if.ack <= 1'b1;
        else                               mem_wr_if.ack <= 1'b0;
    end

    // Environment
    std_verif_pkg::component_env #(
        PACKET_T,
        PACKET_DESCRIPTOR_T
    ) env;

    // Driver/monitor
    packet_intf_driver#(DATA_BYTE_WID,META_T) driver;
    packet_descriptor_monitor#(ADDR_T,META_T) monitor;

    packet_descriptor_driver#(ADDR_T,META_T) rd_completion_driver;

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
        monitor.packet_descriptor_vif = wr_descriptor_if;

        rd_completion_driver = new();
        rd_completion_driver.packet_descriptor_vif = rd_descriptor_if;

        model = new("model", MIN_PKT_SIZE, MAX_PKT_SIZE);
        scoreboard = new();

        env = new("env");
        env.reset_vif = reset_if;
        env.driver = driver;
        env.monitor = monitor;
        env.model = model;
        env.scoreboard = scoreboard;
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

    task one_packet(int id=0, int len=$urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE));
        packet_raw#(META_T) packet;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
        env.inbox.put(packet);
    endtask

    task packet_stream(input int NUM_PKTS);
       for (int i = 0; i < NUM_PKTS; i++) begin
           one_packet(i);
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(single_packet)
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            one_packet(0, len);
            #10us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), 1);
        `SVTEST_END

        `SVTEST(err_packet)
            packet_raw#(META_T) packet;
            int exp_transactions = DROP_ERRORED ? 0 : 1;
            int id = 0;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            void'(std::randomize(meta));
            packet = new($sformatf("pkt_%0d", id), len, meta, 1'b1);
            packet.randomize();
            env.inbox.put(packet);
            #10us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), exp_transactions);
        `SVTEST_END

        `SVTEST(short_packet)
            len = MIN_PKT_SIZE - 1;
            one_packet(0, len);
            #10us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), 0);
        `SVTEST_END

        `SVTEST(long_packet)
            len = MAX_PKT_SIZE + 1;
            one_packet(0, len);
            #10us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), 0);
        `SVTEST_END

        `SVTEST(overflow)
            packet_descriptor#(ADDR_T,META_T) rd_descriptor;
            int words;
            int rd_size;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            words = $ceil(len * 1.0 / DATA_BYTE_WID);
            rd_size = BUFFER_WORDS*DATA_BYTE_WID+(words-2)*DATA_BYTE_WID;
            while (rd_size > 0) begin
                if (rd_size > 2**16-1) begin
                    rd_descriptor = new(.size(2**16-1));
                    rd_completion_driver.send(rd_descriptor);
                    rd_size -= 2**16-1;
                end else begin
                    rd_descriptor = new(.size(rd_size));
                    rd_completion_driver.send(rd_descriptor);
                    rd_size = 0;
                end
            end
            tail_ptr = BUFFER_WORDS + (words - 1);
            model.set_tail_ptr(tail_ptr);
            one_packet(0, len);
            #10us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), 0);
        `SVTEST_END

        `SVTEST(packet_burst)
            localparam int NUM_PKTS = 100;
            packet_stream(NUM_PKTS);
            #100us `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg);
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), NUM_PKTS);
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
            repeat (1000) @(posedge clk);
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
//  Builds unit test for a specific parameterization
//  of the packet_enqueue module that maintains
//  SVUnit compatibility
`define PACKET_ENQUEUE_UNIT_TEST(DROP_ERRORED)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_enqueue_unit_test #(DROP_ERRORED) test();\
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


module packet_enqueue_err_drops_unit_test;
`PACKET_ENQUEUE_UNIT_TEST(0);
endmodule

module packet_enqueue_no_err_drops_unit_test;
`PACKET_ENQUEUE_UNIT_TEST(1);
endmodule

