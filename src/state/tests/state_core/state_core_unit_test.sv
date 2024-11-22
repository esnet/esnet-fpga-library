`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 2ms

module state_core_unit_test
    import state_pkg::*;
#(
    parameter string NAME = "unspecified",
    parameter type ID_T = logic,
    parameter vector_t SPEC = DEFAULT_STATE_VECTOR
);
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import state_verif_pkg::*;
    import axi4l_verif_pkg::*;
    import db_verif_pkg::*;

    string name = $sformatf("state_core_%s_ut", NAME);
    svunit_testcase svunit_ut;

    localparam block_type_t BLOCK_TYPE = BLOCK_TYPE_VECTOR;

    localparam type STATE_T = logic[getStateVectorSize(SPEC)-1:0];
    localparam type UPDATE_T = logic[getUpdateVectorSize(SPEC)-1:0];
    localparam type NOTIFY_MSG_T = expiry_msg_t;

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
    axi4l_intf   #() axil_if ();
    state_intf   #(.ID_T(ID_T),  .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) update_if (.clk(clk));
    state_intf   #(.ID_T(ID_T),  .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) ctrl_if (.clk(clk));
    state_check_intf #(.STATE_T(STATE_T), .MSG_T(NOTIFY_MSG_T)) check_if (.clk(clk));
    state_event_intf #(.ID_T(ID_T), .MSG_T(NOTIFY_MSG_T)) notify_if (.clk(clk));
    db_intf      #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_wr_if (.clk(clk));
    db_intf      #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_rd_if (.clk(clk));

    // Instantiation
    state_core #(
        .ID_T ( ID_T ),
        .SPEC ( SPEC ),
        .NOTIFY_MSG_T ( NOTIFY_MSG_T ),
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

    axi4l_reg_agent axil_reg_agent;
    state_reg_agent #(ID_T, STATE_T) agent;

    state_vector_model#(ID_T, STATE_T, UPDATE_T) model;

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Assign AXI-L clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Interfaces
    std_reset_intf reset_if (.clk(clk));

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;

    assign axil_if.aresetn = !srst;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Model
        model = new($sformatf("state_vector_model[%s]", NAME), SPEC);
        // Database agent
        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;
        agent = new("state_reg_agent", axil_reg_agent);

        // Testbench environment
        env = new();
        env.reset_vif = reset_if;
        env.update_vif = update_if;
        env.ctrl_vif = ctrl_if;

        env.model = model;
        env.db_agent = agent.db;

        env.build();

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
//  Builds unit test for a specific state vector configuration in a way
//  that maintains SVUnit compatibility
`define STATE_CORE_UNIT_TEST(_NAME,_ID_T,_SPEC)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  state_core_unit_test #(.NAME(_NAME), .ID_T(_ID_T), .SPEC(``_SPEC)) test();\
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

// Histogram
module state_core_histogram_unit_test;
    import state_pkg::*;
    localparam element_t STATE_ELEMENT_HIST_BIN_64B = '{
        ELEMENT_TYPE_COUNTER_COND, 64, 1, RETURN_MODE_PREV_STATE, REAP_MODE_CLEAR
    };
    localparam int NUM_ELEMENTS = 8;
    localparam vector_t SPEC = '{
        NUM_ELEMENTS: 8,
        ELEMENTS : '{
            default: STATE_ELEMENT_HIST_BIN_64B
        }
    };
`STATE_CORE_UNIT_TEST("histogram",logic[11:0],SPEC);
endmodule

