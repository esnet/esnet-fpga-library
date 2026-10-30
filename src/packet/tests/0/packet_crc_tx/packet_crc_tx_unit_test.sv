`include "svunit_defines.svh"

module packet_crc_tx_unit_test #(
    parameter crc_pkg::crc_config_t CONFIG = crc_pkg::DEFAULT_CRC,
    parameter int DATA_BYTE_WID = 8,
    parameter bit TRIM = 1,
    parameter bit BYTE_REVERSE = 0,
    parameter string NAME = "packet_crc_tx"
);
    import svunit_pkg::svunit_testcase;

    string name = $sformatf("%s_ut", NAME);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int MTY_WID  = $clog2(DATA_BYTE_WID);
    localparam int META_WID = 8;

    typedef byte byte_array_t [];

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) tx_if (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) rx_if (.clk);

    logic [CONFIG.WIDTH-1:0] crc_out;

    packet_crc_tx #(
        .CONFIG       ( CONFIG ),
        .TRIM         ( TRIM ),
        .BYTE_REVERSE ( BYTE_REVERSE )
    ) DUT (
        .srst,
        .from_tx ( tx_if ),
        .to_rx   ( rx_if ),
        .crc_out
    );

    //===================================
    // Clock / reset
    //===================================
    std_reset_intf reset_if (.clk(clk));
    assign srst = reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    `SVUNIT_CLK_GEN(clk, 1.5ns);

    //===================================
    // Reference model
    //===================================
    // With TRIM=0 the CRC covers the zero-padded final beat; with
    // BYTE_REVERSE=1 the bytes of each beat enter the CRC last byte first.
    function automatic logic [CONFIG.WIDTH-1:0] reference_crc(input byte_array_t data);
        byte_array_t crc_data = data;
        if (!TRIM) begin
            int num_beats = (data.size() + DATA_BYTE_WID - 1) / DATA_BYTE_WID;
            crc_data = new[num_beats * DATA_BYTE_WID];
            foreach (crc_data[i]) crc_data[i] = (i < data.size()) ? data[i] : 8'h00;
        end
        if (BYTE_REVERSE) begin
            byte_array_t rev = new[crc_data.size()];
            foreach (rev[i])
                rev[i] = crc_data[(i / DATA_BYTE_WID) * DATA_BYTE_WID + (DATA_BYTE_WID - 1 - (i % DATA_BYTE_WID))];
            crc_data = rev;
        end
        reference_crc = crc_verif_pkg::calculate(
            CONFIG.WIDTH,
            CONFIG.POLY,
            CONFIG.INIT,
            CONFIG.REFIN,
            CONFIG.REFOUT,
            CONFIG.XOROUT,
            crc_data
        );
    endfunction

    function automatic byte_array_t rand_bytes(input int len);
        byte_array_t b = new[len];
        foreach (b[i]) b[i] = byte'($urandom_range(0, 255));
        return b;
    endfunction

    // Send one complete packet, waiting for ready each beat.
    task automatic send_packet(
        input byte_array_t         data,
        input bit                  src_err = 1'b0,
        input logic [META_WID-1:0] meta    = '0
    );
        int num_words = (data.size() + DATA_BYTE_WID - 1) / DATA_BYTE_WID;
        for (int w = 0; w < num_words; w++) begin
            automatic bit [0:DATA_BYTE_WID-1][7:0] word = '0;
            automatic int valid_bytes = (w == num_words-1) ?
                data.size() - w*DATA_BYTE_WID : DATA_BYTE_WID;
            automatic bit is_eop = (w == num_words-1);
            automatic bit [MTY_WID-1:0] mty = MTY_WID'(DATA_BYTE_WID - valid_bytes);
            for (int b = 0; b < valid_bytes; b++) word[b] = data[w*DATA_BYTE_WID + b];
            tx_if.cb_tx.vld  <= 1'b1;
            tx_if.cb_tx.data <= word;
            tx_if.cb_tx.eop  <= is_eop;
            tx_if.cb_tx.mty  <= mty;
            tx_if.cb_tx.err  <= (is_eop ? src_err : 1'b0);
            tx_if.cb_tx.meta <= meta;
            @(tx_if.cb_tx iff (tx_if.cb_tx.mon_tx_vld && tx_if.cb_tx.rdy));
        end
        tx_if.cb_tx.vld <= 1'b0;
    endtask

    // Receive one complete packet (rdy held high throughout).  rx_crc
    // captures crc_out at the exact cycle the output EOP beat is accepted
    // (crc_out is valid only on that cycle, per the module's contract, so
    // it must be sampled here rather than after this task returns).
    task automatic recv_packet(
        output byte_array_t        rx_data,
        output bit                 rx_err,
        output logic [META_WID-1:0] rx_meta,
        output logic [CONFIG.WIDTH-1:0] rx_crc
    );
        byte  rx_q[$];
        bit   eop = 0;
        rx_if.cb_rx.rdy <= 1'b1;
        while (!eop) begin
            @(rx_if.cb_rx);
            if (rx_if.cb_rx.vld) begin
                automatic logic [0:DATA_BYTE_WID-1][7:0] word = rx_if.cb_rx.data;
                automatic int valid = rx_if.cb_rx.eop ?
                    DATA_BYTE_WID - int'(rx_if.cb_rx.mty) : DATA_BYTE_WID;
                for (int b = 0; b < valid; b++) rx_q.push_back(byte'(word[b]));
                eop = rx_if.cb_rx.eop;
                if (eop) begin
                    rx_err  = rx_if.cb_rx.err;
                    rx_meta = rx_if.cb_rx.meta;
                    rx_crc  = crc_out;
                end
            end
        end
        rx_if.cb_rx.rdy <= 1'b0;
        rx_data = rx_q;
    endtask

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tx_if.idle_tx();
        rx_if.idle_rx();
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

        `SVTEST(single_beat_packet)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] exp_crc, rx_crc;
            tx_data = rand_bytes(DATA_BYTE_WID);
            exp_crc = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta, rx_crc);
            join
            `FAIL_UNLESS_EQUAL(rx_crc, exp_crc);
            `FAIL_IF(rx_err);
        `SVTEST_END

        `SVTEST(multi_beat_packet)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] exp_crc, rx_crc;
            tx_data = rand_bytes(4 * DATA_BYTE_WID);
            exp_crc = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta, rx_crc);
            join
            `FAIL_UNLESS_EQUAL(rx_crc, exp_crc);
            `FAIL_IF(rx_err);
        `SVTEST_END

        `SVTEST(partial_last_beat)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] exp_crc, rx_crc;
            tx_data = rand_bytes(DATA_BYTE_WID + DATA_BYTE_WID / 2);
            exp_crc = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta, rx_crc);
            join
            `FAIL_UNLESS_EQUAL(rx_crc, exp_crc);
            `FAIL_IF(rx_err);
        `SVTEST_END

        // Back-to-back packets with no idle gap get independent CRCs.
        `SVTEST(back_to_back_packets)
            byte_array_t tx0, tx1, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] exp0, exp1, got0, got1;
            tx0 = rand_bytes(2 * DATA_BYTE_WID);
            tx1 = rand_bytes(3 * DATA_BYTE_WID + 1);
            exp0 = reference_crc(tx0);
            exp1 = reference_crc(tx1);
            fork
                begin send_packet(tx0); send_packet(tx1); end
                begin
                    recv_packet(rx_data, rx_err, rx_meta, got0);
                    recv_packet(rx_data, rx_err, rx_meta, got1);
                end
            join
            `FAIL_UNLESS_EQUAL(got0, exp0);
            `FAIL_UNLESS_EQUAL(got1, exp1);
        `SVTEST_END

        // err propagates unchanged; CRC is still computed correctly.
        `SVTEST(err_passthrough)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] exp_crc, rx_crc;
            tx_data = rand_bytes(2 * DATA_BYTE_WID);
            exp_crc = reference_crc(tx_data);
            fork
                send_packet(tx_data, .src_err(1'b1));
                recv_packet(rx_data, rx_err, rx_meta, rx_crc);
            join
            `FAIL_UNLESS(rx_err);
            `FAIL_UNLESS_EQUAL(rx_crc, exp_crc);
        `SVTEST_END

        // meta propagates unchanged.
        `SVTEST(meta_passthrough)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta, exp_meta;
            logic [CONFIG.WIDTH-1:0] rx_crc;
            tx_data  = rand_bytes(DATA_BYTE_WID);
            exp_meta = $urandom();
            fork
                send_packet(tx_data, .src_err(1'b0), .meta(exp_meta));
                recv_packet(rx_data, rx_err, rx_meta, rx_crc);
            join
            `FAIL_UNLESS_EQUAL(rx_meta, exp_meta);
        `SVTEST_END

        // CRC is correct when the receiver applies backpressure.
        `SVTEST(backpressure)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] exp_crc, rx_crc;
            tx_data = rand_bytes(4 * DATA_BYTE_WID);
            exp_crc = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                // Delay receiver by a few cycles to exercise backpressure
                begin
                    repeat(5) @(posedge clk);
                    recv_packet(rx_data, rx_err, rx_meta, rx_crc);
                end
            join
            `FAIL_UNLESS_EQUAL(rx_crc, exp_crc);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule


// ──────────────────────────────────────────────────────────────────────────────
// Wrapper boilerplate
// ──────────────────────────────────────────────────────────────────────────────
`define PACKET_CRC_TX_UNIT_TEST(CFG, BYTES, NM, TRM = 1, REV = 0) \
  import svunit_pkg::svunit_testcase; \
  svunit_testcase svunit_ut; \
  packet_crc_tx_unit_test #(.CONFIG(CFG), .DATA_BYTE_WID(BYTES), .TRIM(TRM), .BYTE_REVERSE(REV), .NAME(NM)) test(); \
  function void build(); \
    test.build(); \
    svunit_ut = test.svunit_ut; \
  endfunction \
  function void __register_tests(); \
    test.__register_tests(); \
  endfunction \
  task run(); \
    test.run(); \
  endtask


module packet_crc_tx_crc32_x8_unit_test;
    `PACKET_CRC_TX_UNIT_TEST(crc_pkg::CRC32, 8, "packet_crc_tx_crc32_x8")
endmodule

module packet_crc_tx_crc32_x64_unit_test;
    `PACKET_CRC_TX_UNIT_TEST(crc_pkg::CRC32, 64, "packet_crc_tx_crc32_x64")
endmodule

module packet_crc_tx_mpeg2_beat_x8_unit_test;
    `PACKET_CRC_TX_UNIT_TEST(crc_pkg::CRC32_MPEG2, 8, "packet_crc_tx_mpeg2_beat_x8", 0, 1)
endmodule

module packet_crc_tx_mpeg2_beat_x64_unit_test;
    `PACKET_CRC_TX_UNIT_TEST(crc_pkg::CRC32_MPEG2, 64, "packet_crc_tx_mpeg2_beat_x64", 0, 1)
endmodule
