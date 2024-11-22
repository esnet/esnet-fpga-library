`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 2ms

module state_notify_unit_test;
   
    //===================================
    // Imports
    //===================================
    import svunit_pkg::svunit_testcase;
    import state_pkg::*;
    import tb_pkg::*;
    import state_verif_pkg::*;
    import db_verif_pkg::*;
    import axi4l_verif_pkg::*;
 
    //===================================
    // Testcase config
    //===================================
    string name = "state_notify_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Typedefs
    //===================================
    localparam vector_t SPEC = '{
        NUM_ELEMENTS : 2,
        ELEMENTS : '{
            0 : ELEMENT_CONTROL_FLAG,
            1 : '{ELEMENT_TYPE_COUNTER, 8, 0, RETURN_MODE_PREV_STATE, REAP_MODE_CLEAR},
            default: DEFAULT_STATE_ELEMENT
        }
    };

    typedef struct packed {
        logic [7:0] count;
        logic       en;
    } __STATE_T;

    typedef struct packed {
        logic en;
    } __UPDATE_T;

    //===================================
    // Parameters
    //===================================
    // NOTE: define ID_T/STATE_T here as 'logic' vectors and not 'bit' vectors
    //       - works around apparent simulation bug where some direct
    //         assignments fail (i.e. assign a = b results in a != b)
    localparam type ID_T = logic[9:0];
    localparam type STATE_T = logic[$bits(__STATE_T)-1:0];
    localparam type UPDATE_T = logic[$bits(__UPDATE_T)-1:0];

    localparam type NOTIFY_MSG_T = expiry_msg_t;

    localparam block_type_t BLOCK_TYPE = BLOCK_TYPE_VECTOR;

    localparam int NUM_IDS = State#(ID_T)::numIDs();

    //===================================
    // DUT
    //===================================

    // Signals
    logic    clk;
    logic    srst;

    logic    en;
    logic    init_done;

    // Interfaces
    axi4l_intf #() axil_if ();
    db_ctrl_intf #(.KEY_T (ID_T), .VALUE_T(STATE_T)) db_ctrl_if (.clk(clk));
    state_check_intf #(.STATE_T(__STATE_T), .MSG_T(NOTIFY_MSG_T)) check_if (.clk(clk));
    state_event_intf #(.ID_T(ID_T), .MSG_T(NOTIFY_MSG_T)) notify_if (.clk(clk));

    // Instantiation
    state_notify_fsm #(
        .ID_T    ( ID_T ),
        .STATE_T ( STATE_T ),
        .MSG_T   ( NOTIFY_MSG_T )
    ) DUT (.*);

    // Implement active/notify
    always_ff @(posedge clk) begin
        if (check_if.req) begin
            check_if.ack <= 1'b1;
            check_if.active <= 1'b0;
            check_if.notify <= 1'b0;
            check_if.msg <= EXPIRY_NONE;
            if (check_if.state.en) begin
                check_if.active <= 1'b1;
                if (check_if.state.count < 128) begin
                    check_if.notify <= 1'b1;
                    if (check_if.state.count > 64)     check_if.msg <= EXPIRY_DONE;
                    else if (check_if.state.count > 0) check_if.msg <= EXPIRY_ACTIVE;
                    else                               check_if.msg <= EXPIRY_IDLE;
                end
            end
        end else check_if.ack <= 1'b0;
    end

    //===================================
    // Testbench
    //===================================
    // Signals
    logic db_init;
    logic db_init_done;
    db_info_intf #() sv_info_if ();
    state_intf #(.ID_T(ID_T), .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) sv_update_if (.clk(clk));
    state_intf #(.ID_T(ID_T), .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) sv_ctrl_if (.clk(clk));
    db_ctrl_intf #(.KEY_T (ID_T), .VALUE_T(STATE_T)) __db_ctrl_if (.clk(clk));
    db_ctrl_intf #(.KEY_T (ID_T), .VALUE_T(STATE_T)) sv_db_ctrl_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_rd_if (.clk(clk));
    
    db_ctrl_intf_prio_mux #(
        .KEY_T ( ID_T ),
        .VALUE_T ( STATE_T )
    ) i_db_ctrl_mux (
        .clk ( clk ),
        .srst ( srst ),
        .ctrl_if_from_controller_hi_prio ( __db_ctrl_if ),
        .ctrl_if_from_controller_lo_prio ( db_ctrl_if ),
        .ctrl_if_to_peripheral           ( sv_db_ctrl_if )
    );

    state_vector_core #(
        .ID_T ( ID_T ),
        .SPEC ( SPEC )
    ) i_state_vector_core (
        .clk          ( clk ),
        .srst         ( srst ),
        .en           ( en ),
        .init_done    ( init_done ),
        .info_if      ( sv_info_if ),
        .update_if    ( sv_update_if ),
        .ctrl_if      ( sv_ctrl_if ),
        .db_ctrl_if   ( sv_db_ctrl_if ),
        .db_init      ( db_init ),
        .db_init_done ( db_init_done ),
        .db_wr_if     ( db_wr_if ),
        .db_rd_if     ( db_rd_if )
    );

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

    state_vector_model#(ID_T, STATE_T, UPDATE_T) model;

    db_ctrl_agent #(ID_T, STATE_T) db_agent;

    axi4l_reg_agent #() axil_reg_agent;
    state_notify_reg_agent reg_agent;

    // Assign clock (200MHz)
    `SVUNIT_CLK_GEN(clk, 2.5ns);

    // Assign AXI-L clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Interfaces
    std_reset_intf reset_if (.clk(clk));

    // Drive srst from reset interface
    assign srst = reset_if.reset;
    assign axil_if.aresetn = ~srst;
    assign reset_if.ready = init_done;

    assign en = 1'b1;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Model
        model = new("state_vector_model", SPEC);

        // Database agent
        db_agent = new("db_agent", State#(ID_T)::numIDs());
        db_agent.ctrl_vif = __db_ctrl_if;
        db_agent.info_vif = sv_info_if;

        // Testbench environment
        env = new();
        env.reset_vif = reset_if;
        env.ctrl_vif = sv_ctrl_if;
        env.update_vif = sv_update_if;

        env.model = model;
        env.db_agent = db_agent;

        env.build();

        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axil_if;
        reg_agent = new("state_notify_reg_agent", axil_reg_agent);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        env.idle();
        reg_agent.idle();

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

    `SVTEST(notify_once)
        ID_T id;
        __STATE_T state;
        int got_cnt;
        
        void'(std::randomize(id));
        state.en = 1'b1;
        state.count = 65;

        // Write state
        set(id, state);

        // Expect notification
        wait(notify_if.evt);
        `FAIL_UNLESS_EQUAL(notify_if.id, id);
        `FAIL_UNLESS_EQUAL(notify_if.msg, EXPIRY_DONE);

        reg_agent.get_notify_cnt(got_cnt);
        `FAIL_UNLESS_EQUAL(got_cnt, 1);
    `SVTEST_END

    `SVTEST(scan_done_cnt)
        localparam int NUM_SCANS = 5;
        int got_cnt;
        // Read scan done count (expect 0 after reset)
        reg_agent.get_scan_done_cnt(got_cnt);
        `FAIL_UNLESS_EQUAL(got_cnt, 0);
        // Wait for specified number of scans to complete
        repeat (NUM_SCANS) @(posedge DUT.scan_done);
        // Read count again and check
        reg_agent.get_scan_done_cnt(got_cnt);
        `FAIL_UNLESS_EQUAL(got_cnt, NUM_SCANS);
    `SVTEST_END

    `SVTEST(active_cnt)
        localparam int EXP_CNT = 100;
        int got_cnt;
        ID_T ids [$];
        __STATE_T __state;

        // State just needs to be enabled (don't care about other fields)
        __state = 'x;
        __state.en = 1;

        // Synthesize list of random IDs
        do begin
            ID_T __id;
            void'(std::randomize(__id));
            ids.push_back(__id);
            ids = ids.unique;
        end while (ids.size() < EXP_CNT);

        // Activate state vectors for the chosen IDs
        foreach (ids[i]) set(ids[i], __state);
        
        // Ensure that full scan runs after all entries are set
        @(posedge DUT.scan_done);
        @(posedge DUT.scan_done);

        // Read and check active count
        reg_agent.get_active_last_scan_cnt(got_cnt);
        `FAIL_UNLESS_EQUAL(got_cnt, EXP_CNT);
    `SVTEST_END

    `SVTEST(scan_limit)
        localparam int CNT = 100;
        int got_cnt;
        ID_T ids [$];
        int exp_cnt;
        int scan_limit = NUM_IDS/2;
        __STATE_T __state;
 
        // Set scan limit
        reg_agent.set_scan_limit(scan_limit);

        // State just needs to be enabled (don't care about other fields)
        __state = 'x;
        __state.en = 1;

        // Synthesize list of random IDs
        // (ensure that three of the IDs are within scan_limit +/- 1
        ids.push_back(scan_limit-1);
        ids.push_back(scan_limit);
        ids.push_back(scan_limit+1);
        do begin
            ID_T __id;
            void'(std::randomize(__id));
            ids.push_back(__id);
            ids = ids.unique;
        end while (ids.size() < CNT);

        // Activate state vectors for the chosen IDs, while tracking
        // the number of IDs that fall within the scan limit
        exp_cnt = 0;
        foreach(ids[i]) begin
            set(ids[i], __state);
            if (ids[i] <= scan_limit) exp_cnt++;
        end

        // Ensure that full scan runs after all entries are set
        @(posedge DUT.scan_done);
        @(posedge DUT.scan_done);

        // Read and check active count
        reg_agent.get_active_last_scan_cnt(got_cnt);
        `FAIL_UNLESS_EQUAL(got_cnt, exp_cnt);
    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

endmodule

