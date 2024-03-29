`include "svunit_defines.svh"

module reg_proxy_unit_test;
    import svunit_pkg::svunit_testcase;
    import reg_verif_pkg::*;

    string name = "reg_proxy_ut";
    svunit_testcase svunit_ut;

    //===================================
    // This is the UUT that we're
    // running the Unit Tests on
    //===================================

    // AXI-L interface
    axi4l_intf axil_if ();
    axi4l_intf axil_if_to_blk ();

    // Implicitly connect signals to UUT
    axi4l_proxy DUT__axi4l_proxy  (
        .axi4l_if_from_controller ( axil_if ),
        .axi4l_if_to_peripheral   ( axil_if_to_blk )
    );
    reg_endian_check DUT__reg_endian_check (
        .axil_if ( axil_if_to_blk )
    );

    //===================================
    // Environment
    //===================================
    std_reset_intf reset_if (.clk(axil_if.aclk));

    // Assign reset interface
    assign axil_if.aresetn = !reset_if.reset;
    assign reset_if.ready = axil_if.aresetn;

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // AXI4-L register agent
    //
    // Executes register read/write transactions over the AXI-L control
    // interface.
    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent;

    // Proxy register agent
    reg_proxy_verif_pkg::reg_proxy_agent reg_proxy_agent;

    // Register block agent
    //
    // This is a custom agent class that is autogenerated by regio
    // based on the reg_endian_check.yaml register block specification.
    //
    // The agent class contains per-register write/read methods, allowing
    // registers to be referred to by name in the test code (rather than
    // by address) which improves readability and maintainability. Also,
    // the methods take as input (for writes) and return as output (for reads)
    // data types that correspond to the register format.
    reg_endian_reg_verif_pkg::reg_endian_check_reg_blk_agent reg_blk_agent;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create AXI-L register agent
        axil_reg_agent = new();

        // Connect AXI-L interface to AXI-L agent
        axil_reg_agent.axil_vif = axil_if;

        // Create proxy reg agent
        // (reg_endian_check block is connected to AXI-L interface via register-indirect proxy interface)
        reg_proxy_agent = new("reg_endian_check_proxy_agent", axil_reg_agent, 0);

        // Create block agent
        reg_blk_agent = new();
        reg_blk_agent.reg_agent = reg_proxy_agent;

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */

        axil_if.idle_controller();

        // Assert/deassert reset
        reset_if.pulse(8);

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

    // Test packed -> unpacked check
    // Write packed value and compare against values unpacked to byte monitors
    `SVTEST(endian_check_packed_to_unpacked)
        logic [3:0][7:0] exp_data;
        logic [3:0][7:0] got_data;

        exp_data = 32'h88776655;

        reg_blk_agent.write_scratchpad_packed(exp_data);
        reg_blk_agent.read_scratchpad_packed_monitor_byte_0(got_data[0]);
        reg_blk_agent.read_scratchpad_packed_monitor_byte_1(got_data[1]);
        reg_blk_agent.read_scratchpad_packed_monitor_byte_2(got_data[2]);
        reg_blk_agent.read_scratchpad_packed_monitor_byte_3(got_data[3]);

        `FAIL_UNLESS(got_data == exp_data);

    `SVTEST_END

    // Test unpacked -> packed check
    // Write unpacked byte values and compare against values packed to reg monitor
    `SVTEST(endian_check_unpacked_to_packed)
        logic [3:0][7:0] exp_data;
        logic [3:0][7:0] got_data;

        exp_data = 32'h88776655;

        reg_blk_agent.write_scratchpad_unpacked_byte_0(exp_data[0]);
        reg_blk_agent.write_scratchpad_unpacked_byte_1(exp_data[1]);
        reg_blk_agent.write_scratchpad_unpacked_byte_2(exp_data[2]);
        reg_blk_agent.write_scratchpad_unpacked_byte_3(exp_data[3]);
        reg_blk_agent.read_scratchpad_unpacked_monitor(got_data);

        `FAIL_UNLESS(got_data == exp_data);

    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
