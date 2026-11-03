`include "svunit_defines.svh"

//
// packet_read testbench.
//
// Three configurations:
//   CHECK_CKSUM=0: descriptor cksum==0, no checking.
//   CHECK_CKSUM=1, IGNORE_RDY=0: cksum check in backpressure-capable path.
//   CHECK_CKSUM=1, IGNORE_RDY=1: cksum check in free-running output path.
//
module packet_read_tb #(
    parameter bit CHECK_CKSUM = 1'b0,
    parameter bit IGNORE_RDY  = 1'b0
);
    import svunit_pkg::svunit_testcase;
    import packet_pkg::*;

    localparam string cksum_str = CHECK_CKSUM ? "_check_cksum" : "";
    localparam string rdy_str   = IGNORE_RDY  ? "_ignore_rdy"  : "";

    string name = $sformatf("packet_read%s%s_ut", cksum_str, rdy_str);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int  DATA_BYTE_WID = 64;
    localparam int  DATA_WID      = DATA_BYTE_WID * 8;
    localparam type META_T        = bit [31:0];
    localparam int  META_WID      = $bits(META_T);
    localparam int  BUFFER_WORDS  = 1024;
    localparam int  ADDR_WID      = $clog2(BUFFER_WORDS);
    localparam int  MAX_PKT_SIZE  = 1500;
    localparam int  MTY_WID       = $clog2(DATA_BYTE_WID);

    localparam type ADDR_T = logic [ADDR_WID-1:0];

    typedef byte byte_array_t [];

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    packet_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .META_WID      ( META_WID )
    ) packet_if (.clk);

    packet_descriptor_intf #(
        .ADDR_WID     ( ADDR_WID ),
        .META_WID     ( META_WID ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE )
    ) descriptor_if (.clk);

    packet_event_intf event_if (.clk(clk));

    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk);

    size_t pkt_size;

    packet_read #(
        .IGNORE_RDY     ( IGNORE_RDY  ),
        .MAX_RD_LATENCY ( 8           ),
        .CHECK_CKSUM    ( CHECK_CKSUM )
    ) DUT (.*);

    //===================================
    // Memory (SDP RAM model with latency)
    //===================================
    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID  : ADDR_WID,
        DATA_WID  : DATA_WID,
        ASYNC     : 0,
        RESET_FSM : 0,
        OPT_MODE  : mem_pkg::OPT_MODE_TIMING
    };

    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk);

    mem_ram_sdp #(
        .SPEC           ( MEM_SPEC ),
        .SIM__FAST_INIT ( 1        ),
        .SIM__RAM_MODEL ( 1        )
    ) i_mem (
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

    initial begin
        mem_wr_if.rst = 1'b0;
        mem_wr_if.en  = 1'b1;
        mem_wr_if.req = 1'b0;
    end

    //===================================
    // Reset / clock
    //===================================
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    `SVUNIT_CLK_GEN(clk, 1.5ns);

    //===================================
    // Helpers
    //===================================

    // 16-bit one's complement checksum matching the RTL implementation.
    function automatic logic [15:0] reference_cksum(input byte_array_t data);
        logic [31:0] acc;
        logic [7:0]  hi, lo;
        acc = 0;
        for (int i = 0; i < data.size(); i += 2) begin
            hi = data[i];
            lo = (i + 1 < data.size()) ? data[i+1] : 8'h00;
            acc += {hi, lo};
        end
        acc = (acc[31:16] + acc[15:0]);
        acc = (acc[31:16] + acc[15:0]);
        reference_cksum = ~acc[15:0];
        if (reference_cksum == 16'h0000) reference_cksum = 16'hffff;
    endfunction

    // Preload bytes into the RAM at word address `base_addr`.
    task automatic preload_mem(input byte_array_t data, input ADDR_T base_addr);
        int num_words;
        logic [0:DATA_BYTE_WID-1][7:0] word;
        int idx;
        num_words = (data.size() + DATA_BYTE_WID - 1) / DATA_BYTE_WID;
        @(posedge clk);
        for (int w = 0; w < num_words; w++) begin
            word = '0;
            for (int b = 0; b < DATA_BYTE_WID; b++) begin
                idx = w * DATA_BYTE_WID + b;
                if (idx < data.size()) word[b] = data[idx];
            end
            mem_wr_if.req  <= 1'b1;
            mem_wr_if.addr <= base_addr + ADDR_T'(w);
            mem_wr_if.data <= word;
            @(posedge clk);
        end
        mem_wr_if.req <= 1'b0;
        @(posedge clk);
    endtask

    // Receive a full packet from packet_if, return bytes and EOP err flag.
    task automatic recv_packet(
            output byte_array_t rx_data,
            output bit          rx_err,
            output bit          timeout
        );
        byte     rx_q [$];
        bit      eop;
        int      cycles;
        int      valid;
        logic [0:DATA_BYTE_WID-1][7:0] word;
        eop     = 1'b0;
        cycles  = 0;
        timeout = 1'b0;
        rx_err  = 1'b0;
        if (!IGNORE_RDY) packet_if.cb_rx.rdy <= 1'b1;
        while (!eop) begin
            @(packet_if.cb_rx);
            if (packet_if.cb_rx.vld) begin
                word  = packet_if.cb_rx.data;
                valid = packet_if.cb_rx.eop ?
                        DATA_BYTE_WID - int'(packet_if.cb_rx.mty) :
                        DATA_BYTE_WID;
                for (int b = 0; b < valid; b++)
                    rx_q.push_back(byte'(word[b]));
                eop = packet_if.cb_rx.eop;
                if (eop) rx_err = packet_if.cb_rx.err;
            end
            cycles++;
            if (cycles > 20000) begin timeout = 1'b1; break; end
        end
        if (!IGNORE_RDY) packet_if.cb_rx.rdy <= 1'b0;
        rx_data = rx_q;
    endtask

    // Generate random byte array.
    function automatic byte_array_t rand_bytes(input int len);
        byte_array_t data = new[len];
        foreach (data[i]) data[i] = byte'($urandom_range(0, 255));
        return data;
    endfunction

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        descriptor_if.idle_tx();
        if (!IGNORE_RDY) packet_if.idle_rx();
        reset_if.pulse(8);
        reset_if._wait(8);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        // Basic: packet bytes come back intact.
        `SVTEST(single_packet)
            byte_array_t tx, rx;
            bit rx_err, timeout;
            tx = rand_bytes(256);
            preload_mem(tx, '0);
            fork
                descriptor_if.send(._addr('0), ._size(256));
                recv_packet(rx, rx_err, timeout);
            join
            `FAIL_IF_LOG(timeout, "Timed out waiting for packet.");
            `FAIL_UNLESS_EQUAL(rx.size(), tx.size());
            foreach (tx[i]) `FAIL_UNLESS_EQUAL(rx[i], tx[i]);
            `FAIL_IF_LOG(rx_err, "Unexpected err on clean packet.");
        `SVTEST_END

        // Odd-length packet: mty path must not corrupt or extend data.
        `SVTEST(partial_last_beat)
            byte_array_t tx, rx;
            bit rx_err, timeout;
            // 100B = one full 64B beat + 36B partial beat
            tx = rand_bytes(100);
            preload_mem(tx, '0);
            fork
                descriptor_if.send(._addr('0), ._size(100));
                recv_packet(rx, rx_err, timeout);
            join
            `FAIL_IF_LOG(timeout, "Timed out.");
            `FAIL_UNLESS_EQUAL(rx.size(), 100);
            foreach (tx[i]) `FAIL_UNLESS_EQUAL(rx[i], tx[i]);
        `SVTEST_END

        // Back-to-back packets at sequential memory offsets.
        `SVTEST(packet_burst)
            localparam int N       = 20;
            localparam int PKT_LEN = 128;
            localparam int WORDS   = (PKT_LEN + DATA_BYTE_WID - 1) / DATA_BYTE_WID;
            for (int p = 0; p < N; p++) begin
                byte_array_t tx, rx;
                bit rx_err, timeout;
                tx = rand_bytes(PKT_LEN);
                preload_mem(tx, ADDR_T'(p * WORDS));
                fork
                    descriptor_if.send(._addr(ADDR_T'(p * WORDS)), ._size(PKT_LEN));
                    recv_packet(rx, rx_err, timeout);
                join
                `FAIL_IF_LOG(timeout, $sformatf("Timed out on packet %0d.", p));
                `FAIL_UNLESS_EQUAL(rx.size(), PKT_LEN);
                `FAIL_IF_LOG(rx_err, $sformatf("Unexpected err on packet %0d.", p));
            end
        `SVTEST_END

        // CHECK_CKSUM=1: correct cksum in descriptor must not raise err.
        `SVTEST(cksum_correct_no_err)
            byte_array_t tx, rx;
            bit rx_err, timeout;
            logic [15:0] cksum;
            if (!CHECK_CKSUM) begin
                $display("SKIP: cksum_correct_no_err is CHECK_CKSUM only.");
            end else begin
                tx = rand_bytes(256);
                cksum = reference_cksum(tx);
                preload_mem(tx, '0);
                fork
                    descriptor_if.send(._addr('0), ._size(256), ._cksum(cksum));
                    recv_packet(rx, rx_err, timeout);
                join
                `FAIL_IF_LOG(timeout, "Timed out.");
                `FAIL_IF_LOG(rx_err, "Correct cksum raised err.");
            end
        `SVTEST_END

        // CHECK_CKSUM=1: wrong cksum must raise err on EOP.
        `SVTEST(cksum_mismatch_sets_err)
            byte_array_t tx, rx;
            bit rx_err, timeout;
            logic [15:0] cksum;
            if (!CHECK_CKSUM) begin
                $display("SKIP: cksum_mismatch_sets_err is CHECK_CKSUM only.");
            end else begin
                tx = rand_bytes(256);
                cksum = reference_cksum(tx) ^ 16'h0001;
                preload_mem(tx, '0);
                fork
                    descriptor_if.send(._addr('0), ._size(256), ._cksum(cksum));
                    recv_packet(rx, rx_err, timeout);
                join
                `FAIL_IF_LOG(timeout, "Timed out.");
                `FAIL_UNLESS_LOG(rx_err, "Bad cksum did not raise err.");
            end
        `SVTEST_END

        // CHECK_CKSUM=1: cksum==0 means not calculated; no check performed.
        `SVTEST(cksum_zero_skips_check)
            byte_array_t tx, rx;
            bit rx_err, timeout;
            if (!CHECK_CKSUM) begin
                $display("SKIP: cksum_zero_skips_check is CHECK_CKSUM only.");
            end else begin
                tx = rand_bytes(256);
                preload_mem(tx, '0);
                fork
                    descriptor_if.send(._addr('0), ._size(256), ._cksum(16'h0000));
                    recv_packet(rx, rx_err, timeout);
                join
                `FAIL_IF_LOG(timeout, "Timed out.");
                `FAIL_IF_LOG(rx_err, "cksum==0 should skip check but raised err.");
            end
        `SVTEST_END

        // CHECK_CKSUM=1: err must clear after a bad-cksum packet.
        `SVTEST(cksum_err_clears)
            byte_array_t tx, rx;
            bit err_bad, err_good, timeout;
            logic [15:0] cksum;
            if (!CHECK_CKSUM) begin
                $display("SKIP: cksum_err_clears is CHECK_CKSUM only.");
            end else begin
                tx = rand_bytes(128);
                cksum = reference_cksum(tx);
                preload_mem(tx, '0);
                fork
                    descriptor_if.send(._addr('0), ._size(128), ._cksum(cksum ^ 16'hffff));
                    recv_packet(rx, err_bad, timeout);
                join
                `FAIL_IF_LOG(timeout, "Timed out on bad-cksum packet.");
                `FAIL_UNLESS_LOG(err_bad, "Bad cksum did not raise err.");

                fork
                    descriptor_if.send(._addr('0), ._size(128), ._cksum(cksum));
                    recv_packet(rx, err_good, timeout);
                join
                `FAIL_IF_LOG(timeout, "Timed out on good-cksum packet.");
                `FAIL_IF_LOG(err_good, "err stuck after bad-cksum packet.");
            end
        `SVTEST_END

        // Descriptor err is forwarded regardless of cksum.
        `SVTEST(descriptor_err_forwarded)
            byte_array_t tx, rx;
            bit rx_err, timeout;
            logic [15:0] cksum;
            tx = rand_bytes(128);
            cksum = CHECK_CKSUM ? reference_cksum(tx) : 16'h0;
            preload_mem(tx, '0);
            fork
                descriptor_if.send(._addr('0), ._size(128), ._err(1'b1), ._cksum(cksum));
                recv_packet(rx, rx_err, timeout);
            join
            `FAIL_IF_LOG(timeout, "Timed out.");
            `FAIL_UNLESS_LOG(rx_err, "Descriptor err was not forwarded.");
        `SVTEST_END

        // Range of lengths covering all bus-width boundary cases.
        `SVTEST(various_lengths)
            int lengths [] = '{1, 63, 64, 65, 127, 128, 129, 512, 1000};
            for (int i = 0; i < lengths.size(); i++) begin
                byte_array_t tx, rx;
                bit rx_err, timeout;
                logic [15:0] cksum;
                tx = rand_bytes(lengths[i]);
                cksum = CHECK_CKSUM ? reference_cksum(tx) : 16'h0;
                preload_mem(tx, '0);
                fork
                    descriptor_if.send(._addr('0), ._size(lengths[i]), ._cksum(cksum));
                    recv_packet(rx, rx_err, timeout);
                join
                `FAIL_IF_LOG(timeout, $sformatf("Timed out at length %0d.", lengths[i]));
                `FAIL_UNLESS_EQUAL(rx.size(), lengths[i]);
                `FAIL_IF_LOG(rx_err, $sformatf("Unexpected err at length %0d.", lengths[i]));
            end
        `SVTEST_END

        // pkt_size must track the packet being presented on packet_if, not the
        // descriptor the read FSM has moved on to.  Back-to-back packets of
        // differing size with a stalled output expose the difference: the
        // FSM finishes issuing reads for a packet while its tail beats are
        // still waiting in the output buffer.
        `SVTEST(pkt_size_tracks_output_packet)
            int lengths [] = '{64, 1500, 64, 200, 1, 1500, 65, 64, 700, 64};
            int words;
            int addr;
            int errors;
            int rx_cnt;
            int cycles;
            addr = 0;
            for (int i = 0; i < lengths.size(); i++) begin
                preload_mem(rand_bytes(lengths[i]), ADDR_T'(addr));
                addr += (lengths[i] + DATA_BYTE_WID - 1) / DATA_BYTE_WID;
            end
            errors = 0;
            rx_cnt = 0;
            fork
                begin
                    addr = 0;
                    for (int i = 0; i < lengths.size(); i++) begin
                        descriptor_if.send(._addr(ADDR_T'(addr)), ._size(lengths[i]),
                                           ._cksum(16'h0));
                        addr += (lengths[i] + DATA_BYTE_WID - 1) / DATA_BYTE_WID;
                    end
                end
                begin
                    cycles = 0;
                    while (rx_cnt < lengths.size() && cycles < 50000) begin
                        if (!IGNORE_RDY) packet_if.cb_rx.rdy <= ($urandom_range(0, 3) == 0);
                        @(posedge clk);
                        if (packet_if.vld && (IGNORE_RDY || packet_if.rdy) && packet_if.eop) begin
                            if (pkt_size != size_t'(lengths[rx_cnt])) begin
                                errors++;
                                $display("pkt_size mismatch on packet %0d: got %0d, expected %0d",
                                         rx_cnt, pkt_size, lengths[rx_cnt]);
                            end
                            rx_cnt++;
                        end
                        cycles++;
                    end
                    if (!IGNORE_RDY) packet_if.cb_rx.rdy <= 1'b0;
                end
            join
            `FAIL_UNLESS_EQUAL(rx_cnt, lengths.size());
            `FAIL_UNLESS_EQUAL(errors, 0);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : packet_read_tb


`define PACKET_READ_UNIT_TEST(CHECK_CKSUM, IGNORE_RDY)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  packet_read_tb #(CHECK_CKSUM, IGNORE_RDY) test();\
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

module packet_read_basic_unit_test;
`PACKET_READ_UNIT_TEST(1'b0, 1'b0);
endmodule

module packet_read_check_cksum_unit_test;
`PACKET_READ_UNIT_TEST(1'b1, 1'b0);
endmodule

module packet_read_check_cksum_ignore_rdy_unit_test;
`PACKET_READ_UNIT_TEST(1'b1, 1'b1);
endmodule
