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
      pcap_hdr_t hdr;
      pcaprec_hdr_t record_hdr [$];
      byte pkt_data [$][$];
      read_pcap("../../pcap/test.pcap", hdr, record_hdr, pkt_data);
      print_pcap(hdr, record_hdr, pkt_data);
    `SVTEST_END

    `SVTEST(read_test_pcap_zero_length)
      pcap_hdr_t hdr;
      pcaprec_hdr_t record_hdr [$];
      byte pkt_data [$][$];
      read_pcap("../../pcap/test_zero_length.pcap", hdr, record_hdr, pkt_data);
      print_pcap(hdr, record_hdr, pkt_data);
    `SVTEST_END

  `SVUNIT_TESTS_END

endmodule
