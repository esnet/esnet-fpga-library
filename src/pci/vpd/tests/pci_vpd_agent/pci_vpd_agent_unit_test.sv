`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module pci_vpd_agent_unit_test;
    import svunit_pkg::svunit_testcase;
    import pci_vpd_pkg::*;
    import pci_vpd_verif_pkg::*;

    string name = "pci_vpd_agent_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Agent probe for protected transport status
    //===================================
    class probe_agent extends pci_vpd_intf_agent;
        function new();
            super.new("vpd_probe", 2, 12);
        endfunction

        task read_result(input int addr, output byte data,
                         output bit error, output bit timeout);
            _read_byte(addr, data, error, timeout);
        endtask
    endclass

    probe_agent agent;

    //===================================
    // Clock and byte-addressable peripheral model
    //===================================
    logic clk;
    logic srst = 1'b1;
    logic respond = 1'b1;
    int read_delay = 0;
    pci_vpd_intf vpd_if (.clk);
    `SVUNIT_CLK_GEN(clk, 5ns);

    byte memory [2**VPD_ADDR_WID];
    bit pending = 0;
    int remaining = 0;
    logic [VPD_ADDR_WID-1:0] pending_addr;

    always @(posedge clk) begin
        vpd_if.rd_vld <= 1'b0;
        if (srst) begin
            pending <= 0;
            remaining <= 0;
            vpd_if.rd_data <= '0;
            foreach (memory[i]) memory[i] <= 0;
        end else begin
            if (vpd_if.req) begin
                if (vpd_if.wr_rd_n) memory[vpd_if.addr] <= vpd_if.wr_data;
                else if (respond) begin
                    pending <= 1;
                    pending_addr <= vpd_if.addr;
                    remaining <= read_delay;
                end
            end
            if (pending) begin
                if (remaining == 0) begin
                    vpd_if.rd_data <= memory[pending_addr];
                    vpd_if.rd_vld <= 1'b1;
                    pending <= 0;
                end else remaining <= remaining - 1;
            end
        end
    end

    //===================================
    // Peripheral controls and resource fixtures
    //===================================
    wire req = vpd_if.req;
    clocking cb @(negedge clk);
        output srst, respond, read_delay;
        input req;
    endclocking

    task automatic load_image(input byte image[]);
        foreach (image[i]) agent.write_byte(i, image[i]);
    endtask

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        agent = new();
        agent.vpd_vif = vpd_if;
        agent.disable_autostart();
        agent.build();
        @(cb);
        cb.srst <= 1'b1;
        cb.respond <= 1'b1;
        cb.read_delay <= 0;
        repeat (2) @(cb);
        agent.idle();
        cb.srst <= 1'b0;
        @(cb);
    endtask

    task teardown();
        agent.destroy();
        agent = null;
        svunit_ut.teardown();
    endtask

    //===================================
    // Transport and resource-reader tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(byte_access_and_read_timeout_setting)
            byte data;
            bit error, timeout;
            cb.read_delay <= 4;
            @(cb);
            agent.write_byte(17, 8'hA5);
            agent.read_result(17, data, error, timeout);
            `FAIL_IF(error || timeout);
            `FAIL_UNLESS_LOG(data == 8'hA5, $sformatf("Readback: 0x%02x", data));
            agent.write_byte((1 << VPD_ADDR_WID)-1, 8'h5A);
            agent.read_byte((1 << VPD_ADDR_WID)-1, data);
            `FAIL_UNLESS_EQUAL(data, 8'h5A);
        `SVTEST_END

        `SVTEST(timeout_and_recovery)
            byte data;
            bit error, timeout;
            agent.set_rd_timeout(4);
            cb.respond <= 0;
            @(cb);
            agent.read_result(0, data, error, timeout);
            `FAIL_IF(error);
            `FAIL_UNLESS(timeout);
            @(cb);
            `FAIL_IF(cb.req);
            cb.respond <= 1;
            @(cb);
            agent.set_rd_timeout(0);
            agent.write_byte(0, 8'h3C);
            agent.read_result(0, data, error, timeout);
            `FAIL_IF(error || timeout);
            `FAIL_UNLESS_EQUAL(data, 8'h3C);
        `SVTEST_END

        `SVTEST(small_resources_and_end_tag)
            byte image[] = '{8'h13, 8'h45, 8'h53, 8'h4E, 8'h78};
            vpd_t vpd;
            load_image(image);
            agent.read();
            vpd = agent.get_vpd();
            `FAIL_UNLESS(agent.is_valid());
            `FAIL_UNLESS_EQUAL(vpd.resources.size(), 2);
            `FAIL_UNLESS_EQUAL(vpd.resources[0].value.size(), 3);
            `FAIL_UNLESS_STR_EQUAL(string_pkg::byte_array_to_ascii_string(vpd.resources[0].value), "ESN");
            `FAIL_UNLESS_EQUAL(vpd.resources[1].tag, VPD_TAG_END);
            `FAIL_UNLESS_EQUAL(vpd.resources[1].value.size(), 0);
        `SVTEST_END

        `SVTEST(read_and_parse_vpd_r)
            byte image[] = '{8'h82, 3, 0, 8'h45, 8'h53, 8'h4E,
                             8'h90, 10, 0, 8'h50, 8'h4E, 3, 8'h41, 8'h42,
                             8'h43, 8'h52, 8'h56, 1, 0, 8'h78};
            byte sum = 0;
            vpd_t vpd;
            vpd_r_t parsed;
            value_t value;
            for (int i = 0; i < 18; i++) sum += image[i];
            image[18] = -sum;
            load_image(image);
            agent.read();
            vpd = agent.get_vpd();
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_UNLESS(vpd.valid && parsed.valid && parsed.checksum_ok);
            value = vpd_r_get_record_value(parsed, "PN");
            `FAIL_UNLESS_STR_EQUAL(string_pkg::byte_array_to_ascii_string(value), "ABC");
        `SVTEST_END

        `SVTEST(large_resource_length)
            byte image[];
            vpd_t vpd;
            image = new[304];
            image[0] = 8'h82;
            image[1] = 8'h2C;
            image[2] = 8'h01;
            for (int i = 0; i < 300; i++) image[i+3] = byte'(i);
            image[303] = 8'h78;
            load_image(image);
            agent.read();
            vpd = agent.get_vpd();
            `FAIL_UNLESS(vpd.valid);
            `FAIL_UNLESS_EQUAL(vpd.resources[0].value.size(), 300);
            `FAIL_UNLESS_EQUAL(vpd.resources[0].value[299], byte'(299));
        `SVTEST_END

        `SVTEST(oversized_resource)
            byte image[] = '{8'h82, 8'hFF, 8'hFF};
            load_image(image);
            agent.read();
            `FAIL_IF(agent.is_valid());
        `SVTEST_END

        `SVTEST(invalid_resource)
            byte image[] = '{8'h00};
            load_image(image);
            agent.read();
            `FAIL_IF(agent.is_valid());
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : pci_vpd_agent_unit_test
