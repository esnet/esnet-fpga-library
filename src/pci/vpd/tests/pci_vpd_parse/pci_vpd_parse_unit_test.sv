`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module pci_vpd_parse_unit_test;
    import svunit_pkg::svunit_testcase;
    import pci_vpd_pkg::*;
    import pci_vpd_verif_pkg::*;

    string name = "pci_vpd_parse_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Resource fixtures
    //===================================
    function automatic vpd_t make_vpd(input int reserved_bytes=0);
        vpd_t vpd;
        vpd.valid = 1;
        vpd.resources = new[2];
        vpd.resources[0].tag = VPD_TAG_ID;
        vpd.resources[0].value = new[3];
        vpd.resources[0].value = '{8'h45, 8'h53, 8'h4E};
        vpd.resources[0].sum = 8'h82 + 3;
        foreach (vpd.resources[0].value[i])
            vpd.resources[0].sum += vpd.resources[0].value[i];
        vpd.resources[1].tag = VPD_TAG_VPD_R;
        // PN="ABC", followed by the final RV checksum record.
        vpd.resources[1].value = new[10];
        vpd.resources[1].value = '{8'h50, 8'h4E, 3, 8'h41, 8'h42, 8'h43,
                                 8'h52, 8'h56, 1, 0};
        vpd.resources[1].value = new[10+reserved_bytes](vpd.resources[1].value);
        vpd.resources[1].value[8] = 1 + reserved_bytes;
        for (int i = 10; i < vpd.resources[1].value.size(); i++)
            vpd.resources[1].value[i] = byte'(8'h55 + i);
        // Resource sums include the resource headers and payload bytes.
        vpd.resources[1].sum = 8'h90 + vpd.resources[1].value.size();
        foreach (vpd.resources[1].value[i])
            vpd.resources[1].sum += vpd.resources[1].value[i];
        vpd.resources[1].value[9] = -(vpd.resources[0].sum + vpd.resources[1].sum);
        vpd.resources[1].sum += vpd.resources[1].value[9];
        // Reserved bytes follow the checksum byte and are outside its coverage.
        for (int i = 10; i < vpd.resources[1].value.size(); i++) begin
            vpd.resources[1].value[9] += vpd.resources[1].value[i];
            vpd.resources[1].sum += vpd.resources[1].value[i];
        end
        return vpd;
    endfunction

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Parsing, lookup, and formatting tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(records_and_checksum)
            vpd_t vpd = make_vpd();
            vpd_r_t parsed;
            value_t value;
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_UNLESS(parsed.valid);
            `FAIL_UNLESS(parsed.checksum_ok);
            `FAIL_UNLESS_EQUAL(parsed.records.size(), 2);
            value = vpd_r_get_record_value(parsed, "PN");
            `FAIL_UNLESS_EQUAL(value.size(), 3);
            `FAIL_UNLESS_STR_EQUAL(string_pkg::byte_array_to_ascii_string(value), "ABC");
            value = vpd_r_get_record_value(parsed, "missing");
            `FAIL_UNLESS_EQUAL(value.size(), 0);
            vpd.resources[1].value[9]++;
            vpd.resources[1].sum++;
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_UNLESS(parsed.valid);
            `FAIL_IF(parsed.checksum_ok);
        `SVTEST_END

        `SVTEST(reserved_bytes_after_checksum)
            vpd_t vpd = make_vpd(3);
            vpd_r_t parsed;
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_UNLESS(parsed.valid);
            `FAIL_UNLESS(parsed.checksum_ok);
            vpd.resources[1].value[10]++;
            vpd.resources[1].sum++;
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_UNLESS(parsed.checksum_ok);
        `SVTEST_END

        `SVTEST(empty_final_record)
            vpd_t vpd = make_vpd();
            vpd_r_t parsed;
            vpd.resources[1].value = new[7];
            vpd.resources[1].value = '{8'h50, 8'h4E, 1, 8'h41, 8'h5A, 8'h5A, 0};
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_UNLESS(parsed.valid);
            `FAIL_UNLESS_EQUAL(parsed.records.size(), 2);
            `FAIL_UNLESS_EQUAL(parsed.records[1].value.size(), 0);
        `SVTEST_END

        `SVTEST(invalid_and_truncated)
            vpd_t vpd = make_vpd();
            vpd_r_t parsed;
            vpd_resource_t resource;
            vpd.valid = 0;
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_IF(parsed.valid);
            resource = vpd_get_resource(vpd, VPD_TAG_ID);
            `FAIL_UNLESS_EQUAL(resource.tag, VPD_TAG_INVALID);
            `FAIL_UNLESS_EQUAL(resource.value.size(), 0);
            vpd.valid = 1;
            resource = vpd_get_resource(vpd, VPD_TAG_VPD_W);
            `FAIL_UNLESS_EQUAL(resource.tag, VPD_TAG_INVALID);
            vpd.resources[1].value = new[5];
            vpd.resources[1].value = '{8'h50, 8'h4E, 4, 8'h41, 8'h42};
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_IF(parsed.valid);
            vpd.resources[1].value = new[2];
            parsed = vpd_parse_vpd_r(vpd);
            `FAIL_IF(parsed.valid);
        `SVTEST_END

        `SVTEST(large_resource_formatting)
            vpd_resource_t resource;
            string formatted;
            resource.tag = VPD_TAG_VPD_R;
            resource.sum = 0;
            resource.value = new[300];
            foreach (resource.value[i]) resource.value[i] = 8'hAB;
            formatted = vpd_resource_to_string(resource);
            `FAIL_UNLESS(formatted.len() > 600);
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : pci_vpd_parse_unit_test
