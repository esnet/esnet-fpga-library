// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

`include "svunit_defines.svh"

module crc_unit_test
#(
    parameter crc_pkg::crc_spec_t CRC_SPEC = crc_pkg::DEFAULT_CRC,
    parameter int DATA_BYTES
) (
);
    import svunit_pkg::svunit_testcase;

    parameter int WIDTH = CRC_SPEC.cfg.WIDTH;
    parameter int CRC_LATENCY = 1;

    string name = {CRC_SPEC.shortname, "_ut"};

    svunit_testcase svunit_ut;

    // Typedefs
    typedef bit[CRC_SPEC.cfg.WIDTH-1:0] CRC_T;


    //===================================
    // This is the UUT that we're
    // running the Unit Tests on
    //===================================
    logic             clk;
    logic             srst;
    logic             en;
    logic [0:DATA_BYTES-1][7:0] data;
    CRC_T             crc;
    logic             check;

    crc #(CRC_SPEC.cfg, DATA_BYTES) UUT (.*);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */
        srst = 1'b1;
        repeat (100) @(posedge clk);
        srst = 1'b0;
        en = 1'b0;
        data = 1'b0;
        @(posedge clk);

    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
        /* Place Teardown Code Here */

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
    `SVUNIT_TESTS_BEGIN

        `SVTEST(ascii_generate)
            byte check_data[];
            CRC_T check_crc;
            CRC_T crc_out;
            bit crc_ok;

            check_crc = get_check_crc();
            `INFO($sformatf("Check CRC: %x", check_crc));
            
            // Get check data
            string_to_bytes(crc_pkg::CHECK_STRING, check_data);

            // Calculate CRC
            calculate_crc(check_data, crc_out, crc_ok);

            `FAIL_IF_LOG(crc_out != check_crc,
                $sformatf("Calculated CRC (0x%x) does not match expected CRC (0x%x).", crc, check_crc)
            );

        `SVTEST_END

    `SVUNIT_TESTS_END

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Functions
    //===================================
    function CRC_T calculate(input byte data[]);
        byte data_zero_padded [];

        // Check that data width is less than or equal to configured data width
        assert(data.size() <= DATA_BYTES);

        // Zero-pad data (if necessary)
        zero_pad_data (data, data_zero_padded);

        // Calculate CRC
        return crc_verif_pkg::calculate(
            WIDTH,
            CRC_SPEC.cfg.POLY,
            CRC_SPEC.cfg.INIT,
            CRC_SPEC.cfg.REFIN,
            CRC_SPEC.cfg.REFOUT,
            CRC_SPEC.cfg.XOROUT,
            data_zero_padded
        );
    endfunction

    function void string_to_bytes(input string input_string, output byte bytes[]);
        bytes = new[input_string.len()];
        foreach (input_string[idx]) begin
            bytes[idx] = input_string[idx];
        end
        return;
    endfunction

    function CRC_T get_check_crc();
        byte check_bytes [];
        string_to_bytes(crc_pkg::CHECK_STRING, check_bytes);
        return calculate(check_bytes);
    endfunction

    function void zero_pad_data(input byte data[], output byte data_zero_padded []);
        const automatic int DATA_IN_BYTES = data.size();
        const automatic int PAD_BYTES = DATA_BYTES > DATA_IN_BYTES ? DATA_BYTES-DATA_IN_BYTES : 0;
        byte data_padded [$] = data;
        for (int i = 0; i < PAD_BYTES; i++) begin
            data_padded.push_front(8'h00);
        end
        data_zero_padded = data_padded;
    endfunction

    //===================================
    // Tasks
    //===================================
    task calculate_crc (input byte data_in[], output CRC_T crc_out, output bit check);
        automatic byte data_in_padded [];

        // Zero-pad data (if necessary)
        zero_pad_data(data_in, data_in_padded);

        // Feed entire input message into CRC
        en = 1'b1;
        for (int byte_idx = 0; byte_idx < DATA_BYTES; byte_idx++) data[byte_idx] = data_in_padded[byte_idx];
        @(posedge clk);
        repeat (CRC_LATENCY) @(posedge clk);
        crc_out = crc;

        check = (crc_out == calculate(data_in));
    endtask

endmodule : crc_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific CRC configuration in a way
//  that maintains SVUnit compatibility
`define CRC_UNIT_TEST(CONFIG,BYTES)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  crc_unit_test #(.CRC_SPEC(``CONFIG), .DATA_BYTES(``BYTES)) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask

// --------------------------------------------
// CRC-specific unit tests
// --------------------------------------------


// CRC-8
module crc8_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC8, 9)
endmodule

module crc8_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC8, 16)
endmodule

// CRC-16/CDMA2000
module crc16_cdma2000_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_CDMA2000, 9)
endmodule

module crc16_cdma2000_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_CDMA2000, 16)
endmodule

// CRC-16/KERMIT
module crc16_kermit_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_KERMIT, 9)
endmodule

module crc16_kermit_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_KERMIT, 16)
endmodule

// CRC-16/USB
module crc16_usb_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_USB, 9)
endmodule

module crc16_usb_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_USB, 16)
endmodule

// CRC-16/XMODEM
module crc16_xmodem_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_XMODEM, 9)
endmodule

module crc16_xmodem_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_XMODEM, 16)
endmodule

// CRC-16/LTE
module crc16_lte_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_LTE, 9)
endmodule

module crc16_lte_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC16_LTE, 16)
endmodule

// CRC-24/INTERLAKEN
module crc24_interlaken_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC24_INTERLAKEN, 9)
endmodule

module crc24_interlaken_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC24_INTERLAKEN, 16)
endmodule

// CRC-32
module crc32_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32, 9)
endmodule

module crc32_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32, 16)
endmodule

// CRC-32/BZIP-2
module crc32_bzip2_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_BZIP2, 9)
endmodule

module crc32_bzip2_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_BZIP2, 16)
endmodule

// CRC-32/CKSUM
module crc32_cksum_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_CKSUM, 9)
endmodule

module crc32_cksum_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_CKSUM, 16)
endmodule

// CRC-32/ISO-HDLC
module crc32_iso_hdlc_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_ISO_HDLC, 9)
endmodule

module crc32_iso_hdlc_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_ISO_HDLC, 16)
endmodule

// CRC-32/ISCSI
module crc32_iscsi_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_ISCSI, 9)
endmodule

module crc32_iscsi_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_ISCSI, 16)
endmodule

// CRC-32/INTERLAKEN
module crc32_interlaken_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_INTERLAKEN, 9)
endmodule

module crc32_interlaken_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_INTERLAKEN, 16)
endmodule

// CRC-32/AIXM
module crc32_aixm_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_AIXM, 9)
endmodule

module crc32_aixm_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_AIXM, 16)
endmodule

// CRC-32/BASE91-D
module crc32_base91_d_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_BASE91_D, 9)
endmodule

module crc32_base91_d_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_BASE91_D, 16)
endmodule

// CRC-32/AUTOSAR
module crc32_autosar_x9_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_AUTOSAR, 9)
endmodule

module crc32_autosar_x16_unit_test;
`CRC_UNIT_TEST(crc_pkg::CRC32_AUTOSAR, 16)
endmodule
