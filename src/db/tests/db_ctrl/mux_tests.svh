    `SVTEST(reset)
    `SVTEST_END

    `SVTEST(ctrl_reset)
        bit error, timeout;
        agent[if_idx].clear_all(error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(set_get)
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
        agent[if_idx].set(key, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Read back and check
        agent[if_idx].get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
    `SVTEST_END

    `SVTEST(unset)
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
        agent[if_idx].set(key, exp_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Clear entry (and check previous value)
        agent[if_idx].unset(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value);
        // Read back and check that entry is cleared
        agent[if_idx].get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_IF(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, 0);

    `SVTEST_END

    `SVTEST(replace)
        KEY_T key;
        VALUE_T exp_value [2];
        VALUE_T got_value;
        bit got_valid;
        bit error;
        bit timeout;
        // Randomize key/value
        void'(std::randomize(key));
        void'(std::randomize(exp_value[0]));
        void'(std::randomize(exp_value[1]));
        // Add entry
        agent[if_idx].set(key, exp_value[0], error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        // Replace entry (and check previous value)
        agent[if_idx].replace(key, exp_value[1], got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[0]);
        // Read back and check that entry is cleared
        agent[if_idx].get(key, got_valid, got_value, error, timeout);
        `FAIL_IF(error);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(got_valid);
        `FAIL_UNLESS_EQUAL(got_value, exp_value[1]);

    `SVTEST_END

    `SVTEST(contention)
        localparam NUM_TRANSACTIONS = 10000;
        KEY_T key;
        VALUE_T exp_value;
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;
        // Write incrementing pattern to database
        for (int i = 0; i < SIZE; i++) begin
            // Skip every 4th entry
            if (i % 4 < 3) begin
                key = i;
                exp_value = i;
                agent[if_idx].set(key, exp_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                agent[if_idx].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS(got_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        fork
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[0].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[0].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                end
            end
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[1].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[1].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                end
            end
        join
    `SVTEST_END

    `SVTEST(contention_backpressure)
        localparam NUM_TRANSACTIONS = 10000;
        KEY_T key;
        VALUE_T exp_value;
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;
        
        // Configure backpressure from downstream database
        set_backpressure(15);

        // Write incrementing pattern to database
        for (int i = 0; i < SIZE; i++) begin
            // Skip every 4th entry
            if (i % 4 < 3) begin
                key = i;
                exp_value = i;
                agent[if_idx].set(key, exp_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                agent[if_idx].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS(got_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        fork
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[0].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[0].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                end
            end
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[1].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[1].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                end
            end
        join
    `SVTEST_END

    `SVTEST(port0_only)
        localparam NUM_TRANSACTIONS = 10000;
        KEY_T key;
        VALUE_T exp_value;
        bit exp_valid;
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;
        // Write incrementing pattern to database
        for (int i = 0; i < SIZE; i++) begin
            // Skip every 4th entry
            if (i % 4 < 3) begin
                key = i;
                exp_value = i;
                agent[if_idx].set(key, exp_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                agent[if_idx].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS(got_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            void'(std::randomize(key));
            if (key % 4 < 3) begin
                exp_valid = 1'b1;
                exp_value = key;
            end else begin
                exp_valid = 1'b0;
                exp_value = '0;
            end
            if ($urandom() % 2 > 0) begin
                if (exp_valid) begin
                    agent[0].set(key, exp_value, error, timeout);
                    `FAIL_IF(error);
                    `FAIL_IF(timeout);
                end
            end else begin
                agent[0].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
    `SVTEST_END

    `SVTEST(port1_only)
        localparam NUM_TRANSACTIONS = 10000;
        KEY_T key;
        VALUE_T exp_value;
        bit exp_valid;
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;
        // Write incrementing pattern to database
        for (int i = 0; i < SIZE; i++) begin
            // Skip every 4th entry
            if (i % 4 < 3) begin
                key = i;
                exp_value = i;
                agent[if_idx].set(key, exp_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                agent[if_idx].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS(got_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            void'(std::randomize(key));
            if (key % 4 < 3) begin
                exp_valid = 1'b1;
                exp_value = key;
            end else begin
                exp_valid = 1'b0;
                exp_value = '0;
            end
            if ($urandom() % 2 > 0) begin
                if (exp_valid) begin
                    agent[1].set(key, exp_value, error, timeout);
                    `FAIL_IF(error);
                    `FAIL_IF(timeout);
                end
            end else begin
                agent[1].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        
    `SVTEST_END

    `SVTEST(port0)
        localparam NUM_TRANSACTIONS = 10000;
        KEY_T key;
        VALUE_T exp_value;
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;
        // Write incrementing pattern to database
        for (int i = 0; i < SIZE; i++) begin
            // Skip every 4th entry
            if (i % 4 < 3) begin
                key = i;
                exp_value = i;
                agent[if_idx].set(key, exp_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                agent[if_idx].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS(got_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        fork
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[0].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[0].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                end
            end
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS/100; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[1].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[1].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                    agent[1]._wait($urandom() % 1000);
                end
            end
        join
    `SVTEST_END

    `SVTEST(port1)
        localparam NUM_TRANSACTIONS = 10000;
        KEY_T key;
        VALUE_T exp_value;
        bit got_valid;
        VALUE_T got_value;
        bit error;
        bit timeout;
        // Write incrementing pattern to database
        for (int i = 0; i < SIZE; i++) begin
            // Skip every 4th entry
            if (i % 4 < 3) begin
                key = i;
                exp_value = i;
                agent[if_idx].set(key, exp_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                agent[if_idx].get(key, got_valid, got_value, error, timeout);
                `FAIL_IF(error);
                `FAIL_IF(timeout);
                `FAIL_UNLESS(got_valid);
                `FAIL_UNLESS_EQUAL(got_value, exp_value);
            end
        end
        fork
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS/100; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[0].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[0].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                    agent[0]._wait($urandom() % 1000);
                end
            end
            begin
                KEY_T key;
                bit exp_valid;
                VALUE_T exp_value;
                bit got_valid;
                VALUE_T got_value;
                bit error;
                bit timeout;
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    void'(std::randomize(key));
                    if (key % 4 < 3) begin
                        exp_valid = 1'b1;
                        exp_value = key;
                    end else begin
                        exp_valid = 1'b0;
                        exp_value = '0;
                    end
                    if ($urandom() % 2 > 0) begin
                        if (exp_valid) begin
                            agent[1].set(key, exp_value, error, timeout);
                            `FAIL_IF(error);
                            `FAIL_IF(timeout);
                        end
                    end else begin
                        agent[1].get(key, got_valid, got_value, error, timeout);
                        `FAIL_IF(error);
                        `FAIL_IF(timeout);
                        `FAIL_UNLESS_EQUAL(got_valid, exp_valid);
                        `FAIL_UNLESS_EQUAL(got_value, exp_value);
                    end
                end
            end
        join
    `SVTEST_END

