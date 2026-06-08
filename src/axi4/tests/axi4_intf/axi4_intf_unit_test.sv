`include "svunit_defines.svh"

// Parameterized unit test module.
// Instantiates the chosen DUT between the agent's controller interface and
// an axi4_mem_bfm peripheral, then runs a common set of write/read tests.
module axi4_intf_unit_test #(
    parameter string DUT_NAME = "axi4_intf_connector"
);
    import svunit_pkg::svunit_testcase;
    import axi4_verif_pkg::*;
    import axi4_pkg::*;

    string name = $sformatf("%s_unit_test", DUT_NAME);
    svunit_testcase svunit_ut;

    // =========================================================================
    // Bus parameters
    // =========================================================================
    localparam int DATA_BYTE_WID = 64;
    localparam int ADDR_WID      = 64;
    localparam int ID_WID        = 2;
    localparam int USER_WID      = 1;
    localparam int DATA_WID      = DATA_BYTE_WID * 8;

    // =========================================================================
    // Clock and reset
    // =========================================================================
    logic aclk;
    `SVUNIT_CLK_GEN(aclk, 4ns);

    std_reset_intf #(.ACTIVE_LOW(1)) reset_if (.clk(aclk));

    logic aresetn;
    logic srst;
    assign aresetn = reset_if.reset;
    assign reset_if.ready = aresetn;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) srst <= 1'b1;
        else          srst <= 1'b0;
    end

    task reset();
        reset_if.pulse(8);
    endtask

    // =========================================================================
    // AXI4 interfaces
    // =========================================================================
    axi4_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) from_controller (.aclk(aclk));

    axi4_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) to_peripheral (.aclk(aclk));

    // =========================================================================
    // DUT
    // =========================================================================
    generate
        case (DUT_NAME)
            "axi4_intf_connector" : begin : g__connector
                axi4_intf_connector DUT (
                    .from_controller ( from_controller ),
                    .to_peripheral   ( to_peripheral   )
                );
            end : g__connector
        endcase
    endgenerate

    // =========================================================================
    // Peripheral — single-channel memory BFM
    // =========================================================================
    axi4_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) mem_if [1] (.aclk(aclk));

    axi4_intf_connector i_to_mem (
        .from_controller ( to_peripheral ),
        .to_peripheral   ( mem_if[0]     )
    );

    axi4_mem_bfm #(
        .CHANNELS   ( 1 ),
        .WR_LATENCY ( 2 ),
        .RD_LATENCY ( 2 )
    ) i_mem_bfm (
        .srst    ( srst  ),
        .axi4_if ( mem_if )
    );

    // =========================================================================
    // Agent
    // =========================================================================
    axi4_reg_agent #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) agent;

    // =========================================================================
    // Build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
        agent = new();
        agent.axi4_vif = from_controller;
    endfunction

    task setup();
        svunit_ut.setup();
        agent.idle();
        reset();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Helper tasks
    // =========================================================================

    // Write a 32-bit word into the correct byte lane for the given address,
    // using the full 512-bit bus width with appropriate strobe.
    task write_word(input logic [ADDR_WID-1:0] addr, input logic [31:0] data);
        automatic int word_idx = addr[5:2];  // which 32-bit word within the beat
        automatic bit [DATA_BYTE_WID-1:0][7:0] wdata = '0;
        automatic bit [DATA_BYTE_WID-1:0]       strb = '0;
        automatic bit [1:0] resp;
        automatic bit       timeout;
        // Place the 32-bit word on the correct lane
        wdata[word_idx*4 +: 4] = data;
        strb[word_idx*4 +: 4]  = 4'hF;
        agent.axi4_vif.write(addr, wdata, strb, resp, timeout);
        `FAIL_IF_LOG(timeout, $sformatf("Write to 0x%0x timed out", addr));
        `FAIL_UNLESS_LOG(resp === 2'b00,
            $sformatf("Write to 0x%0x: expected OKAY, got 2'b%02b", addr, resp));
    endtask

    // Read a 32-bit word from the correct byte lane for the given address.
    task read_word(
            input  logic [ADDR_WID-1:0] addr,
            output logic [31:0]         data
        );
        automatic int word_idx = addr[5:2];
        automatic bit [DATA_BYTE_WID-1:0][7:0] rdata;
        automatic bit [1:0] resp;
        automatic bit       timeout;
        agent.axi4_vif.read(addr, rdata, resp, timeout);
        `FAIL_IF_LOG(timeout, $sformatf("Read from 0x%0x timed out", addr));
        `FAIL_UNLESS_LOG(resp === 2'b00,
            $sformatf("Read from 0x%0x: expected OKAY, got 2'b%02b", addr, resp));
        data = rdata[word_idx*4 +: 4];
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(hard_reset)
        `SVTEST_END

        // Single 32-bit word write then read-back through connector + memory BFM.
        `SVTEST(write_read_word)
            logic [31:0] exp = 32'hDEAD_BEEF;
            logic [31:0] got;
            write_word(64'h0000_0000_0000_0000, exp);
            read_word (64'h0000_0000_0000_0000, got);
            `FAIL_UNLESS_LOG(got === exp,
                $sformatf("write_read_word: exp=0x%08x got=0x%08x", exp, got));
        `SVTEST_END

        // Write to several different 32-bit word offsets within the same beat,
        // verify each reads back independently.
        `SVTEST(write_read_multiple_lanes)
            logic [31:0] vals [4] = '{32'hAABBCCDD, 32'h11223344, 32'hDEADBEEF, 32'hCAFEBABE};
            logic [31:0] got;
            // Write words at byte offsets 0x00, 0x04, 0x08, 0x0C (all in the same beat)
            for (int i = 0; i < 4; i++)
                write_word(64'(i * 4), vals[i]);
            // Read back and verify
            for (int i = 0; i < 4; i++) begin
                read_word(64'(i * 4), got);
                `FAIL_UNLESS_LOG(got === vals[i],
                    $sformatf("lane %0d: exp=0x%08x got=0x%08x", i, vals[i], got));
            end
        `SVTEST_END

        // Stress test — many random writes then reads to confirm no corruption.
        `SVTEST(write_read_stress)
            localparam int N = 64;
            logic [31:0] exp [N];
            logic [31:0] got;
            // Write phase
            for (int i = 0; i < N; i++) begin
                exp[i] = $urandom();
                write_word(64'(i * 4), exp[i]);
            end
            // Read-back phase
            for (int i = 0; i < N; i++) begin
                read_word(64'(i * 4), got);
                `FAIL_UNLESS_LOG(got === exp[i],
                    $sformatf("stress[%0d]: exp=0x%08x got=0x%08x", i, exp[i], got));
            end
        `SVTEST_END

        // Read from an address never written — BFM returns 0 for uninitialised addresses.
        `SVTEST(read_uninitialised)
            logic [31:0] got;
            read_word(64'hFFFF_FFFF_0000_0040, got);
            `FAIL_UNLESS_LOG(got === 32'h0,
                $sformatf("uninitialised read: expected 0, got 0x%08x", got));
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : axi4_intf_unit_test


// =============================================================================
// Boilerplate wrapper — one module per DUT, maintains SVUnit naming convention
// =============================================================================
`define AXI4_INTF_UNIT_TEST(DUT_NAME) \
  import svunit_pkg::svunit_testcase; \
  svunit_testcase svunit_ut; \
  axi4_intf_unit_test #(DUT_NAME) test(); \
  function void build(); \
    test.build(); \
    svunit_ut = test.svunit_ut; \
  endfunction \
  function void __register_tests(); \
    test.__register_tests(); \
  endfunction \
  task run(); \
    test.run(); \
  endtask

module axi4_intf_connector_unit_test;
    `AXI4_INTF_UNIT_TEST("axi4_intf_connector")
endmodule
