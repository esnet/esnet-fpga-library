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
        env.db_agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, db_pkg::DB_TYPE_STATE);
        // Check (state) type
        env.db_agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, BLOCK_TYPE);
        // Check size
        env.db_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, env.NUM_IDS);
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
        _wait(8);
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
        _wait(8);
        // Clear state
        clear(id, got_state);
        // Check that previous value of state is returned
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
        // Wait for clear to happen
        _wait(8);
        // Check that state is now cleared
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, 0);
    `SVTEST_END


    `SVTEST(clear_all_state)
        localparam int NUM_ACTIVE_IDS = 10;
        ID_T ids [$];
        STATE_T exp_state [NUM_ACTIVE_IDS];
        STATE_T got_state;
        // Randomize IDs
        do begin
            ID_T __id;
            void'(std::randomize(__id));
            ids.push_back(__id);
            ids = ids.unique;
        end while (ids.size() < NUM_ACTIVE_IDS);
        // Set state
        foreach (ids[i]) begin
            STATE_T __exp_state;
            void'(std::randomize(__exp_state));
            set(ids[i], __exp_state);
            exp_state[i] = __exp_state;
        end
        // Wait for write to happen
        _wait(8);
        // Check
        foreach (ids[i]) begin
            // Get state
            get(ids[i], got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state[i]);
        end
        // Issue control reset
        clear_all();
        // Check that state is now cleared
        foreach (ids[i]) begin
            // Get state
            get(ids[i], got_state);
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
        void'(std::randomize(exp_state));

        // Initialize state
        set(id, exp_state);

        // Update
        _update(id, update, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

        // Predict next state
        exp_state = get_next_state(exp_state, update);

        // Check
        get(id, got_state);
        env.debug_msg($sformatf("GOT STATE: 0x%0x, EXP STATE: 0x%0x.", got_state, exp_state));
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
        void'(std::randomize(exp_state));

        // Initialize state
        set(id, exp_state);

        // Send updates
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            _update(id, update, got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            // Predict next state
            exp_state = get_next_state(exp_state, update);
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
        void'(std::randomize(exp_state));

        // Initialize state
        set(id, exp_state);

        // Send updates
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            _update(id, update, got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            // Predict next state
            exp_state = get_next_state(exp_state, update);
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

        // Send update with initialization
        void'(std::randomize(update));
        _update(id, update, got_state, 1);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
        // Predict next state
        exp_state = get_next_state(exp_state, update, 1'b1);

        // Send more updates
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            _update(id, update, got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            // Predict next state
            exp_state = get_next_state(exp_state, update);
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
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
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


    `SVTEST(back_to_back_updates_with_1cycle_gap)
        localparam int NUM_UPDATES = 2;
        localparam int GAP_CYCLES = 1;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
                    _wait(GAP_CYCLES);
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


    `SVTEST(back_to_back_updates_with_2cycle_gap)
        localparam int NUM_UPDATES = 2;
        localparam int GAP_CYCLES = 2;
        ID_T id;
        UPDATE_T updates [NUM_UPDATES];
        STATE_T got_state;
        STATE_T exp_state [NUM_UPDATES+1];

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(updates));
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
                    _wait(GAP_CYCLES);
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
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
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
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
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
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
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
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
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
        void'(std::randomize(exp_state[0]));

        // Predict state after each update
        for (int i = 1; i < NUM_UPDATES+1; i++) begin
            exp_state[i] = exp_state[i-1];
            exp_state[i] = get_next_state(exp_state[i-1], updates[i-1]);
        end

        // Initialize state
        set(id, exp_state[0]);

        fork
            begin
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    update_req(id, updates[i]);
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


    `SVTEST(control_update_once)
        ID_T id;
        STATE_T got_state;
        STATE_T exp_state;
        UPDATE_T update;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(update));
        void'(std::randomize(exp_state));

        // Initialize state
        set(id, exp_state);

        // Update
        control_update(id, update, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

        // Predict next state
        exp_state = get_next_state_control(exp_state, update);

        // Check
        get(id, got_state);
        env.debug_msg($sformatf("GOT STATE: 0x%0x, EXP STATE: 0x%0x.", got_state, exp_state));
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
    `SVTEST_END


    `SVTEST(control_update_multiple)
        localparam int NUM_UPDATES = 100;
        ID_T id;
        UPDATE_T update;
        STATE_T got_state;
        STATE_T exp_state;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_state));

        // Initialize state
        set(id, exp_state);

        // Send updates
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(update));
            control_update(id, update, got_state);
            `FAIL_UNLESS_EQUAL(got_state, exp_state);
            // Predict next state
            exp_state = get_next_state_control(exp_state, update);
        end

        // Check
        get(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
    `SVTEST_END


    `SVTEST(reap)
        ID_T id;
        STATE_T got_state;
        STATE_T exp_state;
        UPDATE_T update;

        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(update));
        void'(std::randomize(exp_state));

        // Initialize state
        set(id, exp_state);

        // Reap state
        _reap(id, got_state);
        `FAIL_UNLESS_EQUAL(got_state, exp_state);

        // Predict next state
        exp_state = get_next_state_reap(exp_state, update);

        // Check
        get(id, got_state);
        env.debug_msg($sformatf("GOT STATE: 0x%0x, EXP STATE: 0x%0x.", got_state, exp_state));
        `FAIL_UNLESS_EQUAL(got_state, exp_state);
    `SVTEST_END

