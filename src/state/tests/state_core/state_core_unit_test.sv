`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 2ms

module state_core_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 14;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type STATE_T = byte;
    localparam type UPDATE_T = byte;
    localparam type DUMMY_T = bit;

    //===================================
    // DUT
    //===================================

    // Signals
    logic    clk;
    logic    srst;
    logic    init_done;

    logic    db_init;
    logic    db_init_done;

    STATE_T  prev_state;
    logic    update_init;
    UPDATE_T update_data;
    STATE_T  new_state;

    // Interfaces
    db_info_intf                                         info_if ();
    db_ctrl_intf      #(.KEY_T(ID_T), .VALUE_T(STATE_T)) ctrl_if (.clk(clk));
    state_update_intf #(.ID_T(ID_T),  .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) update_if (.clk(clk));
    db_intf           #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_wr_if (.clk(clk));
    db_intf           #(.KEY_T(ID_T), .VALUE_T(STATE_T)) db_rd_if (.clk(clk));

    // Instantiation
    state_core #(
        .ID_T ( ID_T ),
        .STATE_T ( STATE_T ),
        .UPDATE_T ( UPDATE_T ),
        .RETURN_MODE ( state_pkg::RETURN_MODE_PREV_STATE ),
        .NUM_WR_TRANSACTIONS ( 2 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) DUT (.*);

    // State update (count even updates, reset to zero on init)
    always_comb begin
        if (update_init) new_state = 0;
        else             new_state = prev_state;
        if (update_data % 2 == 0) new_state += 1;
    end

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
    
    // Environment
    std_verif_pkg::env env;

    // Control agent
    db_verif_pkg::db_ctrl_agent#(ID_T, STATE_T) ctrl_agent;

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

        // Testbench environment
        env = new();
        env.reset_vif = reset_if;

        // Instantiate agent
        ctrl_agent = new("db_ctrl_agent", NUM_IDS);
        ctrl_agent.ctrl_vif = ctrl_if;
        ctrl_agent.info_vif = info_if;

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Put driven interfaces into quiescent state
        ctrl_agent.idle();
        update_if.idle();

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

    //===================================
    // Test:
    //   Reset
    //
    // Description:
    //   Issue (block-level) reset signal,
    //   wait for initialization to complete
    //===================================
    `SVTEST(reset)
    `SVTEST_END

    //===================================
    // Test:
    //   Info
    //
    // Description:
    //   Check reported parameterization
    //   and compare against expected
    //===================================
    `SVTEST(info)
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        int got_size;
        // Check (database) type
        ctrl_agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_STATE);
        // Check (state) type
        ctrl_agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, state_pkg::STATE_TYPE_UNSPECIFIED);
        // Check size
        ctrl_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    //===================================
    // Test:
    //   Set state from control plane
    //
    // Description:
    //   Set state via control plane interface,
    //   check by reading state over the
    //   same interface.
    //===================================
    `SVTEST(set_state)
        ID_T id;
        STATE_T got_state;
        STATE_T exp_state;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));
        // Set state
        set(id, exp_state);
        // Issue another (different) SET operation
        set(^id, ^exp_state);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check state
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
    `SVTEST_END

    `SVTEST(set_clear_state)
        ID_T id;
        STATE_T exp_state;
        STATE_T got_state;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));
        // Set state
        set(id, exp_state);
        // Issue another (different) SET operation
        set(^id, ^exp_state);
        // Wait for writes to happen
        ctrl_agent._wait(5);
        // Clear state
        clear(id, got_state);
        // Check that previous value of state is returned
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
        // Wait for clear to happen
        ctrl_agent._wait(5);
        // Check that state is now cleared
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, 0);
    `SVTEST_END

    `SVTEST(clear_all_state)
        localparam int NUM_ACTIVE_IDS = 10;
        ID_T id [NUM_ACTIVE_IDS];
        STATE_T exp_state [NUM_ACTIVE_IDS];
        STATE_T got_state;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));
        for (int i = 0; i < NUM_ACTIVE_IDS; i++) begin
            // Set state
            set(id[i], exp_state[i]);
        end
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        for (int i = 0; i < NUM_ACTIVE_IDS; i++) begin
            // Set state
            get(id[i], got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
        end
        // Issue control reset
        clear_all();
        // Check that state is now cleared
        for (int i = 0; i < NUM_ACTIVE_IDS; i++) begin
            // Set state
            get(id[i], got_state);
            `FAIL_UNLESS_EQUAL(got_state, 0);
        end
    `SVTEST_END

    `SVTEST(update_once)
        ID_T id;
        STATE_T got_state;
        STATE_T exp_state;
        UPDATE_T update;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(update));
        exp_state = (update % 2 == 0) ? 1 : 0;

        // Update
        send(id, update);
        receive(got_state);
        `FAIL_UNLESS_EQUAL(got_state, 0);

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
    `SVTEST_END

    `SVTEST(update_multiple)
        localparam int NUM_UPDATES = 100;
        ID_T id;
        UPDATE_T update;
        STATE_T got_state;
        STATE_T exp_state;

        // Randomize
        void'(std::randomize(id));
        
        // Send updates
        exp_state = 0;
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            send(id, update);
            receive(got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            if (update % 2 == 0) exp_state += 1;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
    `SVTEST_END

    `SVTEST(init_and_update)
        localparam int NUM_UPDATES = 100;
        ID_T id;
        UPDATE_T update;
        STATE_T exp_state;
        STATE_T got_state;

        // Randomize
        void'(std::randomize(id));

        // Send updates
        exp_state = 0;
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            send(id, update);
            receive(got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            if (update % 2 == 0) exp_state += 1;
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

        // Send update with initialization
        void'(std::randomize(update));
        send(id, update, 1);
        receive(got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
        exp_state = 0;
        if (update % 2 == 0) exp_state += 1;

        // Send more updates
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            send(id, update);
            receive(got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            if (update % 2 == 0) exp_state += 1;
        end

        // Check final value (from control plane)
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

    `SVTEST_END

    `SVTEST(back_to_back_updates)
        localparam int NUM_UPDATES = 2;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));

        // Predict state after each update
        exp_state[0] = 0;
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            if (updates[i-1] % 2 == 0) exp_state[i] += 1;
        end

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, updates[i]);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[NUM_UPDATES]);

    `SVTEST_END

    `SVTEST(three_consecutive_updates)
        localparam int NUM_UPDATES = 3;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));

        // Predict state after each update
        exp_state[0] = 0;
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            if (updates[i-1] % 2 == 0) exp_state[i] += 1;
        end

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, updates[i]);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[NUM_UPDATES]);

    `SVTEST_END

    `SVTEST(four_consecutive_updates)
        localparam int NUM_UPDATES = 4;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));

        // Predict state after each update
        exp_state[0] = 0;
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            if (updates[i-1] % 2 == 0) exp_state[i] += 1;
        end

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, updates[i]);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[NUM_UPDATES]);

    `SVTEST_END

    `SVTEST(five_consecutive_updates)
        localparam int NUM_UPDATES = 5;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));

        // Predict state after each update
        exp_state[0] = 0;
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            if (updates[i-1] % 2 == 0) exp_state[i] += 1;
        end

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, updates[i]);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[NUM_UPDATES]);

    `SVTEST_END


    `SVTEST(ten_consecutive_updates)
        localparam int NUM_UPDATES = 10;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));

        // Predict state after each update
        exp_state[0] = 0;
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            if (updates[i-1] % 2 == 0) exp_state[i] += 1;
        end

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, updates[i]);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[NUM_UPDATES]);

    `SVTEST_END


    `SVTEST(one_hundred_consecutive_updates)
        localparam int NUM_UPDATES = 100;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));

        // Predict state after each update
        exp_state[0] = 0;
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            if (updates[i-1] % 2 == 0) exp_state[i] += 1;
        end

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(id, updates[i]);
                end
            end
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive response
                    receive(got_state);
                    `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
                end
            end
        join

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state[NUM_UPDATES]);

    `SVTEST_END

    `SVUNIT_TESTS_END

    //===================================
    // Tasks
    //===================================
    // Import common tasks
    `include "../common/tasks.svh"

endmodule
