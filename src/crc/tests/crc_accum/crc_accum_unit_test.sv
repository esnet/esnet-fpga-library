`include "svunit_defines.svh"

// =========================================================================
// crc_accum_unit_test
//
// Two key properties tested:
//   1. Single-beat output matches crc_verif_pkg::calculate reference.
//   2. Multi-beat accumulation: feeding the check string one byte per beat
//      (DATA_BYTES=1, nine beats) produces the same CHECK value.
//   3. srst resets state cleanly — a second packet produces the same CRC.
// =========================================================================
module crc_accum_unit_test
#(
    parameter crc_pkg::crc_spec_t CRC_SPEC = crc_pkg::DEFAULT_CRC,
    parameter int DATA_BYTES = 1
) (
);
    import svunit_pkg::svunit_testcase;
    import crc_pkg::*;

    parameter int WIDTH = CRC_SPEC.cfg.WIDTH;
    string name = {CRC_SPEC.shortname, "_accum_ut"};
    svunit_testcase svunit_ut;

    typedef bit[WIDTH-1:0] CRC_T;

    // UUT
    logic clk;
    logic srst;
    logic en;
    logic [(DATA_BYTES > 1 ? $clog2(DATA_BYTES) : 1)-1:0] mty;
    logic [0:DATA_BYTES-1][7:0] data;
    CRC_T crc;
    logic check;

    crc_accum #(CRC_SPEC.cfg, DATA_BYTES) UUT (.*);

    `SVUNIT_CLK_GEN(clk, 5ns);

    function void build();
        svunit_ut = new(name);
    endfunction

    // Stimulus is driven on the negative clock edge throughout, so that the
    // UUT's always_ff samples settled values at the following posedge.
    task setup();
        svunit_ut.setup();
        @(negedge clk);
        srst = 1'b1;
        en   = 1'b0;
        mty  = '0;
        data = '0;
        repeat (8) @(posedge clk);
        @(negedge clk);
        srst = 1'b0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------
    function automatic void string_to_bytes(input string s, output byte b[]);
        b = new[s.len()];
        foreach (s[i]) b[i] = s[i];
    endfunction

    function automatic void random_bytes(input int n, output byte b[]);
        b = new[n];
        foreach (b[i]) b[i] = $urandom_range(0, 255);
    endfunction

    // Feed data_in as DATA_BYTES-wide beats.  data_in.size() must be a
    // multiple of DATA_BYTES.  mty=0 on every beat.
    // The combinatorial crc and check outputs are sampled on the final beat.
    task automatic feed_beats(input byte data_in[], output CRC_T crc_out, output logic check_out);
        automatic int n_beats = data_in.size() / DATA_BYTES;
        for (int beat = 0; beat < n_beats; beat++) begin
            @(negedge clk);
            en  = 1'b1;
            mty = '0;
            for (int b = 0; b < DATA_BYTES; b++)
                data[b] = data_in[beat * DATA_BYTES + b];
            if (beat == n_beats - 1) begin
                #1ns;         // let the comb path settle
                crc_out   = crc;
                check_out = check;
            end
            @(posedge clk);   // commit this beat into state_reg
        end
        @(negedge clk);
        en  = 1'b0;
        mty = '0;
    endtask

    // Feed data_in as a packet of arbitrary byte length.  The last beat is
    // automatically padded to DATA_BYTES wide and mty is set to exclude the
    // trailing padding from the CRC.  The reference CRC is computed over
    // data_in.size() bytes; the DUT must produce the same result.
    task automatic feed_packet(input byte data_in[], output CRC_T crc_out, output logic check_out);
        automatic int n_full   = data_in.size() / DATA_BYTES;
        automatic int rem      = data_in.size() % DATA_BYTES;
        automatic int n_beats  = n_full + (rem > 0 ? 1 : 0);
        automatic int last_mty = (rem > 0) ? (DATA_BYTES - rem) : 0;
        for (int beat = 0; beat < n_beats; beat++) begin
            automatic bit is_last = (beat == n_beats - 1);
            @(negedge clk);
            en  = 1'b1;
            mty = is_last ? last_mty : 0;
            for (int b = 0; b < DATA_BYTES; b++) begin
                automatic int idx = beat * DATA_BYTES + b;
                data[b] = (idx < data_in.size()) ? data_in[idx] : 8'h00;
            end
            if (is_last) begin
                #1ns;
                crc_out   = crc;
                check_out = check;
            end
            @(posedge clk);
        end
        @(negedge clk);
        en  = 1'b0;
        mty = '0;
    endtask

    // Soft reset between packets (one cycle of srst)
    task automatic packet_reset();
        @(negedge clk);
        srst = 1'b1;
        @(posedge clk);
        @(negedge clk);
        srst = 1'b0;
    endtask

    function automatic CRC_T reference_crc(byte data_in[]);
        return crc_verif_pkg::calculate(
            WIDTH,
            CRC_SPEC.cfg.POLY,
            CRC_SPEC.cfg.INIT,
            CRC_SPEC.cfg.REFIN,
            CRC_SPEC.cfg.REFOUT,
            CRC_SPEC.cfg.XOROUT,
            data_in
        );
    endfunction

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN

        // Single DATA_BYTES-wide beat — result must match the reference CRC
        // computed over DATA_BYTES bytes of the check string (zero-padded).
        `SVTEST(single_beat_reference)
            byte check_data[];
            byte padded [];
            CRC_T expected;
            CRC_T got;
            logic chk;

            string_to_bytes(crc_pkg::CHECK_STRING, check_data);

            // Zero-pad check_data to exactly DATA_BYTES
            padded = new[DATA_BYTES];
            foreach (padded[i]) padded[i] = (i < check_data.size()) ? check_data[i] : 8'h00;

            expected = reference_crc(padded);
            feed_beats(padded, got, chk);

            `FAIL_IF_LOG(got !== expected,
                $sformatf("single_beat_reference: got 0x%08x, expected 0x%08x", got, expected));
        `SVTEST_END

        // Multi-beat accumulation over randomised data.  Uses 3 full beats so
        // that every instantiation exercises the state feedback path, not just
        // the DATA_BYTES==1 case.
        `SVTEST(multi_beat_reference)
            byte rand_data[];
            CRC_T expected;
            CRC_T got;
            logic chk;

            random_bytes(DATA_BYTES * 3, rand_data);

            expected = reference_crc(rand_data);
            feed_beats(rand_data, got, chk);

            `FAIL_IF_LOG(got !== expected,
                $sformatf("multi_beat_reference: got 0x%08x, expected 0x%08x", got, expected));
        `SVTEST_END

        // Accumulation must hold over a long transfer (16 beats).
        `SVTEST(long_transfer_reference)
            byte rand_data[];
            CRC_T expected;
            CRC_T got;
            logic chk;

            random_bytes(DATA_BYTES * 16, rand_data);

            expected = reference_crc(rand_data);
            feed_beats(rand_data, got, chk);

            `FAIL_IF_LOG(got !== expected,
                $sformatf("long_transfer_reference: got 0x%08x, expected 0x%08x", got, expected));
        `SVTEST_END

        // Check string produces the CRC_SPEC.cfg.CHECK value.
        // Uses feed_packet so the 9-byte string is handled correctly on any bus width.
        `SVTEST(check_value)
            byte check_data[];
            CRC_T expected = CRC_SPEC.cfg.CHECK;
            CRC_T got;
            logic chk;

            string_to_bytes(crc_pkg::CHECK_STRING, check_data);
            feed_packet(check_data, got, chk);
            `FAIL_IF_LOG(got !== expected,
                $sformatf("check_value: got 0x%08x, expected 0x%08x", got, expected));
        `SVTEST_END

        // Packet reset: after srst, a second packet of the same data produces
        // the same CRC, and both match the reference.  This is the property
        // the QDMA C2H path depends on (srst asserted one cycle after EOP).
        `SVTEST(packet_reset_reproducible)
            byte rand_data[];
            CRC_T expected;
            CRC_T crc1, crc2;
            logic chk1, chk2;

            random_bytes(DATA_BYTES * 3, rand_data);
            expected = reference_crc(rand_data);

            feed_beats(rand_data, crc1, chk1);
            packet_reset();
            feed_beats(rand_data, crc2, chk2);

            `FAIL_IF_LOG(crc1 !== expected,
                $sformatf("packet_reset_reproducible: pkt1=0x%08x, expected 0x%08x", crc1, expected));
            `FAIL_IF_LOG(crc2 !== expected,
                $sformatf("packet_reset_reproducible: pkt2=0x%08x, expected 0x%08x", crc2, expected));
        `SVTEST_END

        // Back-to-back packets of differing length, with a reset between.
        `SVTEST(packet_reset_varying_length)
            byte pkt_a[];
            byte pkt_b[];
            CRC_T exp_a, exp_b;
            CRC_T got_a, got_b;
            logic chk_a, chk_b;

            random_bytes(DATA_BYTES * 2, pkt_a);
            random_bytes(DATA_BYTES * 5, pkt_b);
            exp_a = reference_crc(pkt_a);
            exp_b = reference_crc(pkt_b);

            feed_beats(pkt_a, got_a, chk_a);
            packet_reset();
            feed_beats(pkt_b, got_b, chk_b);

            `FAIL_IF_LOG(got_a !== exp_a,
                $sformatf("packet_reset_varying_length: pkt_a=0x%08x, expected 0x%08x", got_a, exp_a));
            `FAIL_IF_LOG(got_b !== exp_b,
                $sformatf("packet_reset_varying_length: pkt_b=0x%08x, expected 0x%08x", got_b, exp_b));
        `SVTEST_END

        // Partial last beat: feed a packet whose byte count is not a multiple
        // of DATA_BYTES.  The trailing (DATA_BYTES - remainder) bytes are padding
        // and must not affect the CRC.  When DATA_BYTES==1 this reduces to a
        // single full beat (mty=0), exercising the trivial path.
        `SVTEST(partial_beat_reference)
            byte rand_data[];
            CRC_T expected;
            CRC_T got;
            logic chk;

            // Two full beats plus a partial: for DATA_BYTES==1 this is 3 full bytes.
            random_bytes(DATA_BYTES * 2 + (DATA_BYTES > 1 ? DATA_BYTES / 2 : 1), rand_data);
            expected = reference_crc(rand_data);
            feed_packet(rand_data, got, chk);
            `FAIL_IF_LOG(got !== expected,
                $sformatf("partial_beat_reference: got 0x%08x, expected 0x%08x", got, expected));
        `SVTEST_END

        // Two consecutive partial-beat packets of identical data must produce
        // the same CRC, proving the state resets cleanly between packets.
        `SVTEST(partial_beat_reset)
            byte rand_data[];
            CRC_T expected;
            CRC_T crc1, crc2;
            logic chk1, chk2;

            random_bytes(DATA_BYTES + (DATA_BYTES > 1 ? 3 : 1), rand_data);
            expected = reference_crc(rand_data);

            feed_packet(rand_data, crc1, chk1);
            packet_reset();
            feed_packet(rand_data, crc2, chk2);

            `FAIL_IF_LOG(crc1 !== expected,
                $sformatf("partial_beat_reset: pkt1=0x%08x, expected 0x%08x", crc1, expected));
            `FAIL_IF_LOG(crc2 !== expected,
                $sformatf("partial_beat_reset: pkt2=0x%08x, expected 0x%08x", crc2, expected));
        `SVTEST_END

        // check output: feed message + correct FCS; check must assert on EOP.
        // Also verify check does NOT assert for a corrupted FCS.
        // Uses feed_packet so this works on any DATA_BYTES width.
        `SVTEST(check_output)
            byte msg[];
            byte fcs_bytes[];
            byte full_pkt[];
            byte bad_pkt[];
            CRC_T fcs;
            CRC_T got;
            logic chk;

            random_bytes(DATA_BYTES * 4, msg);
            fcs = reference_crc(msg);

            // Reflected algorithms (REFOUT=1) place the FCS LSB-first on the wire.
            // Non-reflected (REFOUT=0) place it MSB-first.
            fcs_bytes = new[CRC_SPEC.cfg.WIDTH / 8];
            for (int i = 0; i < CRC_SPEC.cfg.WIDTH / 8; i++) begin
                automatic int byte_idx = CRC_SPEC.cfg.REFOUT ? i : (CRC_SPEC.cfg.WIDTH / 8 - 1 - i);
                fcs_bytes[i] = fcs[8*byte_idx +: 8];
            end

            full_pkt = new[msg.size() + fcs_bytes.size()];
            foreach (msg[i])       full_pkt[i]              = msg[i];
            foreach (fcs_bytes[i]) full_pkt[msg.size() + i] = fcs_bytes[i];

            feed_packet(full_pkt, got, chk);
            `FAIL_IF_LOG(!chk,
                $sformatf("check_output: check not asserted for valid message+FCS (crc=0x%08x)", got));

            // Corrupt one byte of the FCS and verify check de-asserts
            bad_pkt = full_pkt;
            bad_pkt[msg.size()] ^= 8'hff;
            packet_reset();
            feed_packet(bad_pkt, got, chk);
            `FAIL_IF_LOG(chk,
                $sformatf("check_output: check asserted for corrupted FCS (crc=0x%08x)", got));
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : crc_accum_unit_test


// ============================================================
// Boilerplate wrapper — mirrors the pattern in crc_unit_test.sv
// ============================================================
`define CRC_ACCUM_UNIT_TEST(CONFIG, BYTES)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  crc_accum_unit_test #(.CRC_SPEC(``CONFIG), .DATA_BYTES(``BYTES)) test();\
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

// ------------------------------------------------------------
// Instantiations
// ------------------------------------------------------------

// CRC-32 — byte-serial (DATA_BYTES=1): verifies multi-beat accumulation
// and produces the catalogued CHECK value directly.
module crc32_accum_x1_unit_test;
`CRC_ACCUM_UNIT_TEST(crc_pkg::CRC32, 1)
endmodule

// CRC-32 — 9-byte bus (wide single beat, same width as check string)
module crc32_accum_x9_unit_test;
`CRC_ACCUM_UNIT_TEST(crc_pkg::CRC32, 9)
endmodule

// CRC-32/ISO-HDLC — wide bus matching the QDMA C2H use case
module crc32_iso_hdlc_accum_x64_unit_test;
`CRC_ACCUM_UNIT_TEST(crc_pkg::CRC32_ISO_HDLC, 64)
endmodule

// CRC-8 — narrow, exercises the g_narrow generate path
module crc8_accum_x1_unit_test;
`CRC_ACCUM_UNIT_TEST(crc_pkg::CRC8, 1)
endmodule

// CRC-32/BZIP2 — non-reflected (REFIN=0, REFOUT=0); exercises the MSB-first
// FCS byte-append path in check_output.
module crc32_bzip2_accum_x1_unit_test;
`CRC_ACCUM_UNIT_TEST(crc_pkg::CRC32_BZIP2, 1)
endmodule

module crc32_bzip2_accum_x8_unit_test;
`CRC_ACCUM_UNIT_TEST(crc_pkg::CRC32_BZIP2, 8)
endmodule
