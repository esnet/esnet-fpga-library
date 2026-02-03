`include "svunit_defines.svh"

module packet_q_manager_unit_test #(
    parameter int NUM_INPUT_IFS = 1,
    parameter int NUM_QS = 8
);
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = $sformatf("packet_q_manager_%0din_ut", NUM_INPUT_IFS);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  SEL_WID = NUM_INPUT_IFS > 1 ? $clog2(NUM_INPUT_IFS) : 1;

    localparam int  Q_SEL_WID = NUM_QS > 1 ? $clog2(NUM_QS) : 1;
    localparam type Q_SEL_T = logic[Q_SEL_WID-1:0];

    localparam int  Q_DEPTH = 4096;
    localparam int  PTR_WID = $clog2(Q_DEPTH);
    localparam int  MAX_PKT_SIZE = 16383;
    localparam int  PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    localparam type PTR_T = logic[PTR_WID-1:0];
    localparam type META_T = logic[31:0];

    localparam int  META_WID = $bits(META_T);

    localparam int  ADDR_WID = 28; // Packet address
    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam int  BUFFER_SIZE = 2048;

    localparam type DESC_T = alloc_pkg::alloc#(BUFFER_SIZE, ADDR_WID, META_WID)::desc_t;
    localparam int  DESC_WID = $bits(DESC_T);

    localparam int  MEM_DATA_BYTE_WID = 32;
    localparam int  MEM_DATA_WID = MEM_DATA_BYTE_WID * 8;
    localparam int  MEM_ADDR_WID = $clog2(Q_DEPTH * MEM_DATA_BYTE_WID);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    logic init_done;

    logic [Q_SEL_WID-1:0] desc_in_q [NUM_INPUT_IFS];
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_in_if  [NUM_INPUT_IFS] (.clk);

    logic                    enq_ack;
    logic                    enq_nack;
    logic [SEL_WID-1:0]      enq_src;
    logic [Q_SEL_WID-1:0]    enq_q;
    logic [PKT_SIZE_WID-1:0] enq_size;

    logic                    deq_req;
    logic                    deq_rdy;
    logic [Q_SEL_WID-1:0]    deq_q;
    logic                    deq_ack;
    logic                    deq_nack;
    logic [SEL_WID-1:0]      deq_src;
    logic [PKT_SIZE_WID-1:0] deq_size;

    logic [Q_SEL_WID-1:0] desc_out_q;
    packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) desc_out_if (.clk);

    logic mem_init_done;
    mem_wr_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(PTR_WID)) q_mem_wr_if (.clk);
    mem_rd_intf #(.DATA_WID(MEM_DATA_WID), .ADDR_WID(PTR_WID)) q_mem_rd_if (.clk);

    axi4l_intf axil_if ();

    packet_q_manager      #(
        .NUM_INPUT_IFS     ( NUM_INPUT_IFS ),
        .NUM_QS            ( NUM_QS ),
        .Q_DEPTH           ( Q_DEPTH ),
        .MAX_PKT_SIZE      ( MAX_PKT_SIZE ),
        .NUM_TRANSACTIONS  ( 8 )
    ) DUT (.*);

    //===================================
    // Memory
    //===================================
    axi3_intf #(.DATA_BYTE_WID(MEM_DATA_BYTE_WID), .ADDR_WID(MEM_ADDR_WID)) axi3_if [1]  (.aclk(clk));
    axi3_mem_bfm #(
        .CHANNELS ( 1 ),
        .WR_LATENCY ( 16 ),
        .RD_LATENCY ( 48 )
    ) i_axi3_mem_bfm (
        .srst,
        .axi3_if
    );
    
    axi3_from_mem_adapter #(
        .SIZE(axi3_pkg::SIZE_32BYTES),
        .BASE_ADDR ( 0 ),
        .BURST_SUPPORT ( 0 ),
        .WR_ID ( 0 ),
        .RD_ID ( 0 )
    ) i_axi3_from_mem_adapter__desc (
        .clk,
        .srst,
        .init_done (),
        .mem_wr_if ( q_mem_wr_if ),
        .mem_rd_if ( q_mem_rd_if ),
        .axi3_if   ( axi3_if[0] ),
        .wr_data_oflow ( )
    );

    assign mem_init_done = 1'b1;

    //===================================
    // Testbench
    //===================================
    std_verif_pkg::basic_env env;

    typedef packet_descriptor#(ADDR_T,META_T) PACKET_DESCRIPTOR_T;

    packet_descriptor_intf_driver#(ADDR_T, META_T) driver;
    packet_descriptor_intf_monitor#(ADDR_T, META_T) monitor;

    // Reset
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign axil_if.aresetn = !reset_if.reset;
    assign reset_if.ready = init_done;

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
        driver.packet_descriptor_vif = desc_in_if[0];

        // Monitor
        monitor = new();
        monitor.packet_descriptor_vif = desc_out_if;

        env = new("env");
        env.reset_vif = reset_if;
        env.build();
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        driver.idle();
        monitor.idle();
        deq_req = 1'b0;

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
    PACKET_DESCRIPTOR_T desc_in;
    PACKET_DESCRIPTOR_T desc_out;
    ADDR_T addr;
    META_T meta;
    logic [Q_SEL_WID-1:0] q;
    bit match;
    string msg;
    int len;
/*
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
*/
    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(enq_deq_one_packet)
            bit deq_ok;
            int deq_size;
            desc_in = new();
            desc_in.randomize();
            q = $urandom % NUM_QS;
            desc_in_q[0] = q;
            driver.send(desc_in);
            wait(enq_ack || enq_nack);
            `FAIL_UNLESS(enq_ack);
            `FAIL_IF(enq_nack);
            `FAIL_UNLESS_EQUAL(enq_src, 0);
            `FAIL_UNLESS_EQUAL(enq_q, q);
            `FAIL_UNLESS_EQUAL(enq_size, desc_in.size);
            // Dequeue
            dequeue(q,deq_ok,deq_size);
            `FAIL_UNLESS(deq_ok);
            `FAIL_UNLESS_EQUAL(deq_src, 0);
            `FAIL_UNLESS_EQUAL(deq_size,desc_in.size);
            monitor.receive(desc_out);
            match = desc_out.compare(desc_in, msg);
            `FAIL_UNLESS_LOG(match, msg);
        `SVTEST_END

        `SVTEST(deq_uflow)
            bit deq_ok;
            int deq_size;
            desc_in = new();
            desc_in.randomize();
            q = $urandom % NUM_QS;
            desc_in_q[0] = q;
            driver.send(desc_in);
            wait(enq_ack || enq_nack);
            `FAIL_UNLESS(enq_ack);
            `FAIL_IF(enq_nack);
            `FAIL_UNLESS_EQUAL(enq_src, 0);
            `FAIL_UNLESS_EQUAL(enq_q, q);
            `FAIL_UNLESS_EQUAL(enq_size, desc_in.size);
            // Dequeue
            dequeue(q,deq_ok,deq_size);
            `FAIL_UNLESS(deq_ok);
            `FAIL_UNLESS_EQUAL(deq_src, 0);
            `FAIL_UNLESS_EQUAL(deq_size,desc_in.size);
            monitor.receive(desc_out);
            match = desc_out.compare(desc_in, msg);
            `FAIL_UNLESS_LOG(match, msg);

            // Dequeue again (no packet available, so should return nack)
            dequeue(q,deq_ok,deq_size);
            `FAIL_IF(deq_ok);
        `SVTEST_END
/*
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
*/
    `SVUNIT_TESTS_END

    task dequeue_req(input Q_SEL_T q_sel);
        deq_req <= 1'b1;
        deq_q <= q_sel;
        do @(posedge clk);
        while (!deq_rdy);
        deq_req <= 1'b0;
    endtask

    task dequeue_resp(output bit ok, output int size);
        do @(posedge clk);
        while (!(deq_ack || deq_nack));
        if (deq_nack) ok = 1'b0;
        else          ok = 1'b1;
        size = deq_size;
    endtask

    task dequeue(input Q_SEL_T q_sel, output bit ok, output int size);
        dequeue_req(q_sel);
        dequeue_resp(ok, size);
    endtask
/*
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
*/
endmodule : packet_q_manager_unit_test


// 'Boilerplate' unit test wrapper code
//  Builds unit test for a parameterized
//  packet_q_manager instance that maintains
//  SVUnit compatibility
`define PACKET_Q_MANAGER_TEST(INPUT_IFS,NUM_QS)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_q_manager_unit_test #(INPUT_IFS,NUM_QS) test();\
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


module packet_q_manager_1in_8q_unit_test;
`PACKET_Q_MANAGER_TEST(1,8)
endmodule

module packet_q_manager_2in_16q_unit_test;
`PACKET_Q_MANAGER_TEST(2,16)
endmodule
