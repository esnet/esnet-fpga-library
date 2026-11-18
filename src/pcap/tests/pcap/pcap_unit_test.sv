`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 1ms

module pcap_unit_test;
    import svunit_pkg::svunit_testcase;
    import pcap_pkg::*;

    string name = "pcap_ut";
    svunit_testcase svunit_ut;

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

        // Header extraction preserves byte order and leaves payload untouched.
        `SVTEST(pop_global_header)
            byte data[$];
            pcap_hdr_t hdr;
            for (int i = 0; i < PCAP_HDR_BYTES; i++) data.push_back(byte'(i));
            data.push_back(8'ha5);

            hdr = pop_hdr(data);
            `FAIL_UNLESS_EQUAL(hdr.magic_number, 32'h00010203);
            `FAIL_UNLESS_EQUAL(hdr.version_major, 16'h0405);
            `FAIL_UNLESS_EQUAL(hdr.version_minor, 16'h0607);
            `FAIL_UNLESS_EQUAL(hdr.thiszone, 32'h08090a0b);
            `FAIL_UNLESS_EQUAL(hdr.sigfigs, 32'h0c0d0e0f);
            `FAIL_UNLESS_EQUAL(hdr.snaplen, 32'h10111213);
            `FAIL_UNLESS_EQUAL(hdr.network, 32'h14151617);
            `FAIL_UNLESS_EQUAL(data.size(), 1);
            `FAIL_UNLESS_EQUAL(data[0], 8'ha5);
        `SVTEST_END

        `SVTEST(pop_record_header)
            byte data[$];
            pcap_record_hdr_t hdr;
            for (int i = 0; i < PCAP_RECORD_HDR_BYTES; i++) data.push_back(byte'('h80+i));
            data.push_back(8'h5a);

            hdr = pop_record_hdr(data);
            `FAIL_UNLESS_EQUAL(hdr.ts_sec, 32'h80818283);
            `FAIL_UNLESS_EQUAL(hdr.ts_usec, 32'h84858687);
            `FAIL_UNLESS_EQUAL(hdr.incl_len, 32'h88898a8b);
            `FAIL_UNLESS_EQUAL(hdr.orig_len, 32'h8c8d8e8f);
            `FAIL_UNLESS_EQUAL(data.size(), 1);
            `FAIL_UNLESS_EQUAL(data[0], 8'h5a);
        `SVTEST_END

        // File parsing and diagnostic output.

        `SVTEST(read_test_pcap)
            pcap_t pcap;
            pcap = read_pcap("../../pcap/test.pcap");
            `FAIL_UNLESS(pcap.records.size() == 1);
            print_pcap(pcap);
        `SVTEST_END

        `SVTEST(read_test_ns_pcap)
            pcap_t pcap;
            pcap = read_pcap("../../pcap/test_ns.pcap");
            `FAIL_UNLESS(pcap.records.size() == 1);
            print_pcap(pcap);
        `SVTEST_END

        `SVTEST(read_test_pcap_zero_length)
            pcap_t pcap;
            pcap = read_pcap("../../pcap/test_zero_length.pcap");
            `FAIL_UNLESS(pcap.records.size() == 3);
            print_pcap(pcap);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
