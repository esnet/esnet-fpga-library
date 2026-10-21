`include "svunit_defines.svh"

module packet_crc_rx_unit_test #(
    parameter crc_pkg::crc_config_t CONFIG = crc_pkg::DEFAULT_CRC,
    parameter int DATA_BYTE_WID = 8,
    parameter string NAME = "packet_crc_rx"
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

    logic [CONFIG.WIDTH-1:0] crc_in;

    packet_crc_rx #(
        .CONFIG ( CONFIG )
    ) DUT (
        .srst,
        .from_tx ( tx_if ),
        .to_rx   ( rx_if ),
        .crc_in
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
    function automatic logic [CONFIG.WIDTH-1:0] reference_crc(input byte_array_t data);
        reference_crc = crc_verif_pkg::calculate(
            CONFIG.WIDTH,
            CONFIG.POLY,
            CONFIG.INIT,
            CONFIG.REFIN,
            CONFIG.REFOUT,
            CONFIG.XOROUT,
            data
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

    // Receive one complete packet (rdy held high throughout).
    task automatic recv_packet(
        output byte_array_t        rx_data,
        output bit                 rx_err,
        output logic [META_WID-1:0] rx_meta
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
        crc_in = '0;
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

        // Correct CRC → no error on output EOP.
        `SVTEST(matching_crc_no_err)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            tx_data = rand_bytes(2 * DATA_BYTE_WID);
            crc_in  = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta);
            join
            `FAIL_IF(rx_err);
        `SVTEST_END

        // Wrong CRC → err=1 on output EOP.
        `SVTEST(mismatched_crc_sets_err)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            tx_data = rand_bytes(2 * DATA_BYTE_WID);
            crc_in  = reference_crc(tx_data) ^ 32'hDEAD_BEEF;
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta);
            join
            `FAIL_UNLESS(rx_err);
        `SVTEST_END

        // Incoming err=1 preserved even when CRC matches.
        `SVTEST(err_passthrough_preserved)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            tx_data = rand_bytes(2 * DATA_BYTE_WID);
            crc_in  = reference_crc(tx_data);
            fork
                send_packet(tx_data, .src_err(1'b1));
                recv_packet(rx_data, rx_err, rx_meta);
            join
            `FAIL_UNLESS(rx_err);
        `SVTEST_END

        // Alternating good / bad CRC detection across multiple packets.
        `SVTEST(back_to_back_mixed)
            byte_array_t tx0, tx1, tx2, rx_data;
            bit rx_err0, rx_err1, rx_err2;
            logic [META_WID-1:0] rx_meta;
            logic [CONFIG.WIDTH-1:0] crc0, crc1, crc2;
            tx0 = rand_bytes(2 * DATA_BYTE_WID);
            tx1 = rand_bytes(3 * DATA_BYTE_WID);
            tx2 = rand_bytes(2 * DATA_BYTE_WID);
            crc0 = reference_crc(tx0);
            crc1 = reference_crc(tx1);
            crc2 = reference_crc(tx2);
            fork
                begin
                    crc_in = crc0;         send_packet(tx0);
                    crc_in = crc1 ^ '1;    send_packet(tx1);
                    crc_in = crc2;         send_packet(tx2);
                end
                begin
                    recv_packet(rx_data, rx_err0, rx_meta);
                    recv_packet(rx_data, rx_err1, rx_meta);
                    recv_packet(rx_data, rx_err2, rx_meta);
                end
            join
            `FAIL_IF(rx_err0);
            `FAIL_UNLESS(rx_err1);
            `FAIL_IF(rx_err2);
        `SVTEST_END

        // Partial last beat (mty > 0) handled correctly.
        `SVTEST(partial_last_beat)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            tx_data = rand_bytes(DATA_BYTE_WID + DATA_BYTE_WID / 2);
            crc_in  = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta);
            join
            `FAIL_IF(rx_err);
        `SVTEST_END

        // CRC correct under backpressure from downstream.
        `SVTEST(backpressure)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            tx_data = rand_bytes(4 * DATA_BYTE_WID);
            crc_in  = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                begin
                    repeat(5) @(posedge clk);
                    recv_packet(rx_data, rx_err, rx_meta);
                end
            join
            `FAIL_IF(rx_err);
        `SVTEST_END

        // Data and meta pass through unchanged; only err is OR'd on EOP.
        `SVTEST(data_integrity)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta, exp_meta;
            tx_data  = rand_bytes(3 * DATA_BYTE_WID);
            exp_meta = $urandom();
            crc_in   = reference_crc(tx_data);
            fork
                send_packet(tx_data, .src_err(1'b0), .meta(exp_meta));
                recv_packet(rx_data, rx_err, rx_meta);
            join
            `FAIL_IF(rx_err);
            `FAIL_UNLESS_EQUAL(rx_meta, exp_meta);
            `FAIL_UNLESS_EQUAL(rx_data.size(), tx_data.size());
            foreach (tx_data[i]) `FAIL_UNLESS_EQUAL(rx_data[i], tx_data[i]);
        `SVTEST_END

        // Single-beat packet with correct CRC → no error.
        `SVTEST(single_beat_packet)
            byte_array_t tx_data, rx_data;
            bit rx_err;
            logic [META_WID-1:0] rx_meta;
            tx_data = rand_bytes(DATA_BYTE_WID);
            crc_in  = reference_crc(tx_data);
            fork
                send_packet(tx_data);
                recv_packet(rx_data, rx_err, rx_meta);
            join
            `FAIL_IF(rx_err);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule


// ──────────────────────────────────────────────────────────────────────────────
// Wrapper boilerplate
// ──────────────────────────────────────────────────────────────────────────────
`define PACKET_CRC_RX_UNIT_TEST(CFG, BYTES, NM) \
  import svunit_pkg::svunit_testcase; \
  svunit_testcase svunit_ut; \
  packet_crc_rx_unit_test #(.CONFIG(CFG), .DATA_BYTE_WID(BYTES), .NAME(NM)) test(); \
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


module packet_crc_rx_crc32_x8_unit_test;
    `PACKET_CRC_RX_UNIT_TEST(crc_pkg::CRC32, 8, "packet_crc_rx_crc32_x8")
endmodule

module packet_crc_rx_crc32_x64_unit_test;
    `PACKET_CRC_RX_UNIT_TEST(crc_pkg::CRC32, 64, "packet_crc_rx_crc32_x64")
endmodule
