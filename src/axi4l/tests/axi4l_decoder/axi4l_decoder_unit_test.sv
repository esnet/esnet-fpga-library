`include "svunit_defines.svh"

module axi4l_decoder_unit_test;
    import svunit_pkg::svunit_testcase;
    import axi4l_verif_pkg::*;
    import mem_map_pkg::*;
    import reg_example_reg_verif_pkg::*;

    string name = "axi4l_decoder_unit_test";
    svunit_testcase svunit_ut;

    localparam map_spec_t MEM_MAP_TOP = '{
        NUM_REGIONS: 3,
        region : '{
            0: '{base: 0,     size: 32768},
            1: '{base: 32768, size: 32768},
            2: '{base: 65536, size: 32768},
            default: DEFAULT_REGION_SPEC
        }
    };

    localparam map_spec_t MEM_MAP_SUBDECODER = '{
        NUM_REGIONS: 4,
        region : '{
            0: '{base: 0,     size: 4096},
            1: '{base: 4096,  size: 2048},
            2: '{base: 8192,  size: 8192},
            3: '{base: 16384, size: 8192},
            default: DEFAULT_REGION_SPEC
        }
    };

    localparam int SUBDECODERS = MEM_MAP_TOP.NUM_REGIONS;
    localparam int MISSING_SUBDECODERS = 1;
    localparam int VALID_SUBDECODERS = SUBDECODERS - MISSING_SUBDECODERS;

    localparam int CLIENTS = MEM_MAP_SUBDECODER.NUM_REGIONS;
    localparam int MISSING_CLIENTS = 1;
    localparam int VALID_CLIENTS = CLIENTS - MISSING_CLIENTS;

    localparam int BAD_MEM_ADDRESS = 8000; // Unmapped memory (between regions 1 and 2)
    localparam int BAD_REG_ADDRESS = 1000; // Exceeds maximum register address within block

    //===================================
    // Local Signals
    //===================================
    logic aclk;
    logic clk;
    logic srst;

    logic        input_valid  [VALID_SUBDECODERS][VALID_CLIENTS];
    logic [31:0] input_data   [VALID_SUBDECODERS][VALID_CLIENTS];
    logic        output_valid [VALID_SUBDECODERS][VALID_CLIENTS];
    logic [31:0] output_data  [VALID_SUBDECODERS][VALID_CLIENTS];
    //===================================
    // DUT
    //===================================
    // Interfaces
    axi4l_intf axil_if                            ();
    axi4l_intf axil_subdecoder_if   [SUBDECODERS] ();

    axi4l_decoder #(
        .MEM_MAP ( MEM_MAP_TOP )
    ) i_axi4l_decoder_top (
        .axi4l_if         ( axil_if ),
        .axi4l_client_if  ( axil_subdecoder_if )
    );

    // Instantiate subdecoders
    generate
        for (genvar g_sd = 0; g_sd < SUBDECODERS; g_sd++) begin : g__subdecoder
            axi4l_intf axil_subdecoder_if__demarc ();
            axi4l_intf axil_client_if [CLIENTS]   ();

            axi4l_reg_slice #(
                .CONFIG ( axi4l_pkg::REG_SLICE_SLR_CROSSING )
            ) i_axi4l_reg_slice (
                .axi4l_if_from_controller ( axil_subdecoder_if[g_sd] ),
                .axi4l_if_to_peripheral   ( axil_subdecoder_if__demarc )
            );

            axi4l_decoder #(
                .MEM_MAP ( MEM_MAP_SUBDECODER )
            ) i_axi4l_subdecoder (
                .axi4l_if        (axil_subdecoder_if__demarc),
                .axi4l_client_if (axil_client_if)
            );
    
            // Connect clients
            for (genvar g_if = 0; g_if < VALID_CLIENTS; g_if++) begin : g__client
                axi4l_intf axil_client_if__clk  ();
                // Implement CDC on client interfaces
                axi4l_intf_cdc i_axil_cdc (
                    .axi4l_if_from_controller ( axil_client_if [g_if] ),
                    .clk_to_peripheral        ( clk ),
                    .axi4l_if_to_peripheral   ( axil_client_if__clk   )
                );
                // Terminate client interface
                example_component i_component (
                    .clk          ( clk ),
                    .axil_if      ( axil_client_if__clk ),
                    .input_valid  ( input_valid  [g_sd][g_if] ),
                    .input_data   ( input_data   [g_sd][g_if] ),
                    .output_valid ( output_valid [g_sd][g_if] ),
                    .output_data  ( output_data  [g_sd][g_if] )
                );
            end : g__client
        end : g__subdecoder
    endgenerate

    //===================================
    // Testbench
    //===================================
    std_reset_intf #(.ACTIVE_LOW(1)) reset_if (.clk(axil_if.aclk));

    // Connect reset interface
    assign axil_if.aresetn = reset_if.reset;
    assign reset_if.ready = axil_if.aresetn;

    // Agents
    axi4l_reg_agent #() reg_agent;
    example_reg_blk_agent reg_blk_agent [VALID_SUBDECODERS][VALID_CLIENTS];

    // Assign AXI-L clock (125MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 4ns);

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(clk, 1.5ns);

    // Reset
    task reset();
        reset_if.pulse(8);
    endtask

    always @(posedge clk or negedge axil_if.aresetn) begin
        if (!axil_if.aresetn) srst <= 1'b1;
        else                  srst <= 1'b0;
    end

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Build and connect reg agent
        reg_agent = new();
        reg_agent.axil_vif = axil_if;
        reg_agent.set_random_aw_w_alignment(1);

        // Build reg block agents
        for (int i = 0; i < VALID_SUBDECODERS; i++) begin
            automatic region_spec_t region_top = MEM_MAP_TOP.region[i];
            for (int j = 0; j < VALID_CLIENTS; j++) begin
                automatic region_spec_t region_client = MEM_MAP_SUBDECODER.region[j];
                reg_blk_agent[i][j] = new($sformatf("example_reg_blk_agent[%0d][%0d]", i, j), region_top.base + region_client.base);
                reg_blk_agent[i][j].reg_agent = reg_agent;
            end
        end

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */

        axil_if.idle_controller();

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
            for (int i = 0; i < VALID_SUBDECODERS; i++) begin
                for (int j = 0; j < VALID_CLIENTS; j++) begin
                    reg_blk_agent[i][j].read_ro_example(got_reg_ro_example);
                    `FAIL_UNLESS_LOG(
                        got_reg_ro_example === exp_reg_ro_example,
                        $sformatf(
                            "ro_example register read mismatch (client [%0d:%0d]). Exp: %0x, Got: %0x.",
                            i, j,
                            exp_reg_ro_example,
                            got_reg_ro_example
                        )
                    );
                end
            end

        `SVTEST_END

        `SVTEST(write_read)
            example_reg_pkg::reg_rw_example_t exp_reg_rw_example;
            example_reg_pkg::reg_rw_example_t got_reg_rw_example;

            for (int i = 0; i < VALID_SUBDECODERS; i++) begin
                for (int j = 0; j < VALID_CLIENTS; j++) begin
                    // Write random value
                    randomize(exp_reg_rw_example);
                    reg_blk_agent[i][j].write_rw_example(exp_reg_rw_example);

                    // Read and check
                    reg_blk_agent[i][j].read_rw_example(got_reg_rw_example);

                    `FAIL_UNLESS_LOG(
                        got_reg_rw_example === exp_reg_rw_example,
                        $sformatf(
                            "rw_example register read mismatch (client [%0d,%0d]). Exp: %0x, Got: %0x.",
                            i, j,
                            exp_reg_rw_example,
                            got_reg_rw_example
                        )
                    );
                end
            end
        `SVTEST_END

        `SVTEST(read_write_stress)
            const int __NUM_WRITES = 1000;

            for (int i = 0; i < VALID_SUBDECODERS; i++) begin
                for (int j = 0; j < VALID_CLIENTS; j++) begin
                    for (int k = 0; k < __NUM_WRITES; k++) begin
                        example_reg_pkg::reg_rw_example_t exp_reg_rw_example;
                        example_reg_pkg::reg_rw_example_t got_reg_rw_example;
                        example_reg_pkg::reg_rw_example_t exp_reg_wr_evt_example;
                        example_reg_pkg::reg_rw_example_t got_reg_wr_evt_example;

                        // Write random value to RW register
                        randomize(exp_reg_rw_example);
                        reg_blk_agent[i][j].write_rw_example(exp_reg_rw_example);

                        // Read and check
                        reg_blk_agent[i][j].read_rw_example(got_reg_rw_example);

                        `FAIL_UNLESS_LOG(
                            got_reg_rw_example === exp_reg_rw_example,
                            $sformatf(
                                "rw_example register read mismatch (client [%0d:%0d]). Exp: %0x, Got: %0x.",
                                i, j,
                                exp_reg_rw_example,
                                got_reg_rw_example
                            )
                        );

                        // Write random value to WR_EVT register
                        randomize(exp_reg_wr_evt_example);
                        reg_blk_agent[i][j].write_wr_evt_example(exp_reg_wr_evt_example);

                        // Read and check
                        reg_blk_agent[i][j].read_wr_evt_example(got_reg_wr_evt_example);

                        `FAIL_UNLESS_LOG(
                            got_reg_wr_evt_example === exp_reg_wr_evt_example,
                            $sformatf(
                                "wr_evt_example register read mismatch (client [%0d:%0d]). Exp: %0x, Got: %0x.",
                                i, j,
                                exp_reg_wr_evt_example,
                                got_reg_wr_evt_example
                            )
                        );
                    end
                end
            end
        `SVTEST_END

        `SVTEST(write_byte)
            logic [31:0] addr;
            logic [3:0][7:0] exp_reg_data = 'h12345678;
            logic [31:0] got_reg_data;
            byte exp_byte_data = 'hAC;

            // Manipulate ID register in stats block 1 (base offset 4096)
            addr = MEM_MAP_TOP.region[1].base + MEM_MAP_SUBDECODER.region[1].base + example_reg_pkg::OFFSET_RW_MONOLITHIC_EXAMPLE;

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
            addr = MEM_MAP_TOP.region[1].base + MEM_MAP_SUBDECODER.region[1].base + example_reg_pkg::OFFSET_RW_MONOLITHIC_EXAMPLE;

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

        `SVTEST(wr_decode_error)
            bit error;
            string msg;
            reg_agent.write_bad_addr(BAD_MEM_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

        `SVTEST(wr_peripheral_error)
            bit error;
            string msg;
            reg_agent.write_bad_addr(4096+BAD_REG_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

        `SVTEST(wr_missing_peripheral)
            bit error;
            string msg;
            reg_agent.write_bad_addr(16384, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

        `SVTEST(rd_decode_error)
            bit error;
            string msg;
            reg_agent.read_bad_addr(BAD_MEM_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

        `SVTEST(rd_peripheral_error)
            bit error;
            string msg;
            reg_agent.read_bad_addr(4096+BAD_REG_ADDRESS, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

        `SVTEST(rd_missing_peripheral)
            bit error;
            string msg;
            reg_agent.read_bad_addr(16384, error, msg);
            `FAIL_IF_LOG(
                error == 1'b1,
                msg
            );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
