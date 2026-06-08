`include "svunit_defines.svh"

// Unit test for axi4l_from_axi4_adapter.
//
// DUT: axi4l_from_axi4_adapter (wide AXI4 → 32-bit AXI4-L).
// Peripheral: example_component (same as axi4l_intf tests).
//
// AXI4 bus: 512-bit (64 bytes per beat).
// Lane selection: AxADDR[5:2] picks the 32-bit word within the beat.
// AXI4-L address: AxADDR & ~3 (low 2 bits cleared).
//
// Test addresses are chosen to land on writable RW registers:
//   AxADDR 0x000 → lane 0 → AXI4-L 0x00 = RW_EXAMPLE
//   AxADDR 0x010 → lane 4 → AXI4-L 0x10 = RW_MONOLITHIC_EXAMPLE
//   AxADDR 0x018 → lane 6 → AXI4-L 0x18 = RW_ARRAY[0]
//   AxADDR 0x01C → lane 7 → AXI4-L 0x1C = RW_ARRAY[1]
//   AxADDR 0x034 → lane 13→ AXI4-L 0x34 = RW_ARRAY[7]
// Read-only test (RO_EXAMPLE at AXI4-L 0x04, lane 1 of beat 0x000):
//   AxADDR 0x004 → lane 1 → AXI4-L 0x04 = RO_EXAMPLE (expected OKAY, fixed value)

module axi4l_from_axi4_adapter_unit_test;
    import svunit_pkg::svunit_testcase;
    import axi4_verif_pkg::*;
    import axi4_pkg::*;
    import axi4l_verif_pkg::*;
    import reg_pkg::*;
    import reg_example_reg_verif_pkg::*;

    string name = "axi4l_from_axi4_adapter_unit_test";
    svunit_testcase svunit_ut;

    localparam int DATA_BYTE_WID  = 64;
    localparam int ADDR_WID       = 64;
    localparam int ID_WID         = 2;
    localparam int USER_WID       = 1;
    localparam int WORD_BYTES     = 4;

    // =========================================================================
    // Clock / reset
    // =========================================================================
    logic aclk;
    `SVUNIT_CLK_GEN(aclk, 4ns);

    std_reset_intf #(.ACTIVE_LOW(1)) reset_if (.clk(aclk));
    logic aresetn;
    assign aresetn        = reset_if.reset;
    assign reset_if.ready = aresetn;

    task reset();
        reset_if.pulse(8);
    endtask

    // =========================================================================
    // DUT
    // =========================================================================
    axi4_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) axi4_if (.aclk(aclk));

    axi4l_intf axil_if ();

    axi4l_from_axi4_adapter #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) DUT (
        .aclk     ( aclk    ),
        .aresetn  ( aresetn ),
        .axi4_if  ( axi4_if ),
        .axi4l_if ( axil_if )
    );

    // =========================================================================
    // Peripheral — example register block
    // =========================================================================
    logic        input_valid;
    logic [31:0] input_data;
    logic        output_valid;
    logic [31:0] output_data;

    example_component i_component (
        .clk          ( axil_if.aclk ),
        .axil_if      ( axil_if      ),
        .input_valid  ( input_valid  ),
        .input_data   ( input_data   ),
        .output_valid ( output_valid ),
        .output_data  ( output_data  )
    );

    // =========================================================================
    // Agents
    // =========================================================================
    axi4_reg_agent #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) agent;

    axi4l_reg_agent #() axil_agent;
    example_reg_blk_agent reg_blk_agent;

    // =========================================================================
    // Helpers
    // =========================================================================

    // Write a 32-bit word; AxADDR[5:2] selects the lane.
    task write_word(
            input  logic [ADDR_WID-1:0] addr,
            input  logic [31:0]         data,
            output bit [1:0]            resp,
            output bit                  timeout
        );
        automatic int lane = int'(addr[5:2]);
        automatic bit [DATA_BYTE_WID-1:0][7:0] wdata = '0;
        automatic bit [DATA_BYTE_WID-1:0]       strb  = '0;
        wdata[lane*WORD_BYTES +: WORD_BYTES] = data;
        strb [lane*WORD_BYTES +: WORD_BYTES] = 4'hF;
        agent.axi4_vif.write(addr, wdata, strb, resp, timeout);
    endtask

    // Read a 32-bit word from the correct lane.
    task read_word(
            input  logic [ADDR_WID-1:0] addr,
            output logic [31:0]         data,
            output bit [1:0]            resp,
            output bit                  timeout
        );
        automatic int lane = int'(addr[5:2]);
        automatic bit [DATA_BYTE_WID-1:0][7:0] rdata;
        agent.axi4_vif.read(addr, rdata, resp, timeout);
        data = rdata[lane*WORD_BYTES +: WORD_BYTES];
    endtask

    // Write a single byte; AxADDR[5:0] selects the byte lane.
    task write_byte_lane(
            input  logic [ADDR_WID-1:0] addr,
            input  byte                 data,
            output bit [1:0]            resp,
            output bit                  timeout
        );
        automatic int byte_pos = int'(addr[5:0]);
        automatic bit [DATA_BYTE_WID-1:0][7:0] wdata = '0;
        automatic bit [DATA_BYTE_WID-1:0]       strb  = '0;
        wdata[byte_pos] = data;
        strb [byte_pos] = 1'b1;
        agent.axi4_vif.write(addr, wdata, strb, resp, timeout);
    endtask

    // =========================================================================
    // Build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
        agent = new();
        agent.axi4_vif = axi4_if;
        axil_agent = new();
        axil_agent.axil_vif = axil_if;
        reg_blk_agent = new("reg_blk_agent");
        reg_blk_agent.reg_agent = axil_agent;
    endfunction

    task setup();
        svunit_ut.setup();
        agent.idle();
        axil_agent.idle();
        reset();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(hard_reset)
        `SVTEST_END

        // =====================================================================
        // Lane selection — writable registers only
        // =====================================================================

        // Lane 0: addr=0x000 → AXI4-L 0x00 = RW_EXAMPLE (16-bit register)
        // Only the lower 16 bits are writable; test with a 16-bit-safe value.
        `SVTEST(write_read_lane0)
            bit [1:0] resp; bit timeout;
            logic [31:0] exp = 32'h0000_BEEF, got;
            write_word(64'h000, exp, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane0 write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane0 write resp=%02b", resp));
            read_word(64'h000, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane0 read timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane0 read resp=%02b", resp));
            `FAIL_UNLESS_LOG(got === exp, $sformatf("lane0: exp=%08x got=%08x", exp, got));
        `SVTEST_END

        // Lane 4: addr=0x010 → AXI4-L 0x10 = RW_MONOLITHIC_EXAMPLE
        `SVTEST(write_read_lane4)
            bit [1:0] resp; bit timeout;
            logic [31:0] exp = 32'hCAFE_BABE, got;
            write_word(64'h010, exp, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane4 write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane4 write resp=%02b", resp));
            read_word(64'h010, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane4 read timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane4 read resp=%02b", resp));
            `FAIL_UNLESS_LOG(got === exp, $sformatf("lane4: exp=%08x got=%08x", exp, got));
        `SVTEST_END

        // Lane 6: addr=0x018 → AXI4-L 0x18 = RW_ARRAY[0]
        `SVTEST(write_read_lane6)
            bit [1:0] resp; bit timeout;
            logic [31:0] exp = 32'h1234_5678, got;
            write_word(64'h018, exp, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane6 write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane6 write resp=%02b", resp));
            read_word(64'h018, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane6 read timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane6 read resp=%02b", resp));
            `FAIL_UNLESS_LOG(got === exp, $sformatf("lane6: exp=%08x got=%08x", exp, got));
        `SVTEST_END

        // Lane 13: addr=0x034 → AXI4-L 0x34 = RW_ARRAY[7]
        `SVTEST(write_read_lane13)
            bit [1:0] resp; bit timeout;
            logic [31:0] exp = 32'hABCD_1234, got;
            write_word(64'h034, exp, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane13 write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane13 write resp=%02b", resp));
            read_word(64'h034, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "lane13 read timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("lane13 read resp=%02b", resp));
            `FAIL_UNLESS_LOG(got === exp, $sformatf("lane13: exp=%08x got=%08x", exp, got));
        `SVTEST_END

        // Multiple lanes independently readable within the same beat
        `SVTEST(multiple_lanes_independent)
            bit [1:0] resp; bit timeout;
            logic [31:0] v0 = 32'h0000_1111;  // RW_EXAMPLE is 16-bit
            logic [31:0] v6 = 32'hBBBB_2222;
            logic [31:0] v7 = 32'hCCCC_3333;
            logic [31:0] got;
            // Write three different lanes (RW registers only)
            write_word(64'h000, v0, resp, timeout); // lane 0 → RW_EXAMPLE
            `FAIL_IF_LOG(timeout, "multi-lane write lane0 timed out");
            write_word(64'h018, v6, resp, timeout); // lane 6 → RW_ARRAY[0]
            `FAIL_IF_LOG(timeout, "multi-lane write lane6 timed out");
            write_word(64'h01C, v7, resp, timeout); // lane 7 → RW_ARRAY[1]
            `FAIL_IF_LOG(timeout, "multi-lane write lane7 timed out");
            // Read back each independently
            read_word(64'h000, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "multi-lane read lane0 timed out");
            `FAIL_UNLESS_LOG(got === v0, $sformatf("lane0: exp=%08x got=%08x", v0, got));
            read_word(64'h018, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "multi-lane read lane6 timed out");
            `FAIL_UNLESS_LOG(got === v6, $sformatf("lane6: exp=%08x got=%08x", v6, got));
            read_word(64'h01C, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "multi-lane read lane7 timed out");
            `FAIL_UNLESS_LOG(got === v7, $sformatf("lane7: exp=%08x got=%08x", v7, got));
        `SVTEST_END

        // =====================================================================
        // Read-only register — lane 1, addr=0x004 → AXI4-L 0x04 = RO_EXAMPLE
        // Verify: OKAY response, correct data on the correct lane.
        // =====================================================================
        `SVTEST(read_ro_register)
            bit [1:0] resp; bit timeout;
            logic [31:0] got;
            // RO_EXAMPLE init: field0=0xAB (bits 7:0), field1=XYZ (bits 31:8)
            automatic logic [31:0] exp = {
                example_reg_pkg::RO_EXAMPLE_FIELD1_XYZ,
                8'hAB
            };
            read_word(64'h004, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "read_ro timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("read_ro resp=%02b", resp));
            `FAIL_UNLESS_LOG(got === exp, $sformatf("RO: exp=%08x got=%08x", exp, got));
        `SVTEST_END

        // =====================================================================
        // Byte-granularity writes (all on RW_EXAMPLE at AXI4-L 0x00)
        // =====================================================================

        // Byte tests use RW_MONOLITHIC_EXAMPLE at AXI4-L 0x10 (lane 4, addr 0x010)
        // which is a full 32-bit RW register — all four bytes writable.
        `SVTEST(byte_write_preserves_other_bytes)
            bit [1:0] resp; bit timeout;
            logic [31:0] init_val = 32'hAA_BB_CC_DD, got;
            write_word(64'h010, init_val, resp, timeout);
            `FAIL_IF_LOG(timeout, "byte_write init timed out");
            // Overwrite byte 1 (addr 0x011, byte_pos = 17 within the beat)
            write_byte_lane(64'h011, 8'hFF, resp, timeout);
            `FAIL_IF_LOG(timeout, "byte1 write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("byte1 resp=%02b", resp));
            read_word(64'h010, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "byte_write read timed out");
            `FAIL_UNLESS_LOG(got[7:0]   === 8'hDD, $sformatf("byte0 changed: %02x", got[7:0]));
            `FAIL_UNLESS_LOG(got[15:8]  === 8'hFF, $sformatf("byte1 wrong: %02x",   got[15:8]));
            `FAIL_UNLESS_LOG(got[23:16] === 8'hBB, $sformatf("byte2 changed: %02x", got[23:16]));
            `FAIL_UNLESS_LOG(got[31:24] === 8'hAA, $sformatf("byte3 changed: %02x", got[31:24]));
        `SVTEST_END

        `SVTEST(byte_write_last_byte_of_word)
            bit [1:0] resp; bit timeout;
            logic [31:0] init_val = 32'h11_22_33_44, got;
            write_word(64'h010, init_val, resp, timeout);
            `FAIL_IF_LOG(timeout, "byte_last init timed out");
            // Overwrite byte 3 (addr 0x013, byte_pos = 19 within the beat)
            write_byte_lane(64'h013, 8'hDE, resp, timeout);
            `FAIL_IF_LOG(timeout, "byte3 write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("byte3 resp=%02b", resp));
            read_word(64'h010, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "byte_last read timed out");
            `FAIL_UNLESS_LOG(got[31:24] === 8'hDE,        $sformatf("byte3: %02x", got[31:24]));
            `FAIL_UNLESS_LOG(got[23:0]  === 24'h22_33_44, $sformatf("others: %06x", got[23:0]));
        `SVTEST_END

        // Byte write in a non-zero lane: byte 0 of RW_ARRAY[0] (addr 0x018)
        `SVTEST(byte_write_non_zero_lane)
            bit [1:0] resp; bit timeout;
            logic [31:0] init_val = 32'hFF_EE_DD_CC, got;
            write_word(64'h018, init_val, resp, timeout);
            `FAIL_IF_LOG(timeout, "non-zero lane init timed out");
            write_byte_lane(64'h018, 8'hAB, resp, timeout);
            `FAIL_IF_LOG(timeout, "non-zero lane byte write timed out");
            `FAIL_UNLESS_LOG(resp === 2'b00, $sformatf("non-zero lane resp=%02b", resp));
            read_word(64'h018, got, resp, timeout);
            `FAIL_IF_LOG(timeout, "non-zero lane read timed out");
            `FAIL_UNLESS_LOG(got[7:0]  === 8'hAB,      $sformatf("byte0: %02x", got[7:0]));
            `FAIL_UNLESS_LOG(got[31:8] === 24'hFF_EE_DD, $sformatf("others: %06x", got[31:8]));
        `SVTEST_END

        // =====================================================================
        // Multi-beat burst rejection (AxLEN=1 → SLVERR, single W beat sent)
        // =====================================================================

        `SVTEST(multi_beat_write_rejected)
            bit [1:0] resp; bit timeout;
            automatic bit [DATA_BYTE_WID-1:0][7:0] wdata = '0;
            automatic bit [DATA_BYTE_WID-1:0]       strb  = '1;
            @(agent.axi4_vif.cb);
            agent.axi4_vif.cb.awvalid <= 1'b1;
            agent.axi4_vif.cb.awaddr  <= 64'h0;
            agent.axi4_vif.cb.awlen   <= 8'h1;
            agent.axi4_vif.cb.awsize  <= SIZE_4BYTES;
            agent.axi4_vif.cb.awburst <= BURST_INCR;
            agent.axi4_vif.cb.awlock  <= LOCK_NORMAL;
            @(agent.axi4_vif.cb);
            wait(agent.axi4_vif.cb.awvalid && agent.axi4_vif.cb.awready);
            agent.axi4_vif.cb.awvalid <= 1'b0;
            // Single W beat with wlast=1 (DUT accepts one beat then rejects)
            agent.axi4_vif.cb.wvalid  <= 1'b1;
            agent.axi4_vif.cb.wdata   <= wdata;
            agent.axi4_vif.cb.wstrb   <= strb;
            agent.axi4_vif.cb.wlast   <= 1'b1;
            @(agent.axi4_vif.cb);
            wait(agent.axi4_vif.cb.wvalid && agent.axi4_vif.cb.wready);
            agent.axi4_vif.cb.wvalid  <= 1'b0;
            agent.axi4_vif.cb.wlast   <= 1'b0;
            agent.axi4_vif.cb.bready  <= 1'b1;
            fork
                begin
                    @(agent.axi4_vif.cb);
                    wait(agent.axi4_vif.cb.bvalid && agent.axi4_vif.cb.bready);
                    resp = agent.axi4_vif.cb.bresp; timeout = 1'b0;
                end
                begin repeat(256) @(agent.axi4_vif.cb); timeout = 1'b1; end
            join_any
            disable fork;
            agent.axi4_vif.cb.bready <= 1'b0;
            agent.idle();
            `FAIL_IF_LOG(timeout, "multi-beat write: timed out");
            `FAIL_UNLESS_LOG(resp === 2'b10,
                $sformatf("multi-beat write: expected SLVERR got 2'b%02b", resp));
        `SVTEST_END

        `SVTEST(multi_beat_read_rejected)
            bit [1:0] resp; bit timeout;
            @(agent.axi4_vif.cb);
            agent.axi4_vif.cb.arvalid <= 1'b1;
            agent.axi4_vif.cb.araddr  <= 64'h0;
            agent.axi4_vif.cb.arlen   <= 8'h1;
            agent.axi4_vif.cb.arsize  <= SIZE_4BYTES;
            agent.axi4_vif.cb.arburst <= BURST_INCR;
            agent.axi4_vif.cb.arlock  <= LOCK_NORMAL;
            @(agent.axi4_vif.cb);
            wait(agent.axi4_vif.cb.arvalid && agent.axi4_vif.cb.arready);
            agent.axi4_vif.cb.arvalid <= 1'b0;
            agent.axi4_vif.cb.rready  <= 1'b1;
            fork
                begin
                    @(agent.axi4_vif.cb);
                    wait(agent.axi4_vif.cb.rvalid && agent.axi4_vif.cb.rready);
                    resp = agent.axi4_vif.cb.rresp; timeout = 1'b0;
                end
                begin repeat(256) @(agent.axi4_vif.cb); timeout = 1'b1; end
            join_any
            disable fork;
            agent.axi4_vif.cb.rready <= 1'b0;
            agent.idle();
            `FAIL_IF_LOG(timeout, "multi-beat read: timed out");
            `FAIL_UNLESS_LOG(resp === 2'b10,
                $sformatf("multi-beat read: expected SLVERR got 2'b%02b", resp));
        `SVTEST_END

        // =====================================================================
        // Stress — RW_ARRAY[0..7] (AXI4-L 0x18..0x34, lanes 6..13)
        // =====================================================================
        `SVTEST(write_read_stress)
            localparam int N = 8;
            bit [1:0] resp; bit timeout;
            logic [31:0] exp [N], got;
            // Write all 8 RW_ARRAY registers via their lane addresses
            for (int i = 0; i < N; i++) begin
                automatic logic [ADDR_WID-1:0] addr =
                    64'(example_reg_pkg::OFFSET_RW_ARRAY_EXAMPLE[i]);
                exp[i] = $urandom();
                write_word(addr, exp[i], resp, timeout);
                `FAIL_IF_LOG(timeout, $sformatf("stress write[%0d] timed out", i));
                `FAIL_UNLESS_LOG(resp === 2'b00,
                    $sformatf("stress write[%0d] resp=%02b", i, resp));
            end
            for (int i = 0; i < N; i++) begin
                automatic logic [ADDR_WID-1:0] addr =
                    64'(example_reg_pkg::OFFSET_RW_ARRAY_EXAMPLE[i]);
                read_word(addr, got, resp, timeout);
                `FAIL_IF_LOG(timeout, $sformatf("stress read[%0d] timed out", i));
                `FAIL_UNLESS_LOG(resp === 2'b00,
                    $sformatf("stress read[%0d] resp=%02b", i, resp));
                `FAIL_UNLESS_LOG(got === exp[i],
                    $sformatf("stress[%0d]: exp=%08x got=%08x", i, exp[i], got));
            end
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : axi4l_from_axi4_adapter_unit_test
