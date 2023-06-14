    `SVTEST(set_query)
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        agent.set(key, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Query database from app interface
        query(key, got_valid, got_value);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END
 
    `SVTEST(update_query)
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value));
        // Add entry
        update(key, 1'b1, exp_value);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Query database from app interface
        query(key, got_valid, got_value);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END
 
    `SVTEST(burst_update)
        localparam int BURST_CNT = 8;
        KEY_T key;
        VALUE_T exp_value;
        VALUE_T got_value;
        bit exp_valid;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key
        void'(std::randomize(key));
        for (int i = 0; i < BURST_CNT; i++) begin
            // Add new random entry (same key)
            void'(std::randomize(exp_valid));
            void'(std::randomize(exp_value));
            post_update(key, exp_valid, exp_value);
        end
        // Query database and check that most recently written value is returned
        query(key, got_valid, got_value);
        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVTEST(read_modify_write)
        localparam int NUM_UPDATES = 2;
        KEY_T key;
        bit exp_valid [NUM_UPDATES+1];
        VALUE_T exp_value [NUM_UPDATES+1];
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;

        // Randomize
        void'(std::randomize(key));
        exp_valid[0] = 1'b1;
        void'(std::randomize(exp_value[0]));

        // Initialize value
        agent.set(key, exp_value[0], error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);

        for (int i = 1; i <= NUM_UPDATES; i++) begin
            VALUE_T __value;
            // Read current value
            query(key, got_valid, got_value);
            `FAIL_UNLESS_EQUAL(got_valid, exp_valid[i-1]);
            `FAIL_UNLESS_EQUAL(got_value, exp_value[i-1]);
            // Modify value by adding random increment
            void'(std::randomize(__value));
            exp_value[i] = exp_value[i-1] + __value;
            void'(std::randomize(exp_valid[i]));
            // Post write transaction
            post_update(key, exp_valid[i], exp_value[i]);
        end

        // Check final value
        query(key, got_valid, got_value);
        `FAIL_UNLESS_EQUAL(got_valid, exp_valid[NUM_UPDATES]);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[NUM_UPDATES]);

    `SVTEST_END

