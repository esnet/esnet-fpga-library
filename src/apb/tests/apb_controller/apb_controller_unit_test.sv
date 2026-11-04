`include "svunit_defines.svh"

// (Failsafe) timeout (per-testcase)
`define SVUNIT_TIMEOUT 500us

module apb_controller_unit_test #(parameter int TIMEOUT=4);
    import svunit_pkg::svunit_testcase;

    string name = $sformatf("apb_controller_timeout%0d_ut", TIMEOUT);
    svunit_testcase svunit_ut;

    //===================================
    // Clock and interfaces
    //===================================
    logic clk;
    `SVUNIT_CLK_GEN(clk, 5ns);

    reg_intf #(.ADDR_WID(16)) upstream_if ();
    reg_intf #(.ADDR_WID(16)) downstream_if ();
    apb_intf #(.ADDR_WID(16)) apb_if ();

    //===================================
    // DUT and APB peripheral
    //===================================
    apb_controller #(.WR_TIMEOUT(TIMEOUT), .RD_TIMEOUT(TIMEOUT)) DUT (
        .reg_if(upstream_if), .apb_if(apb_if)
    );
    apb_peripheral i_peripheral (.apb_if(apb_if), .reg_if(downstream_if));

    //===================================
    // Register stimulus
    //===================================
    logic srst, wr, rd;
    logic [15:0] wr_addr, rd_addr;
    logic [31:0] wr_data;
    logic [3:0] wr_byte_en;
    assign upstream_if.clk = clk;
    assign upstream_if.srst = srst;
    assign upstream_if.wr = wr;
    assign upstream_if.wr_addr = wr_addr;
    assign upstream_if.wr_data = wr_data;
    assign upstream_if.wr_byte_en = wr_byte_en;
    assign upstream_if.rd = rd;
    assign upstream_if.rd_addr = rd_addr;

    //===================================
    // Register peripheral model
    //===================================
    // Small register model with programmable wait states and error injection.
    logic respond, inject_error;
    int wait_cycles;
    int waited;
    logic [31:0] memory [16];
    assign downstream_if.wr_ack = !downstream_if.srst && downstream_if.wr
                               && respond && waited >= wait_cycles;
    assign downstream_if.rd_ack = !downstream_if.srst && downstream_if.rd
                               && respond && waited >= wait_cycles;
    assign downstream_if.wr_error = inject_error;
    assign downstream_if.rd_error = inject_error;
    assign downstream_if.rd_data = memory[downstream_if.rd_addr[5:2]];

    always @(posedge downstream_if.clk) begin
        if (downstream_if.srst) begin
            waited <= 0;
            foreach (memory[i]) memory[i] <= '0;
        end else begin
            if ((!downstream_if.wr && !downstream_if.rd) || downstream_if.wr_ack || downstream_if.rd_ack)
                waited <= 0;
            else waited <= waited + 1;
            if (downstream_if.wr_ack && !downstream_if.wr_error) begin
                for (int b = 0; b < 4; b++) begin
                    if (downstream_if.wr_byte_en[b])
                        memory[downstream_if.wr_addr[5:2]][b*8 +: 8] <= downstream_if.wr_data[b];
                end
            end
        end
    end

    //===================================
    // Monitoring and clocking block
    //===================================
    wire wr_ack = upstream_if.wr_ack;
    wire wr_error = upstream_if.wr_error;
    wire rd_ack = upstream_if.rd_ack;
    wire rd_error = upstream_if.rd_error;
    wire [31:0] rd_data = upstream_if.rd_data;
    wire psel = apb_if.psel;
    wire penable = apb_if.penable;
    wire pwrite = apb_if.pwrite;
    wire presetn = apb_if.presetn;
    wire [15:0] paddr = apb_if.paddr;
    wire [31:0] pwdata = apb_if.pwdata;
    wire [3:0] pstrb = apb_if.pstrb;
    wire [2:0] pprot = apb_if.pprot;
    wire downstream_reset = downstream_if.srst;

    clocking cb @(posedge clk);
        output srst, wr, rd, wr_addr, rd_addr, wr_data, wr_byte_en;
        output respond, inject_error, wait_cycles;
        input wr_ack, wr_error, rd_ack, rd_error, rd_data;
        input psel, penable, pwrite, presetn, paddr, pwdata, pstrb, pprot;
        input downstream_reset;
    endclocking

    //===================================
    // Build / setup / teardown
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task reset_dut();
        cb.wr <= 1'b0;
        cb.rd <= 1'b0;
        cb.wr_addr <= '0;
        cb.rd_addr <= '0;
        cb.wr_data <= '0;
        cb.wr_byte_en <= '0;
        cb.respond <= 1'b1;
        cb.inject_error <= 1'b0;
        cb.wait_cycles <= 0;
        cb.srst <= 1'b1;
        repeat (4) @(cb);
        cb.srst <= 1'b0;
        repeat (4) @(cb);
    endtask

    task setup();
        svunit_ut.setup();
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // Transaction helper
    //===================================
    task automatic transfer(input bit write, input bit [15:0] addr,
                            input bit [31:0] data, input bit [3:0] strb,
                            input bit expect_error, output bit [31:0] result);
        bit completed = 0;
        bit saw_setup = 0;
        cb.wr <= write;
        cb.rd <= !write;
        cb.wr_addr <= addr;
        cb.rd_addr <= addr;
        cb.wr_data <= data;
        cb.wr_byte_en <= strb;
        @(cb);
        cb.wr <= 1'b0;
        cb.rd <= 1'b0;
        // Bound each request independently of the testcase fuse.
        for (int i = 0; i < (TIMEOUT > 0 ? TIMEOUT : 20) + 16; i++) begin
            @(cb);
            if (cb.psel) begin
                `FAIL_UNLESS_EQUAL(cb.paddr, addr);
                `FAIL_UNLESS_EQUAL(cb.pwrite, write);
                `FAIL_UNLESS_EQUAL(cb.pprot, apb_pkg::PPROT_DEFAULT);
                if (!cb.penable) begin
                    `FAIL_IF(saw_setup);
                    saw_setup = 1;
                end else `FAIL_UNLESS(saw_setup);
                if (write) begin
                    `FAIL_UNLESS_EQUAL(cb.pwdata, data);
                    `FAIL_UNLESS_EQUAL(cb.pstrb, strb);
                end
            end
            if (cb.wr_ack || cb.rd_ack) begin
                `FAIL_UNLESS(cb.psel && cb.penable && saw_setup);
                `FAIL_UNLESS_EQUAL(cb.wr_ack, write);
                `FAIL_UNLESS_EQUAL(cb.rd_ack, !write);
                `FAIL_UNLESS_EQUAL(write ? cb.wr_error : cb.rd_error, expect_error);
                result = cb.rd_data;
                completed = 1;
                break;
            end
        end
        `FAIL_UNLESS_LOG(completed, $sformatf("No completion for %s at 0x%0x", write ? "write" : "read", addr));
        @(cb);
        `FAIL_IF(cb.wr_ack || cb.rd_ack);
    endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
            `FAIL_UNLESS(cb.presetn);
            `FAIL_IF(cb.downstream_reset);
            `FAIL_IF(cb.psel || cb.penable || cb.wr_ack || cb.rd_ack);
        `SVTEST_END

        `SVTEST(write_read_and_byte_strobes)
            bit [31:0] result;
            transfer(1, 16'h10, 32'h11223344, 4'hF, 0, result);
            transfer(1, 16'h10, 32'hAABBCCDD, 4'b0101, 0, result);
            transfer(1, 16'h10, '1, 4'b0000, 0, result);
            transfer(0, 16'h10, 0, 0, 0, result);
            `FAIL_UNLESS_EQUAL(result, 32'h11BB33DD);
        `SVTEST_END

        `SVTEST(wait_states_and_random_readback)
            bit [31:0] expected, result;
            cb.wait_cycles <= TIMEOUT == 0 ? 10 : (TIMEOUT > 1 ? 1 : 0);
            for (int i = 0; i < 16; i++) begin
                expected = $urandom;
                transfer(1, 16'(i*4), expected, '1, 0, result);
                transfer(0, 16'(i*4), 0, 0, 0, result);
                `FAIL_UNLESS_EQUAL(result, expected);
            end
        `SVTEST_END

        `SVTEST(peripheral_errors)
            bit [31:0] result;
            transfer(1, 16'h20, 32'h11223344, '1, 0, result);
            cb.inject_error <= 1'b1;
            transfer(1, 16'h20, '1, '1, 1, result);
            transfer(0, 16'h20, 0, 0, 1, result);
            `FAIL_UNLESS_EQUAL(result, reg_pkg::BAD_ACCESS_DATA);
            cb.inject_error <= 1'b0;
            transfer(0, 16'h20, 0, 0, 0, result);
            `FAIL_UNLESS_EQUAL(result, 32'h11223344);
        `SVTEST_END

        `SVTEST(timeouts_and_reset_recovery)
            bit [31:0] result;
            if (TIMEOUT > 0) begin
                cb.respond <= 1'b0;
                transfer(1, 16'h20, '1, '1, 1, result);
                reset_dut();
                cb.respond <= 1'b0;
                transfer(0, 16'h20, 0, 0, 1, result);
                `FAIL_UNLESS_EQUAL(result, reg_pkg::BAD_ACCESS_DATA);
                reset_dut();
                transfer(1, 16'h20, 32'hA5A55A5A, '1, 0, result);
                transfer(0, 16'h20, 0, 0, 0, result);
                `FAIL_UNLESS_EQUAL(result, 32'hA5A55A5A);
            end else begin
                cb.wait_cycles <= 10;
                transfer(1, 16'h20, 32'hA5A55A5A, '1, 0, result);
                transfer(0, 16'h20, 0, 0, 0, result);
                `FAIL_UNLESS_EQUAL(result, 32'hA5A55A5A);
            end
        `SVTEST_END

    `SVUNIT_TESTS_END
endmodule : apb_controller_unit_test

//===================================
// SVUnit wrappers
//===================================
`define APB_CONTROLLER_UNIT_TEST(TIMEOUT) \
    import svunit_pkg::svunit_testcase; \
    svunit_testcase svunit_ut; \
    apb_controller_unit_test #(TIMEOUT) test(); \
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

module apb_controller_timeout_unit_test;
    `APB_CONTROLLER_UNIT_TEST(4)
endmodule

module apb_controller_single_cycle_timeout_unit_test;
    `APB_CONTROLLER_UNIT_TEST(1)
endmodule

module apb_controller_no_timeout_unit_test;
    `APB_CONTROLLER_UNIT_TEST(0)
endmodule
