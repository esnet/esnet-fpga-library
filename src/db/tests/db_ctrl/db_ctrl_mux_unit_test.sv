`include "svunit_defines.svh"

module db_ctrl_mux_unit_test
#(
    parameter int NUM_IFS = 2,
    parameter type KEY_T = logic[11:0],
    parameter type VALUE_T = logic[31:0],
    parameter string DUT_NAME = "db_ctrl_intf"
) (
    output logic clk,
    output logic srst,
    db_ctrl_intf.controller db_ctrl_if_to_DUT [NUM_IFS],
    db_ctrl_intf.peripheral db_ctrl_if_from_DUT
);
    import svunit_pkg::svunit_testcase;
    import db_pkg::*;
    import db_verif_pkg::*;

    string name = {DUT_NAME, "_ut"};
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int TIMEOUT_CYCLES = 0;
    localparam int SIZE = 2**$bits(KEY_T);

    //===================================
    // Testbench
    //===================================
    int __BACKPRESSURE = 1;

    // Agent
    db_ctrl_agent #(KEY_T, VALUE_T) agent [NUM_IFS];

    // Reset
    std_reset_intf reset_if (.clk(clk));

    // DB peripheral (peripheral + storage)
    // (in absence of verification model just implement
    //  using basic peripheral with array storage)
    int strobe_cnt;
    bit strobe;

    logic init;
    logic init_done;

    db_intf #(KEY_T, VALUE_T) db_wr_if (.clk(clk));
    db_intf #(KEY_T, VALUE_T) db_rd_if (.clk(clk));
    db_intf #(KEY_T, VALUE_T) __db_wr_if (.clk(clk));
    db_intf #(KEY_T, VALUE_T) __db_rd_if (.clk(clk));

    // Peripheral
    db_peripheral #(
        .TIMEOUT_CYCLES ( TIMEOUT_CYCLES )
    ) i_db_peripheral (
        .clk       ( clk ),
        .srst      ( srst ),
        .ctrl_if   ( db_ctrl_if_from_DUT ),
        .init      ( init ),
        .init_done ( init_done ),
        .wr_if     ( db_wr_if ),
        .rd_if     ( db_rd_if )
    );

    initial strobe_cnt = 0;
    always @(posedge clk) strobe_cnt <= (strobe_cnt <= __BACKPRESSURE ? strobe_cnt + 1 : 0);

    assign strobe = (strobe_cnt == 0);

    assign __db_rd_if.req = db_rd_if.req && strobe;
    assign db_rd_if.rdy = __db_rd_if.rdy && strobe;
    assign __db_rd_if.key = db_rd_if.key;
    assign __db_rd_if.next = db_rd_if.next;
    assign db_rd_if.ack = __db_rd_if.ack;
    assign db_rd_if.error = __db_rd_if.error;
    assign db_rd_if.valid = __db_rd_if.valid;
    assign db_rd_if.value = __db_rd_if.value;
    assign db_rd_if.next_key = __db_rd_if.next_key;

    assign __db_wr_if.req = db_wr_if.req && strobe;
    assign db_wr_if.rdy = __db_wr_if.rdy && strobe;
    assign __db_wr_if.key = db_wr_if.key;
    assign __db_wr_if.next = db_wr_if.next;
    assign __db_wr_if.valid = db_wr_if.valid;
    assign __db_wr_if.value = db_wr_if.value;
    assign db_wr_if.ack = __db_wr_if.ack;
    assign db_wr_if.error = __db_wr_if.error;
    assign db_wr_if.next_key = __db_wr_if.next_key;

    // Database store
    db_store_array #(
        .KEY_T     ( KEY_T ),
        .VALUE_T   ( VALUE_T )
    ) i_db_store_array (
        .clk       ( clk ),
        .srst      ( srst ),
        .init      ( init ),
        .init_done ( init_done ),
        .db_wr_if  ( __db_wr_if ),
        .db_rd_if  ( __db_rd_if )
    );

    // Assign clock (250MHz)
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Assign reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        for (int i = 0; i < NUM_IFS; i++) begin
            agent[i] = new($sformatf("db_agent[%e]", i), SIZE);
            agent[i].set_op_timeout(64);
        end
        agent[0].ctrl_vif = db_ctrl_if_to_DUT[0];
        agent[1].ctrl_vif = db_ctrl_if_to_DUT[1];

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        for (int i = 0; i < NUM_IFS; i++) begin
            agent[i].idle();
        end

        // 50% backpressure
        set_backpressure(1);

        reset();
    endtask

    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
      svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    const int if_idx = $urandom() % NUM_IFS;

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

    // Import tests
    `include "../db_ctrl/mux_tests.svh"

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"
    // Import local (db_ctrl_mux) tasks
    `include "../db_ctrl/mux_tasks.svh"

endmodule : db_ctrl_mux_unit_test

// DUT: db_ctrl_intf_2to1_mux
module db_ctrl_intf_2to1_mux_unit_test;

    localparam int  NUM_IFS = 2;

    localparam int  KEY_WID = 12;
    localparam int  VALUE_WID = 32;

    // NOTE: define KEY_T/VALUE_T here as 'logic' vectors and not 'bit' vectors
    //       - works around apparent simulation bug where some direct
    //         assignments fail (i.e. assign a = b results in a != b)
    //       - bug occurs in regression run only, i.e. test suite passes
    //         when run standalone
    localparam type KEY_T = logic[KEY_WID-1:0];
    localparam type VALUE_T = logic[VALUE_WID-1:0];

    import svunit_pkg::svunit_testcase;
    svunit_testcase svunit_ut;

    logic mux_sel;

    logic clk;
    logic srst;
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_to_DUT [NUM_IFS] (.clk(clk));
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_from_DUT (.clk(clk));

    db_ctrl_mux_unit_test #(
        .NUM_IFS  ( NUM_IFS ),
        .KEY_T    ( KEY_T ),
        .VALUE_T  ( VALUE_T ),
        .DUT_NAME ( "db_ctrl_intf_2to1_mux" )
    ) test (.*);

    db_ctrl_intf_2to1_mux #(
        .KEY_T   ( logic[KEY_WID-1:0] ),
        .VALUE_T ( logic[VALUE_WID-1:0] )
    ) DUT (
        .clk  ( clk ),
        .srst ( srst ),
        .mux_sel ( mux_sel ),
        .ctrl_if_from_controller_0 ( db_ctrl_if_to_DUT[0] ),
        .ctrl_if_from_controller_1 ( db_ctrl_if_to_DUT[1] ),
        .ctrl_if_to_peripheral     ( db_ctrl_if_from_DUT )
    );

    always @(posedge clk) begin
        if (srst) mux_sel <= 0;
        else mux_sel <= ~mux_sel;
    end

    function void build();
        test.build();
        svunit_ut = test.svunit_ut;
    endfunction
    task run();
        test.run();
    endtask

endmodule : db_ctrl_intf_2to1_mux_unit_test

// DUT: db_ctrl_intf_prio_mux
module db_ctrl_intf_prio_mux_unit_test;

    localparam int  NUM_IFS = 2;

    localparam int  KEY_WID = 12;
    localparam int  VALUE_WID = 32;

    // NOTE: define KEY_T/VALUE_T here as 'logic' vectors and not 'bit' vectors
    //       - works around apparent simulation bug where some direct
    //         assignments fail (i.e. assign a = b results in a != b)
    //       - bug occurs in regression run only, i.e. test suite passes
    //         when run standalone
    localparam type KEY_T = logic[KEY_WID-1:0];
    localparam type VALUE_T = logic[VALUE_WID-1:0];

    import svunit_pkg::svunit_testcase;
    svunit_testcase svunit_ut;

    logic clk;
    logic srst;
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_to_DUT [NUM_IFS] (.clk(clk));
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_from_DUT (.clk(clk));

    db_ctrl_mux_unit_test #(
        .NUM_IFS  ( NUM_IFS ),
        .KEY_T    ( KEY_T ),
        .VALUE_T  ( VALUE_T ),
        .DUT_NAME ( "db_ctrl_intf_prio_mux" )
    ) test (.*);

    db_ctrl_intf_prio_mux #(
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T )
    ) DUT (
        .clk  ( clk ),
        .srst ( srst ),
        .ctrl_if_from_controller_hi_prio ( db_ctrl_if_to_DUT[0] ),
        .ctrl_if_from_controller_lo_prio ( db_ctrl_if_to_DUT[1] ),
        .ctrl_if_to_peripheral           ( db_ctrl_if_from_DUT )
    );

    function void build();
        test.build();
        svunit_ut = test.svunit_ut;
    endfunction
    task run();
        test.run();
    endtask

endmodule : db_ctrl_intf_prio_mux_unit_test


// DUT: db_ctrl_intf_prio_mux
module db_ctrl_intf_prio_mux_hier_unit_test;

    localparam int  NUM_IFS = 2;

    localparam int  KEY_WID = 12;
    localparam int  VALUE_WID = 32;

    // NOTE: define KEY_T/VALUE_T here as 'logic' vectors and not 'bit' vectors
    //       - works around apparent simulation bug where some direct
    //         assignments fail (i.e. assign a = b results in a != b)
    //       - bug occurs in regression run only, i.e. test suite passes
    //         when run standalone
    localparam type KEY_T = logic[KEY_WID-1:0];
    localparam type VALUE_T = logic[VALUE_WID-1:0];

    import svunit_pkg::svunit_testcase;
    svunit_testcase svunit_ut;

    logic clk;
    logic srst;
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_to_DUT [NUM_IFS] (.clk(clk));
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_to_DUMMY (.clk(clk));
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_from_DUT_0 (.clk(clk));
    db_ctrl_intf #(KEY_T, VALUE_T) db_ctrl_if_from_DUT (.clk(clk));

    db_ctrl_mux_unit_test #(
        .NUM_IFS  ( NUM_IFS ),
        .KEY_T    ( KEY_T ),
        .VALUE_T  ( VALUE_T ),
        .DUT_NAME ( "db_ctrl_intf_prio_hier_mux" )
    ) test (.*);

    db_ctrl_intf_prio_mux #(
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T )
    ) DUT_0 (
        .clk  ( clk ),
        .srst ( srst ),
        .ctrl_if_from_controller_hi_prio ( db_ctrl_if_to_DUT[0] ),
        .ctrl_if_from_controller_lo_prio ( db_ctrl_if_to_DUMMY ),
        .ctrl_if_to_peripheral           ( db_ctrl_if_from_DUT_0 )
    );

    db_ctrl_intf_prio_mux #(
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T )
    ) DUT_1 (
        .clk  ( clk ),
        .srst ( srst ),
        .ctrl_if_from_controller_hi_prio ( db_ctrl_if_to_DUT[1] ),
        .ctrl_if_from_controller_lo_prio ( db_ctrl_if_from_DUT_0 ),
        .ctrl_if_to_peripheral           ( db_ctrl_if_from_DUT )
    );

    db_ctrl_intf_controller_term i_db_ctrl_intf_controller_term (.ctrl_if (db_ctrl_if_to_DUMMY));

    function void build();
        test.build();
        svunit_ut = test.svunit_ut;
    endfunction
    task run();
        test.run();
    endtask

endmodule : db_ctrl_intf_prio_mux_hier_unit_test

