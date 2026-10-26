`include "svunit_defines.svh"

// =========================================================================
// crc_trim_unit_test
//
// Key property tested: for a packet whose true last beat has `mty` empty
// trailing bytes, zero-masking those bytes and accumulating with
// crc_accum's mty tied to 0 (the "pretend full beat" path), then applying
// crc_trim with the real mty, must reproduce exactly what crc_accum itself
// produces when driven with the real mty directly. This is the equivalence
// the packet_crc_tx/rx pipelining relies on.
//
// Also verifies the check output against a message+FCS, and against the
// crc_verif_pkg reference model directly.
// =========================================================================
module crc_trim_unit_test
#(
    parameter crc_pkg::crc_config_t CONFIG = crc_pkg::DEFAULT_CRC,
    parameter string NAME = "crc",
    parameter int DATA_BYTES = 8
) (
);
    import svunit_pkg::svunit_testcase;
    import crc_pkg::*;

    parameter int WIDTH = CONFIG.WIDTH;
    string name = {NAME, "_trim_ut"};
    svunit_testcase svunit_ut;

    typedef bit[WIDTH-1:0] CRC_T;
    localparam int MTY_WID = (DATA_BYTES > 1 ? $clog2(DATA_BYTES) : 1);

    // -----------------------------------------------------------------------
    // UUTs
    // -----------------------------------------------------------------------
    // Reference accumulator — driven with the true mty on the EOP beat.
    logic clk;
    logic srst;
    logic en;
    logic [MTY_WID-1:0] mty_ref;
    logic [0:DATA_BYTES-1][7:0] data_ref;
    CRC_T crc_ref_accum;
    logic check_ref_accum_unused;

    crc_accum #(CONFIG, DATA_BYTES) UUT_REF (
        .clk, .srst, .en,
        .mty  ( mty_ref ),
        .data ( data_ref ),
        .crc  ( crc_ref_accum ),
        .check ( check_ref_accum_unused )
    );

    // Padded accumulator — always driven with mty=0; data pre-masked.
    logic [MTY_WID-1:0] mty_padded;
    assign mty_padded = '0;
    logic [0:DATA_BYTES-1][7:0] data_padded;
    CRC_T crc_padded_accum;
    logic check_padded_accum_unused;

    crc_accum #(CONFIG, DATA_BYTES) UUT_PADDED (
        .clk, .srst, .en,
        .mty  ( mty_padded ),
        .data ( data_padded ),
        .crc  ( crc_padded_accum ),
        .check ( check_padded_accum_unused )
    );

    // crc_trim under test — corrects crc_padded_accum's output
    logic [MTY_WID-1:0] trim_mty;
    CRC_T trim_crc;
    logic trim_check;

    crc_trim #(CONFIG, DATA_BYTES) UUT_TRIM (
        .crc_in ( crc_padded_accum ),
        .mty    ( trim_mty ),
        .crc    ( trim_crc ),
        .check  ( trim_check )
    );

    `SVUNIT_CLK_GEN(clk, 5ns);

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        @(negedge clk);
        srst = 1'b1;
        en   = 1'b0;
        mty_ref  = '0;
        data_ref = '0;
        data_padded = '0;
        trim_mty = '0;
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

    // Drives both UUT_REF (real mty) and UUT_PADDED (mty=0, data zero-masked)
    // in lockstep over a packet of arbitrary byte length. Samples crc_trim's
    // output (applied to UUT_PADDED's result with the true last-beat mty) and
    // UUT_REF's own combinatorial output on the final beat.
    task automatic feed_packet(input byte data_in[], output CRC_T ref_crc_out, output CRC_T trim_crc_out, output logic trim_check_out);
        automatic int n_full   = data_in.size() / DATA_BYTES;
        automatic int rem      = data_in.size() % DATA_BYTES;
        automatic int n_beats  = n_full + (rem > 0 ? 1 : 0);
        automatic int last_mty = (rem > 0) ? (DATA_BYTES - rem) : 0;
        for (int beat = 0; beat < n_beats; beat++) begin
            automatic bit is_last = (beat == n_beats - 1);
            automatic int beat_mty = is_last ? last_mty : 0;
            @(negedge clk);
            en = 1'b1;
            mty_ref  = beat_mty;
            trim_mty = beat_mty;
            for (int b = 0; b < DATA_BYTES; b++) begin
                automatic int idx = beat * DATA_BYTES + b;
                automatic byte val = (idx < data_in.size()) ? data_in[idx] : 8'h00;
                data_ref[b] = val;
                // Zero-mask the trailing beat_mty bytes, mirroring the
                // masking packet_crc_tx/rx perform before crc_accum.
                data_padded[b] = (b >= DATA_BYTES - beat_mty) ? 8'h00 : val;
            end
            if (is_last) begin
                #1ns; // let comb paths settle
                ref_crc_out    = crc_ref_accum;
                trim_crc_out   = trim_crc;
                trim_check_out = trim_check;
            end
            @(posedge clk);
        end
        @(negedge clk);
        en = 1'b0;
        mty_ref  = '0;
        trim_mty = '0;
    endtask

    task automatic packet_reset();
        @(negedge clk);
        srst = 1'b1;
        @(posedge clk);
        @(negedge clk);
        srst = 1'b0;
    endtask

    function automatic CRC_T reference_crc(byte data_in[]);
        return crc_verif_pkg::calculate(
            WIDTH, CONFIG.POLY, CONFIG.INIT, CONFIG.REFIN, CONFIG.REFOUT, CONFIG.XOROUT, data_in
        );
    endfunction

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN

        // Full beats only (mty=0 throughout): crc_trim must be a no-op.
        `SVTEST(full_beats_noop)
            byte rand_data[];
            CRC_T ref_crc, trim_crc_out;
            logic chk;

            random_bytes(DATA_BYTES * 3, rand_data);
            feed_packet(rand_data, ref_crc, trim_crc_out, chk);

            `FAIL_IF_LOG(trim_crc_out !== ref_crc,
                $sformatf("full_beats_noop: trim=0x%08x, ref_accum=0x%08x", trim_crc_out, ref_crc));
        `SVTEST_END

        // Partial last beat, every possible mty value in [1, DATA_BYTES-1]:
        // crc_trim applied to the zero-padded accumulation must match
        // crc_accum driven with the real mty directly.
        `SVTEST(partial_beat_matches_accum)
            for (int m = 1; m < DATA_BYTES; m++) begin
                byte rand_data[];
                CRC_T ref_crc, trim_crc_out;
                logic chk;

                random_bytes(DATA_BYTES * 2 + (DATA_BYTES - m), rand_data);
                feed_packet(rand_data, ref_crc, trim_crc_out, chk);

                `FAIL_IF_LOG(trim_crc_out !== ref_crc,
                    $sformatf("partial_beat_matches_accum: mty=%0d trim=0x%08x, ref_accum=0x%08x", m, trim_crc_out, ref_crc));

                packet_reset();
            end
        `SVTEST_END

        // Single partial beat (DATA_BYTES < full beat), compared directly
        // against the crc_verif_pkg software reference model.
        `SVTEST(partial_beat_matches_reference)
            byte rand_data[];
            CRC_T expected, ref_crc, trim_crc_out;
            logic chk;

            random_bytes(DATA_BYTES > 1 ? DATA_BYTES - 1 : 1, rand_data);
            expected = reference_crc(rand_data);
            feed_packet(rand_data, ref_crc, trim_crc_out, chk);

            `FAIL_IF_LOG(trim_crc_out !== expected,
                $sformatf("partial_beat_matches_reference: got 0x%08x, expected 0x%08x", trim_crc_out, expected));
        `SVTEST_END

        // check output: feed message + correct FCS through the padded/trim
        // path; trim_check must assert. Corrupting the FCS must deassert it.
        `SVTEST(check_output)
            byte msg[];
            byte fcs_bytes[];
            byte full_pkt[];
            byte bad_pkt[];
            CRC_T fcs, ref_crc, trim_crc_out;
            logic chk;

            random_bytes(DATA_BYTES * 2 + 1, msg);
            fcs = reference_crc(msg);

            fcs_bytes = new[CONFIG.WIDTH / 8];
            for (int i = 0; i < CONFIG.WIDTH / 8; i++) begin
                automatic int byte_idx = CONFIG.REFOUT ? i : (CONFIG.WIDTH / 8 - 1 - i);
                fcs_bytes[i] = fcs[8*byte_idx +: 8];
            end

            full_pkt = new[msg.size() + fcs_bytes.size()];
            foreach (msg[i])       full_pkt[i]              = msg[i];
            foreach (fcs_bytes[i]) full_pkt[msg.size() + i] = fcs_bytes[i];

            feed_packet(full_pkt, ref_crc, trim_crc_out, chk);
            `FAIL_IF_LOG(!chk,
                $sformatf("check_output: check not asserted for valid message+FCS (crc=0x%08x)", trim_crc_out));

            bad_pkt = full_pkt;
            bad_pkt[msg.size()] ^= 8'hff;
            packet_reset();
            feed_packet(bad_pkt, ref_crc, trim_crc_out, chk);
            `FAIL_IF_LOG(chk,
                $sformatf("check_output: check asserted for corrupted FCS (crc=0x%08x)", trim_crc_out));
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : crc_trim_unit_test


// ============================================================
// Boilerplate wrapper — mirrors the pattern in crc_accum_unit_test.sv
// ============================================================
`define CRC_TRIM_UNIT_TEST(CFG, NM, BYTES)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  crc_trim_unit_test #(.CONFIG(CFG), .NAME(NM), .DATA_BYTES(BYTES)) test();\
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

// CRC-32/ISO-HDLC — wide bus matching the QDMA C2H / packet_crc use case
module crc32_iso_hdlc_trim_x64_unit_test;
`CRC_TRIM_UNIT_TEST(crc_pkg::CRC32_ISO_HDLC, "crc32_iso_hdlc", 64)
endmodule

// CRC-32/BZIP2 — non-reflected (REFIN=0, REFOUT=0), narrower bus
module crc32_bzip2_trim_x8_unit_test;
`CRC_TRIM_UNIT_TEST(crc_pkg::CRC32_BZIP2, "crc32_bzip2", 8)
endmodule

// CRC-8 — narrow CRC width
module crc8_trim_x8_unit_test;
`CRC_TRIM_UNIT_TEST(crc_pkg::CRC8, "crc8", 8)
endmodule
