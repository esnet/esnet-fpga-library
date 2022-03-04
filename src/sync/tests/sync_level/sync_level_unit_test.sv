`include "svunit_defines.svh"

module sync_level_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_level_ut";
    svunit_testcase svunit_ut;

    //===================================
    // DUTs (multiple instantiations present to test various parameterizations)
    //===================================
    logic clk_out;
    logic rst_out;

    // 'Bit' sync_level
    localparam RST_VALUE = 1'bx;
    logic lvl_in;
    logic lvl_out;

    sync_level    #(
        .STAGES    ( 2 ),
        .DATA_T    ( logic ),
        .RST_VALUE ( RST_VALUE )
    ) dut_sync_level (
        .lvl_in   ( lvl_in ),
        .clk_out  ( clk_out ),
        .rst_out  ( rst_out ),
        .lvl_out  ( lvl_out )
    );

    // 'Vector' sync_level
    typedef struct packed {
        logic field1;
        logic[2:0] field2;
        logic[7:0] field3;
    } vector_t;
    localparam vector_t RST_VALUE_VEC = '{field1: 1'b0, field2: 3'd6, field3: 8'haa};
    vector_t lvl_in_vec;
    vector_t lvl_out_vec;

    sync_level    #(
        .STAGES    ( 3 ),
        .DATA_T    ( vector_t ),
        .RST_VALUE ( RST_VALUE_VEC )
    ) dut_sync_level_vec (
        .lvl_in   ( lvl_in_vec ),
        .clk_out  ( clk_out ),
        .rst_out  ( rst_out ),
        .lvl_out  ( lvl_out_vec )
    );


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
            `FAIL_UNLESS_LOG (
                lvl_out === RST_VALUE,
                $sformatf("Reset value mismatch. Exp: %0b, Got: %0b.", RST_VALUE, lvl_out)
            );
        `SVTEST_END

        `SVTEST(pass_0_to_1)
            lvl_in = 1'b0;
            repeat (8) @(posedge clk_out);
            `FAIL_UNLESS_LOG(
                lvl_out === 1'b0,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b0, lvl_out)
            );
            #1ns;
            lvl_in = 1'b1;
            repeat (8) @(posedge clk_out);
            `FAIL_UNLESS_LOG(
                lvl_out === 1'b1,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b1, lvl_out)
            );
        `SVTEST_END

        `SVTEST(pass_1_to_0)
            lvl_in = 1'b1;
            repeat (8) @(posedge clk_out);
            `FAIL_UNLESS_LOG(
                lvl_out === 1'b1,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b1, lvl_out)
            );
            #1ns;
            lvl_in = 1'b0;
            repeat (8) @(posedge clk_out);
            `FAIL_UNLESS_LOG(
                lvl_out === 1'b0,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", 1'b0, lvl_out)
            );
        `SVTEST_END

        `SVTEST(rst_value_vector)
            `FAIL_UNLESS_LOG (
                lvl_out_vec === RST_VALUE_VEC,
                $sformatf("Reset value mismatch. Exp: %0b, Got: %0b.", RST_VALUE_VEC, lvl_out_vec)
            );
        `SVTEST_END

        `SVTEST(pass_vector)
            vector_t start_vec = '{field1: 1'b1, field2: 3'd3, field3: 8'hf2};
            vector_t end_vec   = '{field1: 1'b0, field2: 3'd5, field3: 8'h4d};
            lvl_in_vec = start_vec;
            repeat (8) @(posedge clk_out);
            `FAIL_UNLESS_LOG(
                lvl_out_vec === start_vec,
                $sformatf("Output value mismatch. Exp: %0x, Got: %0x.", start_vec, lvl_out_vec)
            );
            #1ns;
            lvl_in_vec = end_vec;
            repeat (8) @(posedge clk_out);
            `FAIL_UNLESS_LOG(
                lvl_out_vec === end_vec,
                $sformatf("Output value mismatch. Exp: %0b, Got: %0b.", end_vec, lvl_out_vec)
            );
        `SVTEST_END


    `SVUNIT_TESTS_END

    task reset();
        rst_out <= 1'b1;
        repeat (8) @(posedge clk_out);
        rst_out <= 1'b0;
    endtask

    initial clk_out = 1'b0;
    always #10ns clk_out = ~clk_out;

endmodule
