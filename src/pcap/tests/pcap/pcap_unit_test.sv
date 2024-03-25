`include "svunit_defines.svh"

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
