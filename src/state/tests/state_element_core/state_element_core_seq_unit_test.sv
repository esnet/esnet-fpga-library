`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 2ms

module state_element_core_seq_unit_test;
    //===================================
    // Imports
    //===================================
    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import state_pkg::*;
    import state_verif_pkg::*;
    import db_verif_pkg::*;

    //===================================
    // Parameters
    //===================================
    localparam element_t SPEC = '{
        TYPE: ELEMENT_TYPE_SEQ,
        STATE_WID: 32,
        UPDATE_WID: 48,
        RETURN_MODE: RETURN_MODE_PREV_STATE,
        REAP_MODE: REAP_MODE_PERSIST
    };

    // NOTE: define ID_T/STATE_T here as 'logic' vectors and not 'bit' vectors
    //       - works around apparent simulation bug where some direct
    //         assignments fail (i.e. assign a = b results in a != b)
    localparam type ID_T = logic[11:0];
    localparam type STATE_T = logic[SPEC.STATE_WID-1:0];
    localparam int UPDATE_WID = SPEC.UPDATE_WID > 0 ? SPEC.UPDATE_WID : 1;
    localparam type UPDATE_T = logic[SPEC.UPDATE_WID-1:0];

    localparam int SEQ_WID = SPEC.STATE_WID;
    localparam int INC_WID = SPEC.UPDATE_WID-SEQ_WID;

    typedef logic [SEQ_WID-1:0] seq_t;
    typedef logic [INC_WID-1:0] inc_t;

    typedef struct packed {
        inc_t inc;
        seq_t seq;
    } __update_t;

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

    `SVTEST(seq_expected)
        ID_T id;
        __update_t update;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(seq));

        // Set initial state
        exp_state = seq;
        set(id, exp_state);

        for (int i = 0; i < 1000; i++) begin
            bit [15:0] inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            seq = seq + inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(seq_expected_zero)
        ID_T id;
        __update_t update;
        inc_t init_inc;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));

        // Pick random starting sequence and increment,
        // where sequence number will wrap to exactly zero
        // after first update
        void'(std::randomize(init_inc));
        seq = 0 - init_inc;

        // Set initial state
        exp_state = seq;

        set(id, exp_state);

        update.seq = seq;
        update.inc = init_inc;
        _update(id, update, got_state);

        `FAIL_UNLESS_EQUAL(got_state, exp_state);
        seq = '0;
        exp_state = '0;

        for (int i = 0; i < 100; i++) begin
            inc_t inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            seq = seq + inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(seq_expected_wrap)
        ID_T id;
        __update_t update;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));
        seq = (2**SEQ_WID-1) - $urandom % (2**INC_WID);

        // Set initial state
        exp_state = seq;
        set(id, exp_state);

        for (int i = 0; i < 100; i++) begin
            inc_t inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            seq = seq + inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(seq_replay)
        ID_T id;
        __update_t update;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(seq));

        // Set initial state
        exp_state = seq;
        set(id, exp_state);

        for (int i = 0; i < 1000; i++) begin
            inc_t inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            if ($urandom % 10 == 0) update.seq = seq - inc;
            else                    update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            if (update.seq == seq) seq = seq + inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(seq_replay_wrap)
        ID_T id;
        __update_t update;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));
        seq = (2**SEQ_WID-1) - $urandom % (2**INC_WID);

        // Set initial state
        exp_state = seq;
        set(id, exp_state);

        for (int i = 0; i < 100; i++) begin
            inc_t inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            if ($urandom % 10 == 0) update.seq = seq - inc;
            else                    update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            if (update.seq == seq) seq = seq + inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(seq_missing)
        ID_T id;
        __update_t update;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(seq));

        // Set initial state
        exp_state = seq;
        set(id, exp_state);

        for (int i = 0; i < 1000; i++) begin
            inc_t inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            if ($urandom % 10 == 0) update.seq = seq + inc;
            else                    update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            seq = update.seq + update.inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(seq_missing_wrap)
        ID_T id;
        __update_t update;
        seq_t seq;
        STATE_T exp_state = '0;
        STATE_T got_state;
        
        // Randomize
        void'(std::randomize(id));
        seq = (2**SEQ_WID-1) - $urandom % (2**INC_WID);

        // Set initial state
        exp_state = seq;
        set(id, exp_state);

        for (int i = 0; i < 100; i++) begin
            inc_t inc;
            
            // Randomize increment
            void'(std::randomize(inc));

            // Update with expected sequence number
            if ($urandom % 10 == 0) update.seq = seq + inc;
            else                    update.seq = seq;
            update.inc = inc;

            _update(id, update, got_state);

            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            seq = update.seq + update.inc;
            exp_state = seq;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

endmodule
