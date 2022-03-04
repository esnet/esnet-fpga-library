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

module crc_serial_unit_test
#(
    parameter crc_pkg::crc_spec_t CRC_SPEC = crc_pkg::DEFAULT_CRC
) (
);
    import svunit_pkg::svunit_testcase;

    parameter int WIDTH = CRC_SPEC.cfg.WIDTH;

    string name = {CRC_SPEC.shortname, "_serial_ut"};

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
    logic             data;
    CRC_T             crc;
    logic             check;

    crc_serial #(CRC_SPEC.cfg) UUT (.*);

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
            CRC_T check_crc = CRC_SPEC.cfg.CHECK;
            CRC_T crc_out;

            // Get check data
            string_to_bytes(crc_pkg::CHECK_STRING, check_data);

            // Calculate CRC
            calculate_crc(check_data, crc_out);

            `FAIL_IF_LOG(crc_out != check_crc,
                $sformatf("Calculated CRC (0x%x) does not match expected CRC (0x%x).", crc, check_crc)
            );

        `SVTEST_END

        `SVTEST(ascii_check)
            byte check_data[];
            CRC_T good_crc = CRC_SPEC.cfg.CHECK;
            bit  crc_error;

            // Get check data
            string_to_bytes(crc_pkg::CHECK_STRING, check_data);

            // Check CRC
            check_crc(check_data, good_crc, crc_error);

            // Expect success
            `FAIL_IF_LOG((crc_error == 1), "CRC check failed. Expected success, got error.");

        `SVTEST_END

        `SVTEST(ascii_check_error)
            byte check_data[];
            int bit_error_idx = $urandom_range(0,WIDTH-1);
            CRC_T bad_crc = CRC_SPEC.cfg.CHECK ^ (1 << bit_error_idx);
            bit crc_error;

            // Get check data
            string_to_bytes(crc_pkg::CHECK_STRING, check_data);

            // Check CRC
            check_crc(check_data, bad_crc, crc_error);

            // Expect error
            `FAIL_IF_LOG((crc_error == 0), "CRC check failed. Expected error, got success.");

        `SVTEST_END

    `SVUNIT_TESTS_END

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Functions
    //===================================
    function void string_to_bytes(input string input_string, output byte bytes[]);
        bytes = new[input_string.len()];
        foreach (input_string[idx]) begin
            bytes[idx] = input_string[idx];
        end
        return;
    endfunction

    //===================================
    // Tasks
    //===================================
    task calculate_crc (input byte data_in[], output CRC_T crc_out);
        en = 1'b1;
        // Feed input message into CRC, one bit at a time
        foreach (data_in[byte_idx]) begin
            for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
                // Account for input byte reflection
                if (CRC_SPEC.cfg.REFIN) data = data_in[byte_idx][bit_idx];
                else                   data = data_in[byte_idx][8-bit_idx-1];
                @(posedge clk);
            end
        end
        crc_out = crc;
        en = 1'b0;
    endtask

    task check_crc (input byte data_in[], input CRC_T crc_in, output bit crc_error);
      localparam int CRC_BYTES = WIDTH%8 == 0 ? WIDTH/8 : WIDTH/8 + 1;
      automatic byte crc_bytes[];
      automatic CRC_T crc_out;

      // Feed CRC into calculation LSb-first where specified in implementation spec
      if (CRC_SPEC.cfg.REFIN) crc_bytes = {<< 8 {crc_in}};
      else                    crc_bytes = {>> 8 {crc_in}};

      // Calculate CRC over data and check CRC
      calculate_crc(data_in, crc_out);
      calculate_crc(crc_bytes, crc_out);

      // 'Check' bit is asserted at end of calculation where check CRC matches expected CRC
      crc_error = !check;

    endtask


endmodule : crc_serial_unit_test

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific CRC configuration in a way
//  that maintains SVUnit compatibility
`define CRC_SERIAL_UNIT_TEST(CONFIG)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  crc_serial_unit_test #(.CRC_SPEC(``CONFIG)) test();\
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
module crc8_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC8)
endmodule

// CRC-16/CDMA2000
module crc16_cdma2000_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC16_CDMA2000)
endmodule

// CRC-16/KERMIT
module crc16_kermit_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC16_KERMIT)
endmodule

// CRC-16/USB
module crc16_usb_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC16_USB)
endmodule

// CRC-16/XMODEM
module crc16_xmodem_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC16_XMODEM)
endmodule

// CRC-16/LTE
module crc16_lte_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC16_LTE)
endmodule

// CRC-24/INTERLAKEN
module crc24_interlaken_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC24_INTERLAKEN)
endmodule

// CRC-32
module crc32_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32)
endmodule

// CRC-32/BZIP-2
module crc32_bzip2_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_BZIP2)
endmodule

// CRC-32/CKSUM
module crc32_cksum_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_CKSUM)
endmodule

// CRC-32/ISO-HDLC
module crc32_iso_hdlc_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_ISO_HDLC)
endmodule

// CRC-32/ISCSI
module crc32_iscsi_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_ISCSI)
endmodule

// CRC-32/INTERLAKEN
module crc32_interlaken_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_INTERLAKEN)
endmodule

// CRC-32/AIXM
module crc32_aixm_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_AIXM)
endmodule

// CRC-32/BASE91_D
module crc32_base91_d_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_BASE91_D)
endmodule

// CRC-32/AUTOSAR
module crc32_autosar_serial_unit_test;
`CRC_SERIAL_UNIT_TEST(crc_pkg::CRC32_AUTOSAR)
endmodule
