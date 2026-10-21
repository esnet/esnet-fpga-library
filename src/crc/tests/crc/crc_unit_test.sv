`include "svunit_defines.svh"

// =========================================================================
// crc_unit_test
//
// Tests:
//   1. check_value        — catalogue check string produces CHECK value
//   2. random_reference   — random data matches crc_verif_pkg reference
//   3. en_hold            — output holds when en=0
//   4. srst_clears        — srst clears output register
// =========================================================================
module crc_unit_test
#(
    parameter crc_pkg::crc_config_t CONFIG = crc_pkg::DEFAULT_CRC,
    parameter string NAME = "crc",
    parameter int DATA_BYTES = 4
) (
);
    import svunit_pkg::svunit_testcase;
    import crc_pkg::*;

    parameter int WIDTH = CONFIG.WIDTH;
    string name = {NAME, "_ut"};
    svunit_testcase svunit_ut;

    typedef bit[WIDTH-1:0] CRC_T;

    // UUT
    logic clk;
    logic srst;
    logic en;
    logic [0:DATA_BYTES-1][7:0] data;
    CRC_T crc;

    crc #(CONFIG, DATA_BYTES) UUT (.*);

    `SVUNIT_CLK_GEN(clk, 5ns);

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        @(negedge clk);
        srst = 1'b1;
        en   = 1'b0;
        data = '0;
        repeat (4) @(posedge clk);
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

    // Feed one DATA_BYTES-wide beat and return the registered CRC one cycle later.
    task automatic drive_beat(input byte d[], output CRC_T crc_out);
        @(negedge clk);
        en = 1'b1;
        for (int i = 0; i < DATA_BYTES; i++)
            data[i] = (i < d.size()) ? d[i] : 8'h00;
        @(posedge clk);
        @(negedge clk);
        en = 1'b0;
        @(posedge clk);   // one-cycle registered latency
        crc_out = crc;
    endtask

    function automatic CRC_T reference_crc(byte d[]);
        return crc_verif_pkg::calculate(
            WIDTH,
            CONFIG.POLY,
            CONFIG.INIT,
            CONFIG.REFIN,
            CONFIG.REFOUT,
            CONFIG.XOROUT,
            d
        );
    endfunction

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN

        // Catalogue check string produces the expected CHECK value when DATA_BYTES==9.
        // For other widths the bus is zero-padded; expected comes from the reference model.
        `SVTEST(check_value)
            byte check_data[];
            byte padded[];
            CRC_T expected;
            CRC_T got;

            string_to_bytes(crc_pkg::CHECK_STRING, check_data);

            // Build the DATA_BYTES-wide padded input: check string at the start,
            // trailing zeros if DATA_BYTES > 9, or truncated if DATA_BYTES < 9.
            padded = new[DATA_BYTES];
            for (int i = 0; i < DATA_BYTES; i++)
                padded[i] = (i < check_data.size()) ? check_data[i] : 8'h00;

            expected = reference_crc(padded);
            drive_beat(padded, got);
            `FAIL_IF_LOG(got !== expected,
                $sformatf("check_value: got 0x%0x, expected 0x%0x", got, expected));

            // When the bus is exactly 9 bytes, result must also equal the catalogue CHECK.
            if (DATA_BYTES == crc_pkg::CHECK_STRING_CHARS) begin
                `FAIL_IF_LOG(got !== CRC_T'(CONFIG.CHECK),
                    $sformatf("check_value (CHECK): got 0x%0x, expected 0x%0x",
                              got, CONFIG.CHECK));
            end
        `SVTEST_END

        // Random data must match the software reference model.
        `SVTEST(random_reference)
            byte rand_data[];
            CRC_T expected;
            CRC_T got;

            random_bytes(DATA_BYTES, rand_data);
            expected = reference_crc(rand_data);
            drive_beat(rand_data, got);
            `FAIL_IF_LOG(got !== expected,
                $sformatf("random_reference: got 0x%0x, expected 0x%0x", got, expected));
        `SVTEST_END

        // Output register holds its value when en=0.
        `SVTEST(en_hold)
            byte rand_data[];
            CRC_T first;
            CRC_T held;

            random_bytes(DATA_BYTES, rand_data);
            drive_beat(rand_data, first);

            // Keep en=0 for several cycles and verify crc is unchanged
            repeat (4) @(posedge clk);
            held = crc;
            `FAIL_IF_LOG(held !== first,
                $sformatf("en_hold: output changed to 0x%0x, expected 0x%0x", held, first));
        `SVTEST_END

        // srst clears the output register to 0.
        `SVTEST(srst_clears)
            byte rand_data[];
            CRC_T got;

            // Compute a non-zero CRC first
            random_bytes(DATA_BYTES, rand_data);
            drive_beat(rand_data, got);

            // Assert srst; output should clear
            @(negedge clk);
            srst = 1'b1;
            @(posedge clk);
            @(negedge clk);
            srst = 1'b0;
            got = crc;
            `FAIL_IF_LOG(got !== '0,
                $sformatf("srst_clears: output is 0x%0x after reset, expected 0", got));
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : crc_unit_test


// ============================================================
// Boilerplate wrapper
// ============================================================
`define CRC_UNIT_TEST(CFG, NM, BYTES)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  crc_unit_test #(.CONFIG(CFG), .NAME(NM), .DATA_BYTES(BYTES)) test();\
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

// Narrow path (DATA_BYTES <= 4): exercises g__narrow_crc generate block
module crc32_x1_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32, "crc32", 1)
endmodule

module crc32_x4_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32, "crc32", 4)
endmodule

// Wide path (DATA_BYTES > 4): exercises g__wide_crc generate block
module crc32_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32, "crc32", 9)
endmodule

module crc32_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32, "crc32", 16)
endmodule

// Non-reflected (REFIN=0, REFOUT=0)
module crc32_bzip2_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_BZIP2, "crc32_bzip2", 9)
endmodule

// CRC-8 — narrowest width
module crc8_x1_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC8, "crc8", 1)
endmodule

module crc8_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC8, "crc8", 9)
endmodule

// CRC-16
module crc16_kermit_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_KERMIT, "crc16_kermit", 9)
endmodule

module crc16_xmodem_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_XMODEM, "crc16_xmodem", 9)
endmodule

// CRC-24
module crc24_interlaken_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC24_INTERLAKEN, "crc24_interlaken", 9)
endmodule

// CRC-32/ISO-HDLC (= CRC32 alias — confirms alias config identical)
module crc32_iso_hdlc_x64_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_ISO_HDLC, "crc32_iso_hdlc", 64)
endmodule
