`include "svunit_defines.svh"

`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 10us

module db_intf_unit_test;
    import svunit_pkg::svunit_testcase;
    import db_verif_pkg::*;

    string name = "db_intf_ut";
    svunit_testcase svunit_ut;

    // Interfaces and agents
    typedef bit [7:0] KEY_T;
    typedef bit [31:0] VALUE_T;
    logic clk;
    db_intf #(.KEY_WID(8), .VALUE_WID(32)) rd_if (.clk);
    db_intf #(.KEY_WID(8), .VALUE_WID(32)) wr_if (.clk);
    db_intf_agent #(KEY_T, VALUE_T) reader, writer;
    `SVUNIT_CLK_GEN(clk, 2ns);

    // Responder model: independently stall request acceptance or completion.
    bit ready_enable = 1;
    bit ack_enable = 1;
    bit response_error = 0;
    KEY_T written_key;
    VALUE_T written_value;
    bit written_valid;
    assign rd_if.rdy = ready_enable;
    assign wr_if.rdy = ready_enable;
    assign rd_if.valid = 1'b1;
    assign rd_if.value = 32'h12345678;
    assign rd_if.error = response_error;
    assign wr_if.error = response_error;
    always @(posedge clk) begin
        rd_if.ack <= rd_if.req && rd_if.rdy && ack_enable;
        wr_if.ack <= wr_if.req && wr_if.rdy && ack_enable;
        if (wr_if.req && wr_if.rdy) begin
            written_key <= wr_if.key;
            written_value <= wr_if.value;
            written_valid <= wr_if.valid;
        end
    end

    clocking cb @(posedge clk);
        output ready_enable, ack_enable, response_error;
        input written_key, written_value, written_valid;
    endclocking

    // SVUnit lifecycle
    function void build();
        svunit_ut = new(name);
        reader = new("reader");
        reader.db_vif = rd_if;
        writer = new("writer");
        writer.db_vif = wr_if;
    endfunction

    task setup();
        svunit_ut.setup();
        reader.idle();
        writer.idle();
        cb.ready_enable <= 1;
        cb.ack_enable <= 1;
        cb.response_error <= 0;
        reader.wait_n(2);
    endtask

    task teardown();
        reader.idle();
        writer.idle();
        svunit_ut.teardown();
    endtask

    // Successful transfers, timeout handling, and recovery
    `SVUNIT_TESTS_BEGIN

    `SVTEST(query_and_update)
        bit valid, error, timeout;
        VALUE_T value;
        writer.update(8'hab, 1, 32'habcdef01, error, timeout);
        `FAIL_IF(error || timeout);
        `FAIL_UNLESS_EQUAL(cb.written_key, 8'hab);
        `FAIL_UNLESS_EQUAL(cb.written_value, 32'habcdef01);
        `FAIL_UNLESS(cb.written_valid);
        reader.query(8'hab, valid, value, error, timeout);
        `FAIL_IF(error || timeout);
        `FAIL_UNLESS(valid);
        `FAIL_UNLESS_EQUAL(value, 32'h12345678);
    `SVTEST_END

    `SVTEST(posted_update_without_ack)
        bit timeout;
        cb.ack_enable <= 0;
        writer.wait_n(2);
        writer.post_update(8'h34, 0, 32'hfedcba98, timeout);
        `FAIL_IF(timeout);
        writer.wait_n(1);
        `FAIL_UNLESS_EQUAL(cb.written_key, 8'h34);
        `FAIL_UNLESS_EQUAL(cb.written_value, 32'hfedcba98);
        `FAIL_IF(cb.written_valid);
    `SVTEST_END

    `SVTEST(request_timeout_and_recovery)
        bit valid, error, timeout;
        VALUE_T value;
        cb.ready_enable <= 0;
        reader.wait_n(2);
        reader.query(0, valid, value, error, timeout, 3);
        `FAIL_UNLESS(timeout);
        reader.wait_n(1);
        `FAIL_IF(rd_if.cb.req);
        cb.ready_enable <= 1;
        reader.wait_n(2);
        reader.query(0, valid, value, error, timeout);
        `FAIL_IF(error || timeout);
        `FAIL_UNLESS(valid);
    `SVTEST_END

    `SVTEST(response_timeout_and_recovery)
        bit error, timeout;
        cb.ack_enable <= 0;
        writer.wait_n(2);
        writer.update(1, 1, 2, error, timeout, 4);
        `FAIL_UNLESS(timeout);
        writer.wait_n(1);
        `FAIL_IF(wr_if.cb.req);
        cb.ack_enable <= 1;
        writer.wait_n(2);
        writer.update(3, 1, 4, error, timeout);
        `FAIL_IF(error || timeout);
    `SVTEST_END

    `SVTEST(readiness_timeout)
        bit timeout;
        cb.ready_enable <= 0;
        reader.wait_n(2);
        reader.wait_ready(timeout, 3);
        `FAIL_UNLESS(timeout);
        cb.ready_enable <= 1;
        reader.wait_n(2);
        reader.wait_ready(timeout);
        `FAIL_IF(timeout);
    `SVTEST_END

    `SVTEST(disabled_timeout_and_error_response)
        bit valid, error, timeout;
        VALUE_T value;
        cb.response_error <= 1;
        reader.wait_n(2);
        reader.query(0, valid, value, error, timeout, 0);
        `FAIL_IF(timeout);
        `FAIL_UNLESS(error);
    `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : db_intf_unit_test
