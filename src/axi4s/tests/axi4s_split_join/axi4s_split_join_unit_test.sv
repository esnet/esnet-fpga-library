`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout
//===================================
`define SVUNIT_TIMEOUT 50us

module axi4s_split_join_unit_test;
    import svunit_pkg::svunit_testcase;
    import axi4s_pkg::*;
    import axi4s_verif_pkg::*;
   
    string name = "axi4s_split_join_ut";
    svunit_testcase svunit_ut;

    //===================================
    // DUT and testbench logic 
    //===================================
    logic clk;
    logic rstn;

    initial clk = 1'b0;
    always #10ns clk <= ~clk;    

    localparam BIGENDIAN = 1;
//    localparam DATA_BYTE_WID = 64;
    localparam DATA_BYTE_WID = 16;

    // axi4s driver and monitor instantiations
    axi4s_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_driver;
    axi4s_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_monitor;

    // local axi4s interface instantiations
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_in ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_out();

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) _axi4s_hdr_in();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_in();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_out();

    assign axi4s_in.aclk = clk;
    assign axi4s_in.aresetn = rstn;
    assign axi4s_hdr_in.aclk = clk;
    assign axi4s_hdr_in.aresetn = rstn;
    

    // axi4s_split_join instantiation.
    int hdr_length;
    axi4s_split_join #(
      .BIGENDIAN (BIGENDIAN)
    ) DUT (
      .axi4s_in      (axi4s_in),
      .axi4s_out     (axi4s_out),
      .axi4s_hdr_in  (axi4s_hdr_in),
      .axi4s_hdr_out (axi4s_hdr_out),
      .hdr_length    (hdr_length)
    );

    // instantiate and terminate unused AXI-L interfaces.
    axi4l_intf axil_to_probe ();
    axi4l_intf axil_to_ovfl  ();
    axi4l_intf axil_to_fifo  ();

    axi4l_intf_controller_term axi4l_to_probe_term (.axi4l_if (axil_to_probe));
    axi4l_intf_controller_term axi4l_to_ovfl_term  (.axi4l_if (axil_to_ovfl));
    axi4l_intf_controller_term axi4l_to_fifo_term  (.axi4l_if (axil_to_fifo));

    // header fifo instantiation.
    axi4s_pkt_fifo_sync #(
       .FIFO_DEPTH(128)
    ) fifo_0 (
       .axi4s_in       (axi4s_hdr_out),
       .axi4s_out      (_axi4s_hdr_in),
       .axil_to_probe  (axil_to_probe),
       .axil_to_ovfl   (axil_to_ovfl),
       .axil_if        (axil_to_fifo)
    );

    logic [DATA_BYTE_WID-1:0] tkeep;
    initial tkeep = '1;
    always @(posedge _axi4s_hdr_in.aclk) if (_axi4s_hdr_in.tvalid && _axi4s_hdr_in.tlast && _axi4s_hdr_in.tready) tkeep <= BIGENDIAN ? tkeep << 0 : tkeep >> 0;

    assign axi4s_hdr_in.aclk   = _axi4s_hdr_in.aclk;
    assign axi4s_hdr_in.aresetn= _axi4s_hdr_in.aresetn;
    assign axi4s_hdr_in.tvalid = _axi4s_hdr_in.tvalid;
    assign axi4s_hdr_in.tdata  = _axi4s_hdr_in.tdata;
    assign axi4s_hdr_in.tkeep  = _axi4s_hdr_in.tlast ? tkeep: _axi4s_hdr_in.tkeep;
    assign axi4s_hdr_in.tlast  = _axi4s_hdr_in.tlast;
    assign axi4s_hdr_in.tid    = _axi4s_hdr_in.tid;
    assign axi4s_hdr_in.tdest  = _axi4s_hdr_in.tdest;
    assign axi4s_hdr_in.tuser  = _axi4s_hdr_in.tuser;

    assign _axi4s_hdr_in.tready = axi4s_hdr_in.tready;


    //===================================
    // Import common testcase tasks
    //=================================== 
    `include "../../tests/axi4s_split_join/tasks.svh"

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axis_driver  = new(.BIGENDIAN (BIGENDIAN));  // Configure for little-endian
        axis_monitor = new(.BIGENDIAN (BIGENDIAN));

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

      `SVTEST(split_test_hdr_len_16)
          hdr_length = 16;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_32)
          hdr_length = 32;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_48)
          hdr_length = 48;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_64)
          hdr_length = 64;
          run_pkt_test();
      `SVTEST_END

/*
      `SVTEST(split_test_hdr_len_64)
          hdr_length = 64;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_128)
          hdr_length = 128;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_192)
          hdr_length = 192;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_256)
          hdr_length = 256;
          run_pkt_test();
      `SVTEST_END
*/

    `SVUNIT_TESTS_END

endmodule
