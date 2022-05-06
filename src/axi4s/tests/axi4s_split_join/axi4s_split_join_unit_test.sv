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

    // axi4s driver and monitor instantiations
    axi4s_driver  #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_driver;
    axi4s_monitor #(.DATA_BYTE_WID(DATA_BYTE_WID)) axis_monitor;

    // local axi4s interface instantiations
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_in ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_out();

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_in();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_out();

    assign axi4s_in.aclk = clk;
    assign axi4s_in.aresetn = rstn;
    assign axi4s_hdr_in.aclk = clk;
    assign axi4s_hdr_in.aresetn = rstn;
    


    int hdr_length;

    axi4s_split_join DUT (
      .axi4s_in      (axi4s_in),
      .axi4s_out     (axi4s_out),
      .axi4s_hdr_in  (axi4s_hdr_in),
      .axi4s_hdr_out (axi4s_hdr_out),
      .hdr_length    (hdr_length)
    );

   // buffer context signals
   logic [15:0] wr_ptr;
   logic [15:0] rd_ptr, rd_ptr_nxt;
   logic        rd_req;
   
   // wr_ptr logic
   always @(posedge axi4s_hdr_out.aclk)
      if (!axi4s_hdr_out.aresetn)                  wr_ptr <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready) wr_ptr <= wr_ptr + 1;

   // rd_ptr logic
   assign rd_req = (wr_ptr >= 20);
   assign rd_ptr_nxt = (axi4s_hdr_in.tvalid && axi4s_hdr_in.tready) ? rd_ptr + 1 : rd_ptr;

   always @(posedge axi4s_hdr_in.aclk) begin
      if (!axi4s_hdr_in.aresetn) rd_ptr <= '0;
      else                       rd_ptr <= rd_ptr_nxt;
   end


   // packet buffer instantiation
   axi4s_pkt_buffer #(
//      .ADDR_WID (15)
      .ADDR_WID (8)
   ) axi4s_pkt_buffer_0 (
      .axi4s_in      (axi4s_hdr_out),
      .axi4s_out     (axi4s_hdr_in),
      .rd_req        (rd_req),
      .rd_ptr        (rd_ptr_nxt),
      .wr_ptr        (wr_ptr)
   );


    //===================================
    // Import common testcase tasks
    //=================================== 
    `include "./tasks.svh"

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

      `SVTEST(split_test_hdr_len_1)
          hdr_length = 1;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_2)
          hdr_length = 2;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_3)
          hdr_length = 3;
          run_pkt_test();
      `SVTEST_END

      `SVTEST(split_test_hdr_len_4)
          hdr_length = 4;
          run_pkt_test();
      `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
