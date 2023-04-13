`include "svunit_defines.svh"

//===================================
// (Failsafe) timeout (per-testcase)
//===================================
`define SVUNIT_TIMEOUT 2ms

module state_seq_core_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "state_seq_core_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int ID_WID = 13;
    localparam int INC_WID = 16;
    localparam int SEQ_WID = 32;

    // Derived parameters
    localparam int NUM_IDS = 2**ID_WID;

    // Typedefs
    localparam type ID_T = bit[ID_WID-1:0];
    localparam type SEQ_T = bit[SEQ_WID-1:0];
    localparam type INC_T = bit[INC_WID-1:0];

    localparam type UPDATE_T = struct packed {INC_T inc; SEQ_T seq;};

    localparam type DUMMY_T = bit;

    //===================================
    // DUT
    //===================================

    // Signals
    logic   clk;
    logic   srst;
    logic   init_done;

    logic   db_init;
    logic   db_init_done;

    // Interfaces
    db_ctrl_intf      #(.KEY_T(ID_T), .VALUE_T(SEQ_T)) ctrl_if (.clk(clk));
    db_info_intf      #() info_if ();
    state_update_intf #(.ID_T(ID_T), .UPDATE_T(UPDATE_T), .STATE_T(SEQ_T)) update_if (.clk(clk));
    db_intf           #(.KEY_T(ID_T), .VALUE_T(SEQ_T)) db_wr_if (.clk(clk));
    db_intf           #(.KEY_T(ID_T), .VALUE_T(SEQ_T)) db_rd_if (.clk(clk));

    // Instantiation
    state_seq_core #(
        .ID_T ( ID_T ),
        .SEQ_T ( SEQ_T ),
        .INC_T ( INC_T ),
        .NUM_WR_TRANSACTIONS ( 2 ),
        .NUM_RD_TRANSACTIONS ( 8 )
    ) DUT (.*);

    //===================================
    // Testbench
    //===================================
    // Database store
    db_store_array #(
        .KEY_T   ( ID_T ),
        .VALUE_T ( SEQ_T ),
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
    db_verif_pkg::db_ctrl_agent#(ID_T, SEQ_T) ctrl_agent;

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
        `FAIL_UNLESS_EQUAL(got_subtype, state_pkg::STATE_TYPE_SEQ);
        // Check size
        ctrl_agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, NUM_IDS);
    `SVTEST_END

    `SVTEST(set_seq)
        ID_T id;
        SEQ_T seq;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(seq));
        // Set sequence
        set(id, seq);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check sequence
        check(id, seq);
    `SVTEST_END

    `SVTEST(set_clear_seq)
        ID_T id;
        SEQ_T exp_seq;
        SEQ_T got_seq;
        // Randomize
        void'(std::randomize(id));
        void'(std::randomize(exp_seq));
        // Enable seq
        set(id, exp_seq);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Clear seq
        clear(id, got_seq);
        // Check that previous value of seq is returned
        `FAIL_UNLESS_EQUAL(got_seq, exp_seq);
        // Wait for clear to happen
        ctrl_agent._wait(5);
        // Check that seq is now cleared
        check(id, '0);
    `SVTEST_END

    `SVTEST(clear_all_seqs)
        ID_T id = $urandom % NUM_IDS;
        SEQ_T set_seq;
        // Randomize
        void'(std::randomize(set_seq));
        // Enable ID
        set(id, set_seq);
        // Wait for write to happen
        ctrl_agent._wait(5);
        // Check
        check(id, set_seq);
        // Issue control reset
        clear_all();
        // Check that seq is now cleared
        check(id, '0);
    `SVTEST_END

    `SVTEST(update_seq)
        ID_T exp_id;
        ID_T got_id;
        SEQ_T got_seq;
        SEQ_T exp_seq;
        INC_T _inc;

        // Randomize
        void'(std::randomize(exp_id));
        void'(std::randomize(exp_seq));
        // Initialize
        send(exp_id, exp_seq, '0, 1'b1);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, '0);
        // Check
        check(exp_id, exp_seq);
        // Send update
        void'(std::randomize(_inc));
        send(exp_id, exp_seq, _inc);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, exp_seq);
        // Check
        check(exp_id, exp_seq + _inc);
    `SVTEST_END

    `SVTEST(seq_retrace)
        ID_T exp_id;
        ID_T got_id;
        SEQ_T got_seq;
        SEQ_T exp_seq;
        INC_T _inc;

        // Randomize
        void'(std::randomize(exp_id));
        void'(std::randomize(exp_seq));
        // Initialize
        send(exp_id, exp_seq, '0, 1'b1);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, '0);
        // Check
        check(exp_id, exp_seq);
        // Send update
        void'(std::randomize(_inc));
        send(exp_id, exp_seq, _inc);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, exp_seq);
        // Send another update with same sequence number
        send(exp_id, exp_seq, _inc + 1);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, exp_seq + _inc);
        // Check
        check(exp_id, exp_seq + _inc);
    `SVTEST_END

    `SVTEST(seq_skip)
        ID_T exp_id;
        ID_T got_id;
        SEQ_T got_seq;
        SEQ_T exp_seq;
        INC_T _inc;

        // Randomize
        void'(std::randomize(exp_id));
        void'(std::randomize(exp_seq));
        // Initialize
        send(exp_id, exp_seq, '0, 1'b1);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, '0);
        // Check
        check(exp_id, exp_seq);
        // Send update
        void'(std::randomize(_inc));
        send(exp_id, exp_seq, _inc);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, exp_seq);
        // Send another update but 'skip' sequence number
        send(exp_id, exp_seq + 2*_inc + 1, _inc);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, exp_seq + _inc);
        // Check
        check(exp_id, exp_seq + 3*_inc + 1);
    `SVTEST_END

    `SVTEST(back_to_back_updates)
        localparam int NUM_UPDATES = 2;
        ID_T exp_id;
        ID_T got_id;
        SEQ_T init_seq;
        SEQ_T exp_seq;
        SEQ_T got_seq;
        INC_T _inc [NUM_UPDATES];

        // Randomize
        void'(std::randomize(exp_id));
        void'(std::randomize(init_seq));
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(_inc[i]));
        end
        // Initialize
        send(exp_id, init_seq, '0, 1'b1);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, '0);
        // Send/receive updates
        fork
            begin
                SEQ_T _seq = init_seq;
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(exp_id, _seq, _inc[i]);
                    _seq = _seq + _inc[i];
                end
                exp_seq = _seq;
            end
            begin
                SEQ_T _seq = init_seq;
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive responses
                    receive(got_seq);
                    `FAIL_UNLESS_EQUAL(got_seq, _seq);
                    _seq = _seq + _inc[i];
                end
            end
        join
        // Check
        check(exp_id, exp_seq);
    `SVTEST_END

    `SVTEST(ten_consecutive_updates)
        localparam int NUM_UPDATES = 10;
        ID_T exp_id;
        ID_T got_id;
        SEQ_T init_seq;
        SEQ_T exp_seq;
        SEQ_T got_seq;
        INC_T _inc [NUM_UPDATES];

        // Randomize
        void'(std::randomize(exp_id));
        void'(std::randomize(init_seq));
        for (int i = 0; i < NUM_UPDATES; i++) begin
            void'(std::randomize(_inc[i]));
        end
        // Initialize
        send(exp_id, init_seq, '0, 1'b1);
        receive(got_seq);
        `FAIL_UNLESS_EQUAL(got_seq, '0);
        // Send/receive updates
        fork
            begin
                SEQ_T _seq = init_seq;
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Send update
                    send(exp_id, _seq, _inc[i]);
                    _seq = _seq + _inc[i];
                end
                exp_seq = _seq;
            end
            begin
                SEQ_T _seq = init_seq;
                for (int i = 0; i < NUM_UPDATES; i++) begin
                    // Receive responses
                    receive(got_seq);
                    `FAIL_UNLESS_EQUAL(got_seq, _seq);
                    _seq = _seq + _inc[i];
                end
            end
        join
        // Check
        check(exp_id, exp_seq);
    `SVTEST_END

    `SVUNIT_TESTS_END

    task send(input ID_T id, input SEQ_T seq, input INC_T inc, input bit init=1'b0);
        UPDATE_T update;
        update.seq = seq;
        update.inc = inc;
        update_if.send(id, update, init);
    endtask

    task receive(output SEQ_T seq);
        bit __timeout;
        update_if.receive(seq, __timeout);
    endtask

    task set(input ID_T id, input SEQ_T seq);
        automatic DUMMY_T __dummy = 1'b0;
        bit error;
        bit timeout;
        ctrl_agent.set(id, seq, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while setting sequence for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while setting sequence for ID 0x%0x.",
                id
            )
        );
    endtask

    task clear(input ID_T id, output SEQ_T old_seq);
        DUMMY_T __dummy;
        bit error;
        bit timeout;
        ctrl_agent.unset(id, __dummy, old_seq, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while clearing sequence for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while clearing sequence for ID 0x%0x.",
                id
            )
        );
    endtask

    task check(input ID_T id, input SEQ_T exp_seq);
        DUMMY_T __dummy;
        SEQ_T got_seq;
        bit error;
        bit timeout;
        ctrl_agent.get(id, __dummy, got_seq, error, timeout);
        `FAIL_IF_LOG(
            error,
            $sformatf(
                "Error detected while checking sequence for ID 0x%0x.",
                id
            )
        );
        `FAIL_IF_LOG(
            timeout,
            $sformatf(
                "Timeout detected while checking sequence flags for ID 0x%0x.",
                id
            )
        );
        `FAIL_UNLESS_LOG(
            got_seq === exp_seq,
            $sformatf(
                "Mismatch detected for ID 0x%0x. (Exp: 0x%0x, Got: 0x%0x.)",
                id, exp_seq, got_seq
            )
        );
    endtask

    task clear_all();
        bit error;
        bit timeout;
        ctrl_agent.clear_all(error, timeout);
        `FAIL_IF_LOG(
            error,
            "Error detected while performing RESET operation."
        );
        `FAIL_IF_LOG(
            timeout,
            "Timeout detected while performing RESET operation."
        );
    endtask

endmodule
