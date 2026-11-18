`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module pci_vpd_pkg_unit_test;
    import svunit_pkg::svunit_testcase;
    import pci_vpd_pkg::*;

    string name = "pci_vpd_pkg_ut";
    svunit_testcase svunit_ut;

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
    // Header and tag tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(resource_headers)
            vpd_rdt_t header;
            header = vpd_get_lrdt(VPD_TAG_ID);
            `FAIL_UNLESS_EQUAL(header.raw, 8'h82);
            `FAIL_UNLESS_EQUAL(vpd_get_type(header), VPD_RESOURCE_TYPE__LARGE);
            `FAIL_UNLESS_EQUAL(vpd_get_tag(header), VPD_TAG_ID);
            header = vpd_get_lrdt(VPD_TAG_VPD_R);
            `FAIL_UNLESS_EQUAL(header.raw, 8'h90);
            header = vpd_get_lrdt(VPD_TAG_VPD_W);
            `FAIL_UNLESS_EQUAL(header.raw, 8'h91);
            header = vpd_get_srdt(VPD_TAG_END, 0);
            `FAIL_UNLESS_EQUAL(header.raw, 8'h78);
            `FAIL_UNLESS_EQUAL(vpd_get_type(header), VPD_RESOURCE_TYPE__SMALL);
            `FAIL_UNLESS_EQUAL(vpd_get_tag(header), VPD_TAG_END);
            header = vpd_get_srdt(VPD_TAG_ID, 3);
            `FAIL_UNLESS_EQUAL(header.raw, 8'h13);
            `FAIL_UNLESS_EQUAL(header._small.len, 3);
        `SVTEST_END

        `SVTEST(unknown_tags)
            vpd_rdt_t header;
            header.raw = 8'hFE;
            `FAIL_UNLESS_EQUAL(vpd_get_tag(header), VPD_TAG_INVALID);
            header.raw = 8'h38;
            `FAIL_UNLESS_EQUAL(vpd_get_tag(header), VPD_TAG_INVALID);
            `FAIL_UNLESS_EQUAL(vpd_get_small_tag(VPD_TAG_VPD_R), VPD_TAG_INVALID);
            `FAIL_UNLESS_STR_EQUAL(vpd_get_tag_name(VPD_TAG_END), "END");
            `FAIL_UNLESS_STR_EQUAL(vpd_get_tag_name(VPD_TAG_VPD_R), "VPD-R");
            `FAIL_UNLESS_STR_EQUAL(vpd_get_tag_name(VPD_TAG_INVALID), "INVALID");
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : pci_vpd_pkg_unit_test
