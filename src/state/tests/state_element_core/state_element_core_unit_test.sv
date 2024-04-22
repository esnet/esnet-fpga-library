`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 2ms

module state_element_core_unit_test
    import state_pkg::*;
#(
    parameter type ID_T = logic,
    parameter element_t SPEC = DEFAULT_STATE_ELEMENT
);
    //===================================
    // Imports
    //===================================
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import state_verif_pkg::*;
    import db_verif_pkg::*;

    //===================================
    // Parameters
    //===================================
    // NOTE: define ID_T/STATE_T here as 'logic' vectors and not 'bit' vectors
    //       - works around apparent simulation bug where some direct
    //         assignments fail (i.e. assign a = b results in a != b)
    localparam type STATE_T = logic[SPEC.STATE_WID-1:0];
    localparam int UPDATE_WID = SPEC.UPDATE_WID > 0 ? SPEC.UPDATE_WID : 1;
    localparam type UPDATE_T = logic[UPDATE_WID-1:0];

    localparam block_type_t BLOCK_TYPE = BLOCK_TYPE_ELEMENT;

    //===================================
    // Testcase config
    //===================================
    string name = $sformatf("state_element_core_%s_ut", getElementTypeString(SPEC.TYPE));
    svunit_testcase svunit_ut;

    //===================================
    // DUT
    //===================================

    // Signals
    logic    clk;
    logic    srst;
    logic    en;
    logic    init_done;

    logic    db_init;
    logic    db_init_done;

    // Interfaces
    db_info_intf  info_if ();
    state_intf    #(.ID_T(ID_T),  .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) update_if (.clk(clk));
    state_intf    #(.ID_T(ID_T),  .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) ctrl_if   (.clk(clk));
    db_ctrl_intf  #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_ctrl_if (.clk(clk));
    db_intf       #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_wr_if (.clk(clk));
    db_intf       #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_rd_if (.clk(clk));

    // Instantiation
    state_element_core #(
        .ID_T ( ID_T ),
        .SPEC ( SPEC ),
        .NUM_WR_TRANSACTIONS ( 4 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Database store
    db_store_array #(
        .KEY_T   ( ID_T ),
        .VALUE_T ( STATE_T ),
        .TRACK_VALID ( 0 ),
        .SIM__FAST_INIT ( 0 )
    ) i_db_store_array (
        .init ( db_init ),
        .init_done ( db_init_done ),
        .*
    );

    // Common state testbench environment
    tb_env#(ID_T, STATE_T, UPDATE_T) env;

    state_element_model#(ID_T, STATE_T, UPDATE_T) model;

    db_ctrl_agent#(ID_T, STATE_T) db_agent;

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Interfaces
    std_reset_intf reset_if (.clk(clk));

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Model
        model = new($sformatf("state_element_model[%s]", getElementTypeString(SPEC.TYPE)), SPEC);

        // Database agent
        db_agent = new("db_ctrl_agent", State#(ID_T)::numIDs());
        db_agent.ctrl_vif = db_ctrl_if;
        db_agent.info_vif = info_if;

        // Testbench environment
        env = new();
        env.reset_vif = reset_if;
        env.ctrl_vif = ctrl_if;
        env.update_vif = update_if;

        env.model = model;
        env.db_agent = db_agent;

        env.connect();

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        env.idle();

        en = 1'b1;

        // HW reset
        env.reset_dut();

        env._wait(1);

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

    // Run common tests
    `include "../common/tests.svh"

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

endmodule

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific state element configuration in a way
//  that maintains SVUnit compatibility
`define STATE_ELEMENT_UNIT_TEST(_ID_T,_SPEC)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  state_element_core_unit_test #(.ID_T(_ID_T), .SPEC(_SPEC)) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  function void __register_tests();\
    test.__register_tests();\
  endfunction \
  task run();\
    test.run();\
  endtask

// READ
module state_element_core_read_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_READ,24,24,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_PERSIST};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule

// WRITE
module state_element_core_write_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_WRITE,32,32,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_PERSIST};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule

// WRITE_IF_ZERO
module state_element_core_write_if_zero_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_WRITE_IF_ZERO,20,20,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_CLEAR};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule

// FLAGS
module state_element_core_flags_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_FLAGS,10,10,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_CLEAR};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule

// COUNTER
module state_element_core_counter_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_COUNTER,32,0,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_CLEAR};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule

// COUNTER_COND
module state_element_core_counter_cond_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_COUNTER_COND,32,1,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_CLEAR};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule

// COUNT
module state_element_core_count_unit_test;
    localparam type ID_T = logic[11:0];
    localparam state_pkg::element_t SPEC = '{state_pkg::ELEMENT_TYPE_COUNT,64,16,state_pkg::RETURN_MODE_PREV_STATE,state_pkg::REAP_MODE_CLEAR};
    `STATE_ELEMENT_UNIT_TEST(ID_T,SPEC);
endmodule
