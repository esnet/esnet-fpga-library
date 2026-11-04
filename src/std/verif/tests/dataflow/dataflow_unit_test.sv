`include "svunit_defines.svh"

module dataflow_unit_test;
    import svunit_pkg::svunit_testcase;
    import std_verif_pkg::*;
    import std_verif_test_pkg::*;

    string name = "dataflow_ut";
    svunit_testcase svunit_ut;
    //===================================
    // Components under test
    //===================================
    component workers[$];
    //===================================
    // Clock and synchronization
    //===================================
    // Cleanup runs after SVUnit marks the testcase stopped.
    bit clk = 0;
    always #5ns clk = ~clk;
    default clocking cb @(posedge clk); endclocking

    //===================================
    // Build / setup / teardown
    //===================================
    function void build(); svunit_ut = new(name); endfunction
    task setup(); svunit_ut.setup(); endtask
    task teardown();
        foreach (workers[i]) workers[i].stop();
        repeat (2) @(cb);
        foreach (workers[i]) workers[i].destroy();
        workers.delete();
        svunit_ut.teardown();
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN
        `SVTEST(wire_model_order_and_identity)
            wire_model#(word_t) model = new();
            word_t sent[8];
            word_t got;
            workers.push_back(model);
            model.inbox = new(); model.outbox = new();
            model.build(); model.init(); model.run();
            foreach (sent[i]) begin
                sent[i] = new("sent", $urandom);
                model.inbox.put(sent[i]);
            end
            foreach (sent[i]) begin
                model.outbox.get(got);
                `FAIL_UNLESS(got == sent[i]);
                `FAIL_UNLESS_EQUAL(got.data, sent[i].data);
            end
            `FAIL_UNLESS_EQUAL(model.num_input_transactions(), 8);
            `FAIL_UNLESS_EQUAL(model.num_output_transactions(), 8);
            model.stop();
            repeat (2) @(cb);
            model.reset();
            `FAIL_UNLESS_EQUAL(model.num_input_transactions(), 0);
            `FAIL_UNLESS_EQUAL(model.num_output_transactions(), 0);
        `SVTEST_END

        `SVTEST(predictor_function_and_mailboxes)
            xor_predictor model = new();
            word_t sent = new("sent", 32'h12345678);
            word_t got;
            workers.push_back(model);
            got = model.predict(sent);
            `FAIL_IF(got == sent);
            `FAIL_UNLESS_EQUAL(got.data, 32'h479e03d2);
            `FAIL_UNLESS_EQUAL(sent.data, 32'h12345678);
            model.inbox = new(); model.outbox = new();
            model.build(); model.init(); model.run();
            model.inbox.put(sent);
            model.outbox.get(got);
            `FAIL_UNLESS_EQUAL(got.data, sent.data ^ 32'h55aa55aa);
            `FAIL_UNLESS_EQUAL(model.num_input_transactions(), 1);
            `FAIL_UNLESS_EQUAL(model.num_output_transactions(), 1);
        `SVTEST_END

        `SVTEST(raw_predictor_conversion_and_processing)
            raw_xor_predictor model = new();
            byte_t sent;
            byte_t got;
            workers.push_back(model);
            sent = model.input_transaction_from_raw(8'h12);
            got = model.predict(sent);
            `FAIL_UNLESS_EQUAL(model.output_transaction_to_raw(got), 8'h48);
            model.inbox = new(); model.outbox = new();
            model.build(); model.init(); model.run();
            model.inbox.put(sent);
            model.outbox.get(got);
            `FAIL_UNLESS_EQUAL(got.data, 8'h48);
        `SVTEST_END

        `SVTEST(raw_model_filtering)
            filtering_model model = new();
            byte_t item;
            workers.push_back(model);
            model.inbox = new(); model.outbox = new();
            model.build(); model.init(); model.run();
            for (int i = 0; i < 4; i++) begin
                item = new("input", i);
                model.inbox.put(item);
            end
            for (int i = 0; i < 2; i++) begin
                model.outbox.get(item);
                `FAIL_UNLESS_EQUAL(item.data, 2*i + 1);
            end
            repeat (2) @(cb);
            `FAIL_UNLESS_EQUAL(model.num_input_transactions(), 4);
            `FAIL_UNLESS_EQUAL(model.num_output_transactions(), 2);
            `FAIL_UNLESS_EQUAL(model.outbox.num(), 0);
        `SVTEST_END

        `SVTEST(sequencer_and_collector)
            expanding_sequencer seq = new();
            pair_collector collect = new();
            word_t item = new("four_elements", 4);
            workers.push_back(seq); workers.push_back(collect);
            seq.inbox = new(); seq.outbox = new();
            collect.inbox = seq.outbox; collect.outbox = new();
            seq.build(); collect.build();
            seq.init(); collect.init(); seq.run(); collect.run();
            seq.inbox.put(item);
            collect.outbox.get(item);
            `FAIL_UNLESS_EQUAL(item.data, 1);
            collect.outbox.get(item);
            `FAIL_UNLESS_EQUAL(item.data, 5);
            `FAIL_UNLESS_EQUAL(seq.num_sequences(), 1);
            `FAIL_UNLESS_EQUAL(seq.num_transactions(), 4);
            `FAIL_UNLESS_EQUAL(collect.num_input_transactions(), 4);
            `FAIL_UNLESS_EQUAL(collect.num_output_sequences(), 2);
            seq.stop(); collect.stop(); repeat (2) @(cb);
            seq.reset(); collect.reset();
            `FAIL_UNLESS_EQUAL(seq.num_sequences(), 0);
            `FAIL_UNLESS_EQUAL(collect.num_input_transactions(), 0);
        `SVTEST_END

        `SVTEST(driver_monitor_direct_and_background)
            mailbox_driver drv = new();
            mailbox_monitor mon = new();
            word_t sent = new("input", 32'h1234);
            word_t got;
            workers.push_back(drv); workers.push_back(mon);
            drv.link = new(); mon.link = drv.link;
            drv.inbox = new(); mon.outbox = new();
            mon.set_rx_transaction_prefix("sample");
            drv.send(sent); mon.receive(got);
            `FAIL_UNLESS_STR_EQUAL(got.get_name(), "sample[0]");
            `FAIL_UNLESS_EQUAL(got.data, sent.data);
            `FAIL_UNLESS_EQUAL(drv.num_transactions(), 1);
            `FAIL_UNLESS_EQUAL(mon.num_transactions(), 1);
            drv.reset(); mon.reset();
            drv.build(); mon.build(); drv.run(); mon.run();
            drv.inbox.put(sent);
            mon.outbox.get(got);
            `FAIL_UNLESS_STR_EQUAL(got.get_name(), "sample[0]");
            `FAIL_UNLESS_EQUAL(drv.num_transactions(), 1);
            `FAIL_UNLESS_EQUAL(mon.num_transactions(), 1);
        `SVTEST_END

        `SVTEST(scoreboard_matches)
            raw_scoreboard#(word_data_t) sb = new();
            word_t got;
            word_t expected;
            string msg;
            workers.push_back(sb);
            sb.got_inbox = new(); sb.exp_inbox = new();
            sb.build(); sb.init(); sb.run();
            for (int i = 0; i < 3; i++) begin
                got = new("got", i); expected = new("expected", i);
                sb.got_inbox.put(got); sb.exp_inbox.put(expected);
            end
            wait (sb.got_matched() == 3);
            sb.stop(); repeat (2) @(cb);
            `FAIL_UNLESS_EQUAL(sb.got_processed(), 3);
            `FAIL_UNLESS_EQUAL(sb.exp_processed(), 3);
            `FAIL_UNLESS_EQUAL(sb.report(msg), 0);
        `SVTEST_END

        `SVTEST(scoreboard_detects_mismatch)
            raw_scoreboard#(word_data_t) sb = new();
            word_t got = new("got", 1);
            word_t expected = new("expected", 2);
            string msg;
            workers.push_back(sb);
            sb.got_inbox = new(); sb.exp_inbox = new();
            sb.build(); sb.init(); sb.run();
            sb.got_inbox.put(got); sb.exp_inbox.put(expected);
            repeat (2) @(cb);
            sb.stop(); repeat (2) @(cb);
            `FAIL_UNLESS_EQUAL(sb.got_processed(), 1);
            `FAIL_UNLESS_EQUAL(sb.exp_processed(), 1);
            `FAIL_UNLESS_EQUAL(sb.got_matched(), 0);
            `FAIL_UNLESS_EQUAL(sb.report(msg), 1);
        `SVTEST_END

        `SVTEST(scoreboard_unmatched_and_init_flush)
            event_scoreboard#(word_t) sb = new();
            word_t expected = new("expected", 7);
            string msg;
            workers.push_back(sb);
            sb.got_inbox = new(); sb.exp_inbox = new();
            sb.exp_inbox.put(expected);
            `FAIL_UNLESS_EQUAL(sb.exp_pending(), 1);
            `FAIL_UNLESS_EQUAL(sb.report(msg), 1);
            sb.init();
            `FAIL_UNLESS_EQUAL(sb.exp_pending(), 0);
            `FAIL_UNLESS_EQUAL(sb.report(msg), 0);
        `SVTEST_END

        `SVTEST(model_init_flushes_stale_input)
            wire_model#(word_t) model = new();
            word_t stale = new("stale", 1);
            workers.push_back(model);
            model.inbox = new(); model.outbox = new();
            model.inbox.put(stale);
            model.init();
            `FAIL_UNLESS_EQUAL(model.inbox.num(), 0);
            `FAIL_UNLESS_EQUAL(model.num_input_transactions(), 0);
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule
