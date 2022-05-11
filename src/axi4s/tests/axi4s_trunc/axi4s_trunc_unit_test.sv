`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout
//===================================
`define SVUNIT_TIMEOUT 5000us

module axi4s_trunc_unit_test;
    import svunit_pkg::svunit_testcase;
    import axi4s_pkg::*;
    import axi4s_verif_pkg::*;
   
    string name = "axi4s_trunc_ut";
    svunit_testcase svunit_ut;

    //===================================
    // DUT and testbench logic 
    //===================================
    logic clk;
    logic rstn;

    initial clk = 1'b0;
    always #10ns clk <= ~clk;    

    localparam DATA_BYTE_WID = 64;

    // axi4s driver and monitor instantiations
    axi4s_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_driver;
    axi4s_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_monitor;

    // local axi4s interface instantiations
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_in ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_out();

    assign axi4s_in.aclk = clk;
    assign axi4s_in.aresetn = rstn;

    // axi4s_split_join instantiation
    int length;
    axi4s_trunc #(.BIGENDIAN(0)) DUT (  
      .axi4s_in  (axi4s_in),
      .axi4s_out (axi4s_out),
      .length    (length)
    );

    //===================================
    // Import common testcase tasks
    //=================================== 
    `include "../../tests/axi4s_trunc/tasks.svh"

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axis_driver  = new(.BIGENDIAN(0));  // Configure for little-endian
        axis_monitor = new(.BIGENDIAN(0));

        axis_driver.axis_vif  = axi4s_in;
        axis_monitor.axis_vif = axi4s_out;
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
       svunit_ut.setup();

       $display("Setting up");

       // Flush packets from pipeline
       axis_monitor.flush();

       // Put AXI-S interfaces into quiescent state
       axis_driver.idle();
       axis_monitor.idle();

       rstn = 1;
       @(posedge clk);
       rstn <= 0;
       @(posedge clk);
       rstn <= 1;
       @(posedge clk);

       repeat(100) @(posedge clk);
    endtask

    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
        /* Place Teardown Code Here */
       $display("Tearing down");       
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

      `SVTEST(trunc_test)
          debug_msg("Reading expected pcap file...");
          pcap_pkg::read_pcap(filename, exp_pcap_hdr, exp_pcap_record_hdr, exp_data);

          force axi4s_out.tready = '1;

          for (length=64; length<256; length = length + 3) begin
	     $display("Length: ", length);
             run_pkt_test(.size(length)); 
          end
      `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
