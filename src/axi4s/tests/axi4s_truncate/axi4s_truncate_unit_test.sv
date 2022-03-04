`include "svunit_defines.svh"

module axi4s_truncate_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axi4s_truncate_ut";
    svunit_testcase svunit_ut;

    //===================================
    // DUTs 
    //===================================
    logic clk;
    logic rstn;

    initial clk = 1'b0;
    always #10ns clk = ~clk;    

    axi4s_intf axis_in ();
    axi4s_intf axis_out();

    axi4s_truncate axi4s_truncate(
      .rx_axis(axis_in),
      .tx_axis(axis_out)
    );

    always @(posedge axis_in.aclk) begin
       $display("axis_in  :tr=%b tv=%b tl=%b sop=%b td=%h",axis_in.tready,axis_in.tvalid,axis_in.tlast,axis_in.sop,axis_in.tdata[31:0]);
    end
   
    always @(posedge axis_out.aclk) begin
       $display("axis_out :tr=%b tv=%b tl=%b sop=%b td=%h",axis_out.tready,axis_out.tvalid,axis_out.tlast,axis_out.sop,axis_out.tdata[31:0]);
    end   
   
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
       $display("Setting up");
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
      `SVTEST(truncate_test)

   $display("Starting ax4s_truncate test .. ");
   
   rstn = 1;
   axis_in.tready = 1;
   
   @(posedge clk);
   rstn <= 0;
   @(posedge clk);
   rstn <= 1;
   @(posedge clk);
   write_axis(512'hDEC0FFEE,0);
   write_axis(512'hDEADBEEF,1);
   write_axis(512'hC0C0FADE,1);   

      `SVTEST_END

    `SVUNIT_TESTS_END

      task write_axis(logic [511:0] data , tlast);

	 while (axis_in.tready != 1) @(posedge clk);

	 axis_in.tdata  <= data;
	 axis_in.tvalid <= '1;
	 axis_in.tlast  <= tlast;
	 axis_in.tkeep  <= '1;
	    
	 axis_in.tid    <= '0;
	 axis_in.tdest  <= '0;
	 axis_in.tuser  <= '0;

//	 $display ("   Writing .. %h",data);	    
	 
	 @(posedge clk);
	 
      endtask

	 
endmodule
