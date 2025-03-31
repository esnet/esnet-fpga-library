`include "svunit_defines.svh"

module axi4l_intf_unit_test #(
    parameter string DUT_NAME = "axi4l_intf_connector"
);
    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import reg_pkg::*;
    import reg_example_reg_verif_pkg::*;

    string name = $sformatf("%s_unit_test", DUT_NAME);
    svunit_testcase svunit_ut;

    localparam int BAD_MEM_ADDRESS = example_reg_pkg::BLOCK_SIZE;

    //===================================
    // DUT
    //===================================
    // Interfaces
    axi4l_intf from_controller ();
    axi4l_intf to_peripheral ();

    generate
        case (DUT_NAME)
            "axi4l_intf_connector" : begin
                axi4l_intf_connector DUT (.axi4l_if_from_controller(from_controller), .axi4l_if_to_peripheral(to_peripheral));
            end
            "axi4l_intf_cdc" : begin
                axi4l_intf_cdc DUT (.clk_to_peripheral (clk), .axi4l_if_from_controller(from_controller), .axi4l_if_to_peripheral(to_peripheral));
            end
            "axi4l_pipe" : begin
                axi4l_pipe #(.STAGES(2)) DUT (.*);
            end
            "axi4l_pipe_auto" : begin
                axi4l_pipe_auto #() DUT (.*);
            end
            "axi4l_pipe_slr" : begin
                axi4l_pipe_slr #(.PRE_PIPE_STAGES(0),.POST_PIPE_STAGES(0)) DUT (.*);
            end
            "axi4l_pipe_slr_p1_p1" : begin
                axi4l_pipe_slr #(.PRE_PIPE_STAGES(1),.POST_PIPE_STAGES(2)) DUT (.*);
            end
        endcase
    endgenerate
   
    //===================================
    // Testbench
    //===================================
    logic aclk;
    logic aresetn;
    logic clk;
    logic srst;

    logic        input_valid;
    logic [31:0] input_data;
    logic        output_valid;
    logic [31:0] output_data;

    // Terminate AXI-L interface on representative register block
    example_component i_component (
        .clk          ( to_peripheral.aclk ),
        .axil_if      ( to_peripheral ),
        .input_valid  ( input_valid ),
        .input_data   ( input_data ),
        .output_valid ( output_valid ),
        .output_data  ( output_data )
    );

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(aclk, 4ns);

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    std_reset_intf #(.ACTIVE_LOW(1)) reset_if (.clk(aclk));

    assign aresetn = reset_if.reset;
    assign reset_if.ready = aresetn;

    // Drive controller interface
    assign from_controller.aclk = aclk;
    assign from_controller.aresetn = aresetn;

    // Agents
    axi4l_reg_agent #() reg_agent;
    example_reg_blk_agent reg_blk_agent;

    // Reset
    task reset();
        reset_if.pulse(8);
    endtask

    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) srst <= 1'b1;
        else          srst <= 1'b0;
    end

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Build and connect reg agent
        reg_agent = new();
        reg_agent.axil_vif = from_controller;
        reg_agent.set_random_aw_w_alignment(1);

        // Build reg block agents
        reg_blk_agent = new("example_reg_blk_agent");
        reg_blk_agent.reg_agent = reg_agent;

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */

        reg_agent.idle();

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

        `SVTEST(hard_reset)
        `SVTEST_END

        `SVTEST(read)
            example_reg_pkg::reg_ro_example_t exp_reg_ro_example = '{field0: 8'hAB, field1: example_reg_pkg::RO_EXAMPLE_FIELD1_XYZ};
            example_reg_pkg::reg_ro_example_t got_reg_ro_example;

            // Read RO register
            reg_blk_agent.read_ro_example(got_reg_ro_example);
            `FAIL_UNLESS_LOG(
                got_reg_ro_example === exp_reg_ro_example,
                $sformatf(
                    "ro_example register read mismatch . Exp: %0x, Got: %0x.",
                    exp_reg_ro_example,
                    got_reg_ro_example
                )
            );

        `SVTEST_END

        `SVTEST(write_read)
            example_reg_pkg::reg_rw_example_t exp_reg_rw_example;
            example_reg_pkg::reg_rw_example_t got_reg_rw_example;

            // Write random value
            exp_reg_rw_example = $urandom();
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
                exp_reg_rw_example = $urandom();
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
                exp_reg_wr_evt_example = $urandom();
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
            reg_agent.write_bad_addr(BAD_MEM_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END
        
        `SVTEST(rd_peripheral_error)
            bit error;
            string msg;
            reg_agent.read_bad_addr(BAD_MEM_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule

// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific AXI4L DUT in a way
//  that maintains SVUnit compatibility
`define AXI4L_INTF_UNIT_TEST(DUT_NAME)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  axi4l_intf_unit_test #(DUT_NAME) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  function void __register_tests();\
    test.__register_tests();\
  endfunction\
  task run();\
    test.run();\
  endtask

module axi4l_intf_connector_unit_test;
`AXI4L_INTF_UNIT_TEST("axi4l_intf_connector")
endmodule

module axi4l_intf_cdc_unit_test;
`AXI4L_INTF_UNIT_TEST("axi4l_intf_connector")
endmodule

module axi4l_pipe_unit_test;
`AXI4L_INTF_UNIT_TEST("axi4l_pipe")
endmodule

module axi4l_pipe_auto_unit_test;
`AXI4L_INTF_UNIT_TEST("axi4l_pipe_auto")
endmodule

module axi4l_pipe_slr_unit_test;
`AXI4L_INTF_UNIT_TEST("axi4l_pipe_slr")
endmodule

module axi4l_pipe_slr_p1_p1_unit_test;
`AXI4L_INTF_UNIT_TEST("axi4l_pipe_slr_p1_p1")
endmodule
