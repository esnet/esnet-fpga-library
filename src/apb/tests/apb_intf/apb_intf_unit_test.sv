`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`define SVUNIT_TIMEOUT 500us

module apb_intf_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "apb_intf_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Clock and interfaces
    //===================================
    logic clk;
    `SVUNIT_CLK_GEN(clk, 5ns);

    apb_intf #(.ADDR_WID(16)) source_if ();
    apb_intf #(.ADDR_WID(16)) middle_if ();
    apb_intf #(.ADDR_WID(16)) sink_if ();
    apb_intf terminated_if ();

    logic reset_n;
    assign source_if.pclk = clk;
    assign source_if.presetn = reset_n;

    //===================================
    // DUT and signal helpers
    //===================================
    // Flatten and reconstruct every signal before the interface connector.
    wire pclk, presetn, psel, penable, pwrite, pready, pslverr;
    wire [15:0] paddr;
    wire [2:0] pprot;
    wire [31:0] pwdata, prdata;
    wire [3:0] pstrb;

    apb_intf_to_signals #(.ADDR_WID(16)) i_to_signals (.apb_if(source_if), .*);
    apb_intf_from_signals #(.ADDR_WID(16)) i_from_signals (.apb_if(middle_if), .*);
    apb_intf_connector DUT (
        .apb_if_from_controller(middle_if), .apb_if_to_peripheral(sink_if)
    );
    apb_intf_controller_term i_controller_term (.apb_if(terminated_if));
    apb_intf_peripheral_term i_peripheral_term (.apb_if(terminated_if));

    //===================================
    // Peripheral stimulus and monitoring
    //===================================
    logic response_ready, response_error;
    logic [31:0] response_data;
    assign sink_if.pready = response_ready;
    assign sink_if.prdata = response_data;
    assign sink_if.pslverr = response_error;

    wire sel_mon = sink_if.psel;
    wire enable_mon = sink_if.penable;
    wire write_mon = sink_if.pwrite;
    wire ready_mon = sink_if.pready;
    wire reset_mon = sink_if.presetn;
    wire [15:0] addr_mon = sink_if.paddr;
    wire [31:0] data_mon = sink_if.pwdata;
    wire [3:0] strb_mon = sink_if.pstrb;
    wire [2:0] prot_mon = sink_if.pprot;

    clocking cb @(posedge clk);
        output reset_n, response_ready, response_error, response_data;
        input sel_mon, enable_mon, write_mon, ready_mon, reset_mon;
        input addr_mon, data_mon, strb_mon, prot_mon;
    endclocking

    //===================================
    // Agent
    //===================================
    apb_verif_pkg::apb_reg_agent #(.ADDR_WID(16)) agent;

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
        agent = new();
        agent.apb_vif = source_if;
    endfunction

    task setup();
        svunit_ut.setup();
        cb.reset_n <= 1'b0;
        cb.response_ready <= 1'b0;
        cb.response_error <= 1'b0;
        cb.response_data <= '0;
        agent.idle();
        repeat (4) @(cb);
        cb.reset_n <= 1'b1;
        repeat (2) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Transaction helpers
    //===================================
    task automatic check_access(input bit wr, input bit [15:0] addr,
                                input bit [31:0] data, input bit [3:0] strb);
        `FAIL_UNLESS(cb.sel_mon && cb.enable_mon);
        `FAIL_UNLESS_EQUAL(cb.write_mon, wr);
        `FAIL_UNLESS_EQUAL(cb.addr_mon, addr);
        `FAIL_UNLESS_EQUAL(cb.prot_mon, apb_pkg::PPROT_DEFAULT);
        if (wr) begin
            `FAIL_UNLESS_EQUAL(cb.data_mon, data);
            `FAIL_UNLESS_EQUAL(cb.strb_mon, strb);
        end else begin
            `FAIL_UNLESS_EQUAL(cb.strb_mon, 0);
        end
    endtask

    task automatic respond(input bit wr, input bit [15:0] addr,
                           input bit [31:0] data, input bit [3:0] strb,
                           input int wait_cycles, input bit error,
                           input bit [31:0] read_data);
        cb.response_ready <= (wait_cycles == 0);
        cb.response_error <= error;
        cb.response_data <= read_data;
        @(cb iff (cb.sel_mon && !cb.enable_mon));
        `FAIL_UNLESS_EQUAL(cb.addr_mon, addr);
        `FAIL_UNLESS_EQUAL(cb.write_mon, wr);
        `FAIL_UNLESS(cb.reset_mon);
        @(cb);
        for (int i = 0; i < wait_cycles; i++) begin
            check_access(wr, addr, data, strb);
            `FAIL_IF(cb.ready_mon);
            if (i + 1 < wait_cycles) @(cb);
        end
        if (wait_cycles > 0) begin
            cb.response_ready <= 1'b1;
            @(cb);
        end
        check_access(wr, addr, data, strb);
        `FAIL_UNLESS(cb.ready_mon);
    endtask

    task automatic transfer(input bit wr, input int wait_cycles=0, input bit error=0);
        bit [31:0] data = $urandom;
        bit [15:0] addr = 16'($urandom);
        bit [3:0] strb = 4'($urandom);
        bit [31:0] read_data = $urandom;
        bit [31:0] got_data;
        bit got_error, timeout;
        fork
            begin
                if (wr) agent.write(addr, data, strb, got_error, timeout);
                else agent.read(addr, got_data, got_error, timeout);
            end
            respond(wr, addr, data, strb, wait_cycles, error, read_data);
        join
        `FAIL_IF(timeout);
        `FAIL_UNLESS_EQUAL(got_error, error);
        if (!wr) `FAIL_UNLESS_EQUAL(got_data, read_data);
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(zero_wait_transfers)
            transfer(1'b1);
            transfer(1'b0);
        `SVTEST_END

        `SVTEST(wait_states_and_strobes)
            repeat (8) begin
                transfer(1'b1, $urandom_range(1, 4));
                transfer(1'b0, $urandom_range(1, 4));
            end
        `SVTEST_END

        `SVTEST(error_responses)
            transfer(1'b1, 2, 1'b1);
            transfer(1'b0, 2, 1'b1);
        `SVTEST_END

        `SVTEST(byte_access)
            byte got;
            fork
                agent.write_byte(16'h23, 8'hAA);
                respond(1'b1, 16'h20, 32'hAA000000, 4'b1000, 1, 0, 0);
            join
            fork
                agent.read_byte(16'h23, got);
                respond(1'b0, 16'h20, 0, 0, 1, 0, 32'hAABBCCDD);
            join
            `FAIL_UNLESS_EQUAL(got, 8'hAA);
        `SVTEST_END

        `SVTEST(agent_timeout_cleanup)
            bit [31:0] data;
            bit error, timeout;
            agent.read(16'h40, data, error, timeout, 4);
            `FAIL_UNLESS(timeout);
            `FAIL_IF(cb.sel_mon || cb.enable_mon);
            agent.write(16'h40, '1, '1, error, timeout, 4);
            `FAIL_UNLESS(timeout);
            `FAIL_IF(cb.sel_mon || cb.enable_mon);
            transfer(1'b1);
            transfer(1'b0);
        `SVTEST_END

        `SVTEST(terminations)
            `FAIL_UNLESS_EQUAL(terminated_if.pclk, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.presetn, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.paddr, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.pprot, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.psel, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.penable, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.pwrite, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.pwdata, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.pstrb, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.pready, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.prdata, 0);
            `FAIL_UNLESS_EQUAL(terminated_if.pslverr, 1);
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : apb_intf_unit_test
