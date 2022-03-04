`include "svunit_defines.svh"

module sync_ctr_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_cnt_ut";
    svunit_testcase svunit_ut;
   
    //===================================
    // Test parameters and variables
    //===================================

    localparam DATA_WID = 8;
    localparam STAGES   = 3;

    typedef logic [DATA_WID-1:0] cnt_t;
    localparam cnt_t RST_VALUE = { DATA_WID/8 {8'h5c} };

    int clk_ratio      = 1;
    int clk_in_period  = 10;
    int clk_out_period = 10;

    logic clk_in, clk_out;
    logic rst_in, rst_out;

    int ones_count = 0;

    cnt_t  cnt_in;
    cnt_t  cnt_out_bin,  cnt_out_bin_exp;
    cnt_t  cnt_out_gray, cnt_out_gray_prev;

   
    //===================================
    // DUTs (multiple instantiations present to test various parameterizations)
    //===================================

    // sync_ctr - decoded output (binary)
    sync_ctr #(
        .STAGES       ( STAGES ),
        .DATA_T       ( cnt_t ),
        .RST_VALUE    ( RST_VALUE ),
        .DECODE_OUT   ( 1 )
    ) dut_sync_ctr_bin_out (
        .clk_in       ( clk_in  ),
        .rst_in       ( rst_in  ),
        .cnt_in       ( cnt_in  ),
        .clk_out      ( clk_out ),
        .rst_out      ( rst_out ),
        .cnt_out      ( cnt_out_bin )
    );

    // sync_ctr - undecoded output (gray)
    sync_ctr #(
        .STAGES       ( STAGES ),
        .DATA_T       ( cnt_t ),
        .RST_VALUE    ( RST_VALUE ),
        .DECODE_OUT   ( 0 )
    ) dut_sync_ctr_gray_out (
        .clk_in       ( clk_in  ),
        .rst_in       ( rst_in  ),
        .cnt_in       ( cnt_in  ),
        .clk_out      ( clk_out ),
        .rst_out      ( rst_out ),
        .cnt_out      ( cnt_out_gray )
    );


    //===================================
    // Stimulus generation (clks, rst, cnt_in)
    //===================================
    initial clk_out = 1'b0;
    always #(clk_out_period) clk_out = ~clk_out;

    initial clk_in = 1'b0;
    always #(clk_in_period)  clk_in  = ~clk_in;

    task reset();
        rst_out = 1'b1; 
        rst_in  = 1'b1;

        repeat (8) @(posedge clk_out); 
        rst_out = 1'b0;

        @(posedge clk_in); 
        rst_in  = 1'b0;

    endtask

    always @(posedge clk_in) cnt_in  = rst_in ? 0 : cnt_in+1;


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

        reset();
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

        `SVTEST(rst_value)
            force cnt_in = RST_VALUE;

            repeat (STAGES+3) @(posedge clk_in) begin
                `FAIL_UNLESS_LOG (
                     cnt_out_bin == RST_VALUE,
                     $sformatf("Reset value mismatch. Exp: %0b, Got: %0b.", RST_VALUE, cnt_out_bin)
                );
            end
   
            release cnt_in;
        `SVTEST_END

 
        `SVTEST(gray_output)
             cnt_out_gray_prev = 0; wait (cnt_out_gray == 1);

             repeat (2**(DATA_WID+1)) @(posedge clk_out) begin
                ones_count = 0;
                for (int i=0; i<DATA_WID; i++) ones_count = ones_count + (cnt_out_gray[i] ^ cnt_out_gray_prev[i]);

                `FAIL_UNLESS_LOG ( ones_count == 1,
                      $sformatf("Gray count mismatch. Exp: %0b, Got: %0b.", 1, ones_count) );

                 cnt_out_gray_prev = cnt_out_gray;
             end
        `SVTEST_END

	  
        `SVTEST(binary_output)
             cnt_out_bin_exp = 0; wait (cnt_out_bin == 0);

             for (int i=0; i<2**(DATA_WID+1); i++) @(posedge clk_out) begin
                 cnt_out_bin_exp = i;

                `FAIL_UNLESS_LOG ( cnt_out_bin == cnt_out_bin_exp,
                      $sformatf("Binary count mismatch. Exp: %0b, Got: %0b.", cnt_out_bin_exp, cnt_out_bin) );
             end
        `SVTEST_END


        `SVTEST(slow_to_fast)
             clk_ratio = 3; clk_in_period = clk_ratio * clk_out_period;

             cnt_out_bin_exp = 0; wait (cnt_out_bin == 0);

             for (int i=0; i<2**(DATA_WID+1); i++) @(posedge clk_out) begin
                 cnt_out_bin_exp = i / clk_ratio;

                `FAIL_UNLESS_LOG ( cnt_out_bin == cnt_out_bin_exp,
                      $sformatf("Binary count mismatch. Exp: %0b, Got: %0b.", cnt_out_bin_exp, cnt_out_bin) );
             end
        `SVTEST_END


        `SVTEST(fast_to_slow)
             clk_ratio = 3; clk_out_period = clk_ratio * clk_in_period;

             cnt_out_bin_exp = 0; wait (cnt_out_bin == 0);

             for (int i=0; i<2**(DATA_WID+1); i++) @(posedge clk_out) begin
                 cnt_out_bin_exp = i * clk_ratio;

                `FAIL_UNLESS_LOG ( cnt_out_bin == cnt_out_bin_exp,
                      $sformatf("Binary count mismatch. Exp: %0b, Got: %0b.", cnt_out_bin_exp, cnt_out_bin) );
             end
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
