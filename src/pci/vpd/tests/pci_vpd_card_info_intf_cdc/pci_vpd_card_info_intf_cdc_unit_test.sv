`include "svunit_defines.svh"
`define SVUNIT_TIMEOUT 1ms

module pci_vpd_card_info_intf_cdc_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pci_vpd_card_info_intf_cdc_ut";
    svunit_testcase svunit_ut;
    logic provider_clk;
    logic consumer_clk;
    logic provider_srst = 1'b1;
    logic consumer_srst = 1'b1;
    int response_delay = 0;
    int cycles_left;
    int provider_requests;
    logic provider_pending = 1'b0;
    logic [8:0] pending_addr;

    localparam time PROVIDER_HALF = `PROVIDER_HALF_NS * 1ns;
    localparam time CONSUMER_HALF = `CONSUMER_HALF_NS * 1ns;
    `SVUNIT_CLK_GEN(provider_clk, PROVIDER_HALF);
    `SVUNIT_CLK_GEN(consumer_clk, CONSUMER_HALF);

    pci_vpd_card_info_intf provider_if (.clk(provider_clk));
    pci_vpd_card_info_intf consumer_if (.clk(consumer_clk));
    assign provider_if.srst = provider_srst;

    pci_vpd_card_info_intf_cdc DUT (
        .consumer_srst,
        .card_info_if_from_provider ( provider_if ),
        .card_info_if_to_consumer   ( consumer_if )
    );

    function automatic byte expected_byte(input logic [8:0] addr);
        return addr[7:0] ^ {7'b0, addr[8]} ^ 8'h96;
    endfunction

    // Byte data is valid for one provider cycle only.
    always @(posedge provider_clk) begin
        provider_if.rd_vld <= 1'b0;
        provider_if.rd_data <= 8'hxx;
        if (provider_srst) begin
            provider_pending <= 1'b0;
            provider_requests <= 0;
        end else begin
            if (provider_if.rd) begin
                provider_pending <= 1'b1;
                pending_addr <= provider_if.rd_addr;
                cycles_left <= response_delay;
                provider_requests <= provider_requests + 1;
            end
            if (provider_pending) begin
                if (cycles_left == 0) begin
                    provider_if.rd_vld <= 1'b1;
                    provider_if.rd_data <= expected_byte(pending_addr);
                    provider_pending <= 1'b0;
                end else cycles_left <= cycles_left - 1;
            end
        end
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        provider_srst = 1;
        consumer_srst = 1;
        provider_if.vld = 0;
        provider_if.error = 0;
        provider_if.len = 0;
        consumer_if.rd = 0;
        consumer_if.rd_addr = 0;
        response_delay = 0;
        repeat (16) @(negedge provider_clk);
        provider_srst = 0;
        @(negedge consumer_clk);
        consumer_srst = 0;
        repeat (64) @(negedge consumer_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task issue_read(input logic [8:0] addr);
        @(negedge consumer_clk);
        consumer_if.rd_addr = addr;
        consumer_if.rd = 1;
        @(negedge consumer_clk);
        consumer_if.rd = 0;
    endtask

    task check_response(input logic [8:0] addr);
        bit received;
        received = 0;
        for (int i = 0; i < 2000; i++) begin
            @(posedge consumer_clk);
            if (consumer_if.rd_vld) begin
                `FAIL_UNLESS_EQUAL(consumer_if.rd_data, expected_byte(addr));
                received = 1;
                break;
            end
        end
        `FAIL_UNLESS(received);
    endtask

    `SVUNIT_TESTS_BEGIN
        `SVTEST(coherent_status_and_error)
            @(negedge provider_clk);
            provider_if.len = 9'd403;
            provider_if.vld = 1;
            wait(consumer_if.vld);
            `FAIL_UNLESS_EQUAL(consumer_if.len, 403);
            `FAIL_IF(consumer_if.error);
            @(negedge provider_clk);
            provider_if.error = 1;
            provider_if.vld = 0;
            provider_if.len = 0;
            wait(consumer_if.error);
            `FAIL_IF(consumer_if.vld);
            `FAIL_UNLESS_EQUAL(consumer_if.len, 0);
        `SVTEST_END

        `SVTEST(all_byte_addresses_and_pulse_valid_data)
            for (int i = 0; i < 512; i++) begin
                response_delay = i % 4;
                issue_read(9'(i));
                check_response(9'(i));
            end
            `FAIL_UNLESS_EQUAL(provider_requests, 512);
        `SVTEST_END

        `SVTEST(consumer_reset_drains_old_response)
            response_delay = 160;
            issue_read(9'h123);
            wait(provider_pending);
            @(negedge consumer_clk);
            consumer_srst = 1;
            repeat (16) @(negedge consumer_clk);
            consumer_srst = 0;
            repeat (64) @(negedge consumer_clk);
            response_delay = 0;
            issue_read(9'h056);
            check_response(9'h056);
            `FAIL_UNLESS_EQUAL(provider_requests, 2);
        `SVTEST_END

        `SVTEST(provider_reset_discards_pending_read)
            response_delay = 160;
            issue_read(9'h123);
            wait(provider_pending);
            @(negedge provider_clk);
            provider_srst = 1;
            repeat (16) @(negedge provider_clk);
            provider_srst = 0;
            repeat (64) @(negedge consumer_clk);
            response_delay = 0;
            issue_read(9'h1fe);
            check_response(9'h1fe);
            `FAIL_UNLESS_EQUAL(provider_requests, 1);
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule
