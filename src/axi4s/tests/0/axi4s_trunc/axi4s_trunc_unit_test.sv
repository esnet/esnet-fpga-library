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
    logic srst;

    logic rstn;

    `SVUNIT_CLK_GEN(clk, 10ns);

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
    axi4s_trunc #() DUT (.*);

    assign srst = !rstn;

    // monitor for tdata==0 when tkeep==0
    always @(negedge axi4s_out.aclk)  if (axi4s_out.tvalid && axi4s_out.tready)
       for (int i=0; i<DATA_BYTE_WID; i++)
          `FAIL_IF_LOG( ((axi4s_out.tkeep[i] == 1'b0) && (axi4s_out.tdata[i] != '0)),
                        $sformatf("FAIL!!! tkeep=0 but packet bytes NOT zeroed at byte_idx: 0x%0h (d:%0d)", i, i) )

    // monitor for zeroed axi4s signals when tvalid==0
    always @(negedge axi4s_out.aclk)  if (!axi4s_out.tvalid)
          `FAIL_IF_LOG( ((axi4s_out.tdata != '0) && (axi4s_out.tkeep != '0) && (axi4s_out.tlast != 1'b0) &&
                         (axi4s_out.tid   != '0) && (axi4s_out.tdest != '0) && (axi4s_out.tuser != '0) ),
                        $sformatf("FAIL!!! tvalid=0 but axi4s signals NOT all zeroes.") )

    //===================================
    // Import common testcase tasks
    //=================================== 
    `include "../axi4s_trunc/tasks.svh"

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axis_driver  = new();
        axis_monitor = new();

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
          exp_pcap = pcap_pkg::read_pcap(filename);

          force axi4s_out.tready = '1;

          for (length=64; length<256; length = length + 3) begin
          $display("Length: ", length);
             run_pkt_test(.size(length)); 
          end
      `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
