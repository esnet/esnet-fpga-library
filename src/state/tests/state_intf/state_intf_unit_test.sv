`include "svunit_defines.svh"

`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module state_intf_unit_test;
    import svunit_pkg::svunit_testcase;
    import state_pkg::*;
    import state_verif_pkg::*;

    string name = "state_intf_ut";
    svunit_testcase svunit_ut;

    // Interface bindings and typed verification components
    typedef bit [3:0] ID_T;
    typedef bit [31:0] STATE_T;
    typedef bit [7:0] UPDATE_T;
    typedef bit [7:0] MSG_T;
    logic clk;
    state_intf #(.ID_WID(4), .STATE_WID(32), .UPDATE_WID(8)) state_if (.clk);
    state_check_intf #(.STATE_WID(32), .MSG_WID(8)) check_if (.clk);
    state_event_intf #(.ID_WID(4), .MSG_WID(8)) event_if (.clk);
    state_intf_agent #(ID_T, STATE_T, UPDATE_T) agent;
    state_check_agent #(STATE_T, MSG_T) checker_agent;
    state_event_agent #(ID_T, MSG_T) publisher;
    state_driver #(ID_T, STATE_T, UPDATE_T) driver;
    state_monitor #(ID_T, STATE_T, UPDATE_T) monitor;
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Responders encode the received operands for end-to-end comparison.
    bit ready_enable = 1;
    bit ack_enable = 1;
    update_ctxt_t observed_ctxt;
    assign state_if.rdy = ready_enable;
    always @(posedge clk) begin
        state_if.ack <= state_if.req && state_if.rdy && ack_enable;
        if (state_if.req && state_if.rdy) begin
            state_if.state <= STATE_T'({state_if.ctxt, state_if.init,
                                       state_if.id, state_if.update});
            observed_ctxt <= state_if.ctxt;
        end
        check_if.ack <= check_if.req;
        if (check_if.req) begin
            check_if.active <= check_if.state[0];
            check_if.notify <= check_if.state[1];
            check_if.msg <= check_if.state[15:8];
        end
    end

    // Passive event capture checks payload and single-cycle notification pulses.
    int event_count = 0;
    ID_T last_id;
    MSG_T last_msg;
    wire event_valid = event_if.evt;
    always @(posedge clk) begin
        if (event_if.evt) begin
            event_count <= event_count + 1;
            last_id <= event_if.id;
            last_msg <= event_if.msg;
        end
    end
    clocking cb @(posedge clk);
        output ready_enable, ack_enable;
        input observed_ctxt, event_count, last_id, last_msg, event_valid;
    endclocking

    // SVUnit lifecycle
    function void build();
        svunit_ut = new(name);
        agent = new("state_agent");
        agent.state_vif = state_if;
        checker_agent = new("check_agent");
        checker_agent.state_vif = check_if;
        publisher = new("event_agent");
        publisher.state_vif = event_if;
        driver = new("driver");
        driver.update_vif = state_if;
        monitor = new("monitor");
        monitor.update_vif = state_if;
    endfunction

    task setup();
        svunit_ut.setup();
        checker_agent.idle();
        publisher.idle();
        agent.idle();
        cb.ready_enable <= 1;
        cb.ack_enable <= 1;
        agent.wait_n(2);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // Directed protocol, timeout, and transaction-stream checks
    `SVUNIT_TESTS_BEGIN
    `SVTEST(operation_contexts)
        STATE_T result;
        bit timeout;
        agent._update(4'h5, 8'hab, 1, result, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(result, STATE_T'({UPDATE_CTXT_DATAPATH, 1'b1, 4'h5, 8'hab}));
        agent.control(4'h7, 8'hcd, 0, result, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(result, STATE_T'({UPDATE_CTXT_CONTROL, 1'b0, 4'h7, 8'hcd}));
        agent.reap(4'h2, result, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(cb.observed_ctxt, UPDATE_CTXT_REAP);
        agent.nop(4'h1, timeout);
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(cb.observed_ctxt, UPDATE_CTXT_NOP);
    `SVTEST_END

    `SVTEST(pipelined_requests)
        STATE_T result;
        bit timeout;
        fork
            begin
                agent.update_req(4'h2, 8'ha1);
                agent.update_req(4'h2, 8'hb2);
            end
            begin
                agent.receive_resp(result, timeout, 16);
                `FAIL_IF(timeout);
                `FAIL_UNLESS_EQUAL(result, STATE_T'({UPDATE_CTXT_DATAPATH, 1'b0, 4'h2, 8'ha1}));
                agent.receive_resp(result, timeout, 16);
                `FAIL_IF(timeout);
                `FAIL_UNLESS_EQUAL(result, STATE_T'({UPDATE_CTXT_DATAPATH, 1'b0, 4'h2, 8'hb2}));
            end
        join
    `SVTEST_END

    `SVTEST(response_timeout_and_recovery)
        STATE_T result;
        bit timeout;
        cb.ack_enable <= 0;
        agent.wait_n(2);
        agent._update(0, 1, 0, result, timeout, 3);
        `FAIL_UNLESS(timeout);
        cb.ack_enable <= 1;
        agent.wait_n(2);
        agent._update(1, 2, 0, result, timeout, 8);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(readiness_timeout)
        bit timeout;
        cb.ready_enable <= 0;
        agent.wait_n(2);
        agent.wait_ready(timeout, 3);
        `FAIL_UNLESS(timeout);
        cb.ready_enable <= 1;
        agent.wait_n(2);
        agent.wait_ready(timeout, 0);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(check_state_payload)
        bit active, notify;
        MSG_T msg;
        checker_agent.check(32'h00005a03, active, notify, msg);
        `FAIL_UNLESS(active && notify);
        `FAIL_UNLESS_EQUAL(msg, 8'h5a);
        checker_agent.check(32'h0000a500, active, notify, msg);
        `FAIL_IF(active || notify);
        `FAIL_UNLESS_EQUAL(msg, 8'ha5);
    `SVTEST_END

    `SVTEST(notification_pulse)
        int before_count = cb.event_count;
        publisher.notify(4'hb, 8'he7);
        publisher.wait_n(3);
        `FAIL_UNLESS_EQUAL(cb.event_count, before_count+1);
        `FAIL_UNLESS_EQUAL(cb.last_id, 4'hb);
        `FAIL_UNLESS_EQUAL(cb.last_msg, 8'he7);
        `FAIL_IF(cb.event_valid);
    `SVTEST_END

    `SVTEST(typed_driver_monitor)
        state_req #(ID_T, UPDATE_T) request;
        state_resp #(STATE_T) response;
        request = new("request", 4'h9, UPDATE_CTXT_CONTROL, 1);
        request.update = 8'h63;
        fork
            driver.send(request);
            monitor.receive(response);
        join
        `FAIL_UNLESS_EQUAL(response.state, STATE_T'({UPDATE_CTXT_CONTROL, 1'b1, 4'h9, 8'h63}));
    `SVTEST_END
    `SVUNIT_TESTS_END
endmodule : state_intf_unit_test
