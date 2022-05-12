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

    localparam DATA_BYTE_WID = 64;
    localparam HDR_PIPE_STAGES = 16;

    // axi4s driver and monitor instantiations
    axi4s_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_driver;
    axi4s_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_monitor;

    // local axi4s interface instantiations
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_in ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_out();

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_in();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_pipe [HDR_PIPE_STAGES] ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_out();

    assign axi4s_in.aclk = clk;
    assign axi4s_in.aresetn = rstn;
    assign axi4s_hdr_in.aclk = clk;
    assign axi4s_hdr_in.aresetn = rstn;
    

    // axi4s_split_join instantiation
    int hdr_length;
    axi4s_split_join DUT (
      .axi4s_in      (axi4s_in),
      .axi4s_out     (axi4s_out),
      .axi4s_hdr_in  (axi4s_hdr_in),
      .axi4s_hdr_out (axi4s_hdr_out),
      .hdr_length    (hdr_length)
    );

    // axi4s hdr pipeline
    generate for (genvar i = 0; i <= HDR_PIPE_STAGES; i += 1)
       if (i == 0)                    axi4s_intf_pipe axi4s_pipe (.axi4s_if_from_tx(axi4s_hdr_out),       .axi4s_if_to_rx(axi4s_hdr_pipe[0]));
       else if (i == HDR_PIPE_STAGES) axi4s_intf_pipe axi4s_pipe (.axi4s_if_from_tx(axi4s_hdr_pipe[i-1]), .axi4s_if_to_rx(axi4s_hdr_in));
       else                           axi4s_intf_pipe axi4s_pipe (.axi4s_if_from_tx(axi4s_hdr_pipe[i-1]), .axi4s_if_to_rx(axi4s_hdr_pipe[i]));
    endgenerate


    //===================================
    // Import common testcase tasks
    //=================================== 
    `include "../../tests/axi4s_split_join/tasks.svh"

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        axis_driver  = new(.BIGENDIAN(0));  // Configure for little-endian
        axis_monitor = new(.BIGENDIAN(0));  // Configure for little-endian

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

    `SVUNIT_TESTS_END

endmodule
