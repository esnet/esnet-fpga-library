`include "svunit_defines.svh"

module axi4l_apb_proxy_unit_test;
    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import reg_verif_pkg::*;
    import example_reg_pkg::*;
    import reg_example_reg_verif_pkg::*;

    string name = "axi4l_apb_proxy_ut";
    svunit_testcase svunit_ut;

    localparam int BAD_MEM_ADDRESS = 8000; // Unmapped memory (between regions 1 and 2)
    localparam int BAD_REG_ADDRESS = 1000; // Exceeds maximum register address within block

    //===================================
    // DUT
    //===================================
    // Interfaces
    axi4l_intf axi4l_if ();
    apb_intf   apb_if ();

    axi4l_apb_proxy DUT(.*);

    //===================================
    // Testbench
    //===================================
    reg_intf reg_if ();
    example_reg_intf example_reg_if ();
    apb_peripheral i_tb_apb_peripheral (
        .apb_if ( apb_if ),
        .reg_if ( reg_if )
    );
    example_reg_blk__reg_if i__reg_example_blk (
        .reg_if ( reg_if ),
        .reg_blk_if ( example_reg_if )
    );
    assign example_reg_if.ro_example_nxt_v = 1'b1;
    assign example_reg_if.ro_example_nxt = '{field0: 8'hAB, field1: RO_EXAMPLE_FIELD1_XYZ};

    std_reset_intf reset_if (.clk(axi4l_if.aclk));

    // Connect reset interface
    assign axi4l_if.aresetn = !reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    // Agents
    axi4l_reg_agent #() axil_reg_agent;
    reg_proxy_agent reg_agent;
    example_reg_blk_agent reg_blk_agent;

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axi4l_if.aclk, 4ns);

    // Reset
    task reset();
        reset_if.pulse(8);
    endtask

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Build and connect reg agent
        axil_reg_agent = new();
        axil_reg_agent.axil_vif = axi4l_if;
        axil_reg_agent.set_random_aw_w_alignment(1);

        // Create proxy reg agent
        // (example_reg block is connected to AXI-L interface via register-indirect proxy interface)
        reg_agent = new("example_reg_proxy_agent", axil_reg_agent, 0);

        reg_blk_agent = new("example_reg_blk_agent");
        reg_blk_agent.reg_agent = reg_agent;

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */

        axi4l_if.idle_controller();

        reset();

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

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(read)
            example_reg_pkg::reg_ro_example_t exp_reg_ro_example = '{field0: 8'hAB, field1: example_reg_pkg::RO_EXAMPLE_FIELD1_XYZ};
            example_reg_pkg::reg_ro_example_t got_reg_ro_example;

            // Read RO register
            reg_blk_agent.read_ro_example(got_reg_ro_example);
            `FAIL_UNLESS_LOG(
                got_reg_ro_example === exp_reg_ro_example,
                $sformatf(
                    "ro_example register read mismatch. Exp: %0x, Got: %0x.",
                    exp_reg_ro_example,
                    got_reg_ro_example
                )
            );

        `SVTEST_END

        `SVTEST(write_read)
            example_reg_pkg::reg_rw_example_t exp_reg_rw_example;
            example_reg_pkg::reg_rw_example_t got_reg_rw_example;

            // Write random value
            randomize(exp_reg_rw_example);
            reg_blk_agent.write_rw_example(exp_reg_rw_example);

            // Read and check
            reg_blk_agent.read_rw_example(got_reg_rw_example);

            `FAIL_UNLESS_LOG(
                got_reg_rw_example === exp_reg_rw_example,
                $sformatf(
                    "rw_example register read mismatch. Exp: %0x, Got: %0x.",
                    exp_reg_rw_example,
                    got_reg_rw_example
                )
            );
        `SVTEST_END

        `SVTEST(read_write_stress)
            const int __NUM_WRITES = 1000;

            for (int k = 0; k < __NUM_WRITES; k++) begin
                example_reg_pkg::reg_rw_example_t exp_reg_rw_example;
                example_reg_pkg::reg_rw_example_t got_reg_rw_example;
                example_reg_pkg::reg_rw_example_t exp_reg_wr_evt_example;
                example_reg_pkg::reg_rw_example_t got_reg_wr_evt_example;

                // Write random value to RW register
                randomize(exp_reg_rw_example);
                reg_blk_agent.write_rw_example(exp_reg_rw_example);

                // Read and check
                reg_blk_agent.read_rw_example(got_reg_rw_example);

                `FAIL_UNLESS_LOG(
                    got_reg_rw_example === exp_reg_rw_example,
                    $sformatf(
                        "rw_example register read mismatch. Exp: %0x, Got: %0x.",
                        exp_reg_rw_example,
                        got_reg_rw_example
                    )
                );

                // Write random value to WR_EVT register
                randomize(exp_reg_wr_evt_example);
                reg_blk_agent.write_wr_evt_example(exp_reg_wr_evt_example);

                // Read and check
                reg_blk_agent.read_wr_evt_example(got_reg_wr_evt_example);

                `FAIL_UNLESS_LOG(
                    got_reg_wr_evt_example === exp_reg_wr_evt_example,
                    $sformatf(
                        "wr_evt_example register read mismatch. Exp: %0x, Got: %0x.",
                        exp_reg_wr_evt_example,
                        got_reg_wr_evt_example
                    )
                );
            end
        `SVTEST_END

        `SVTEST(write_byte)
            logic [31:0] addr;
            logic [3:0][7:0] exp_reg_data = 'h12345678;
            logic [31:0] got_reg_data;
            byte exp_byte_data = 'hAC;

            // Manipulate ID register in stats block 1 (base offset 4096)
            addr = example_reg_pkg::OFFSET_RW_MONOLITHIC_EXAMPLE;

            // Write entire 32-bit RW register
            reg_agent.write_reg(addr, exp_reg_data);

            // Check RW register
            reg_agent.read_reg(addr, got_reg_data);

            `FAIL_UNLESS_LOG(
                got_reg_data == exp_reg_data,
                $sformatf(
                    "Reg write/read mismatch. Wrote: %0x, Read: %0x.",
                    exp_reg_data, got_reg_data
                )
            );

            // Write single byte of RW register
            reg_agent.write_byte(addr + 1, exp_byte_data);

            exp_reg_data[1] = exp_byte_data;

            // Read back entire register
            reg_agent.read_reg(addr, got_reg_data);
            `FAIL_UNLESS_LOG(
                got_reg_data == exp_reg_data,
                $sformatf(
                    "Reg byte write/read mismatch. Wrote: %0x, Read: %0x.",
                    exp_reg_data, got_reg_data
                )
            );

        `SVTEST_END

        `SVTEST(read_byte)
            logic [31:0] addr;
            logic [3:0][7:0] exp_reg_data = 'h12345678;
            logic [31:0] got_reg_data;
            byte exp_byte_data = 'h56;
            byte got_byte_data;

            // Manipulate ID register in stats block 1 (base offset 4096)
            addr = example_reg_pkg::OFFSET_RW_MONOLITHIC_EXAMPLE;

            // Write entire 32-bit RW register
            reg_agent.write_reg(addr, exp_reg_data);

            // Check RW register
            reg_agent.read_reg(addr, got_reg_data);

            `FAIL_UNLESS_LOG(
                got_reg_data == exp_reg_data,
                $sformatf(
                    "Reg write/read mismatch. Wrote: %0x, Read: %0x.",
                    exp_reg_data, got_reg_data
                )
            );

            // Read single byte of RW register
            reg_agent.read_byte(addr + 1, got_byte_data);

            `FAIL_UNLESS_LOG(
                got_byte_data == exp_byte_data,
                $sformatf(
                    "Reg byte read mismatch. Exp: %0x, Got: %0x.",
                    exp_byte_data, got_byte_data
                )
            );

        `SVTEST_END

        `SVTEST(wr_peripheral_error)
            bit error;
            string msg;
            reg_agent.write_bad_addr(BAD_REG_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

        `SVTEST(rd_peripheral_error)
            bit error;
            string msg;
            reg_agent.read_bad_addr(BAD_REG_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule


