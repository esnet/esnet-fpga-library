`include "svunit_defines.svh"

module packet_write_unit_test #(
    parameter bit DROP_ERRORED = 1'b1
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    localparam string drop_errored_str = DROP_ERRORED ? "_err_drops" : "_no_err_drops";

    string name = $sformatf("packet_write%s_ut", drop_errored_str);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  DATA_BYTE_WID = 64;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam type META_T = bit[31:0];
    localparam int  BUFFER_WORDS = 16384;
    localparam int  ADDR_WID = $clog2(BUFFER_WORDS);
    localparam int  MIN_PKT_SIZE = 40;
    localparam int  MAX_PKT_SIZE = 1500;

    localparam int  META_WID = $bits(META_T);

    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam type PTR_T  = logic[ADDR_WID  :0];


    typedef packet#(META_T) PACKET_T;
    typedef packet_descriptor#(ADDR_T,META_T) PACKET_DESCRIPTOR_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_if (.clk, .srst);

    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID)) nxt_descriptor_if (.clk, .srst);
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID)) descriptor_if (.clk, .srst);
    packet_event_intf event_if (.clk(clk));

    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));
    logic mem_init_done;

    packet_write     #(
        .IGNORE_RDY   ( 1 ),
        .MIN_PKT_SIZE ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE ),
        .DROP_ERRORED ( DROP_ERRORED )
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

    assign mem_init_done = 1'b1;

    // Environment
    std_verif_pkg::component_env #(
        PACKET_T,
        PACKET_DESCRIPTOR_T
    ) env;

    // Driver/monitor
    packet_intf_driver#(DATA_BYTE_WID,META_T) driver;
    packet_descriptor_intf_driver#(ADDR_T,META_T) nxt_descriptor_driver;
    packet_descriptor_intf_monitor#(ADDR_T,META_T) monitor;

    // Model
    packet_write_model#(DATA_BYTE_WID,ADDR_T,META_T) model;
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

        nxt_descriptor_driver = new();
        nxt_descriptor_driver.packet_descriptor_vif = nxt_descriptor_if;

        monitor = new();
        monitor.packet_descriptor_vif = descriptor_if;

        model = new("model", MIN_PKT_SIZE, MAX_PKT_SIZE, DROP_ERRORED);
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

    ADDR_T addr;
    META_T meta;
    string msg;
    int len;

    task _one_packet(int id=0, int len=$urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE));
        packet_raw#(META_T) packet;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
        env.inbox.put(packet);
    endtask

    function automatic packet#(META_T) random_packet(input int id=0, input int len=$urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE));
        packet_raw#(META_T) packet;
        void'(std::randomize(meta));
        packet = new($sformatf("pkt_%0d", id), len, meta);
        packet.randomize();
        return packet;
    endfunction

    task send_packet(input packet#(META_T) packet, input ADDR_T addr);
        localparam int DESC_SIZE = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE : (MAX_PKT_SIZE / DATA_BYTE_WID + 1) * DATA_BYTE_WID;
        packet_descriptor#(ADDR_T,META_T) raw_descriptor;
        // Configure new (empty) descriptor
        raw_descriptor = new(.addr(addr), .size(DESC_SIZE));
        model.add_descriptor(raw_descriptor);
        // Send packet
        fork
            begin
                fork
                    nxt_descriptor_driver.send(raw_descriptor);
                    env.inbox.put(packet);
                join
            end
            begin
                #100us;
            end
        join_any
        disable fork;
    endtask

    task packet_stream(input int NUM_PKTS=100);
        addr = 0;
        for (int i = 0; i < NUM_PKTS; i++) begin
            packet#(META_T) packet;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            packet = random_packet(i, len);
            send_packet(packet, addr);
            addr += len;
       end
    endtask

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(single_packet)
            packet#(META_T) packet;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            // Create packet
            packet = random_packet(0, len);
            // Randomize address
            void'(std::randomize(addr));
            // Send single packet
            send_packet(packet, addr);
            // Check
            `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), 1);
        `SVTEST_END

        `SVTEST(err_packet)
            packet#(META_T) packet;
            int exp_transactions = DROP_ERRORED ? 0 : 1;
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            // Create packet, mark as errored
            packet = random_packet(0, len);
            packet.mark_as_errored();
            // Randomize address
            void'(std::randomize(addr));
            // Send single packet
            send_packet(packet, addr);
            // Check
            `FAIL_IF_LOG(scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), exp_transactions);
        `SVTEST_END

        `SVTEST(short_packet)
            packet#(META_T) packet;
            len = MIN_PKT_SIZE - 1;
            // Create packet
            packet = random_packet(0, len);
            // Randomize address
            void'(std::randomize(addr));
            // Send single packet
            send_packet(packet, addr);
            // Check
            `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), 0);
        `SVTEST_END

        `SVTEST(long_packet)
            packet#(META_T) packet;
            len = MAX_PKT_SIZE + 1;
            // Create packet
            packet = random_packet(0, len);
            // Randomize address
            void'(std::randomize(addr));
            // Send single packet
            send_packet(packet, addr);
            `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), 0);
        `SVTEST_END

        `SVTEST(overflow)
            packet#(META_T) packet;
            packet_descriptor#(ADDR_T,META_T) raw_descriptor;
            len = 500;
            // Create packet
            packet = random_packet(0, len);
            // Randomize address
            void'(std::randomize(addr));
            // Configure new (empty) descriptor
            // (descriptor size is insufficient to contain packet;
            //  should result in a failure to write accompanied by
            //  a pkt_status == STATUS_OFLOW)
            raw_descriptor = new(.addr(addr), .size(len-1));
            model.add_descriptor(raw_descriptor);
            // Send packet
            fork
                begin
                    fork
                        nxt_descriptor_driver.send(raw_descriptor);
                        env.inbox.put(packet);
                    join
                end
                begin
                    #100us;
                end
            join_any
            disable fork;
            `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_processed(), 0);
        `SVTEST_END

        `SVTEST(packet_burst)
            localparam int NUM_PKTS = 100;
            packet_stream(NUM_PKTS);
            `FAIL_IF_LOG( scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL(scoreboard.got_matched(), NUM_PKTS);
        `SVTEST_END

        `SVTEST(single_packet_bad)
            packet_raw#(META_T) exp_pkt;
            packet#(META_T) bad_pkt;
            packet_descriptor#(ADDR_T,META_T) raw_descriptor;
            // Create 'expected' transaction
            len = $urandom_range(MIN_PKT_SIZE, MAX_PKT_SIZE);
            void'(std::randomize(meta));
            exp_pkt = new("pkt_0", len, meta);
            exp_pkt.randomize();
            model.inbox.put(exp_pkt);
            // Configure new (empty) descriptor
            raw_descriptor = new(.addr(addr), .size(MAX_PKT_SIZE + DATA_BYTE_WID));
            model.add_descriptor(raw_descriptor);
            // Create 'actual' transaction and modify one byte of packet
            // so that it generates a mismatch wrt the expected packet
            bad_pkt = exp_pkt.dup("pkt_0_bad");
            bad_pkt.set_meta(exp_pkt.get_meta()+1);
            // Send (bad) packet
            fork
                begin
                    fork
                        nxt_descriptor_driver.send(raw_descriptor);
                        driver.inbox.put(bad_pkt);
                    join
                end
                begin
                    #100us;
                end
            join_any
            disable fork;
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
//  of the packet_write module that maintains
//  SVUnit compatibility
`define PACKET_WRITE_UNIT_TEST(DROP_ERRORED)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_write_unit_test #(DROP_ERRORED) test();\
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


module packet_write_err_drops_unit_test;
`PACKET_WRITE_UNIT_TEST(0);
endmodule

module packet_write_no_err_drops_unit_test;
`PACKET_WRITE_UNIT_TEST(1);
endmodule

