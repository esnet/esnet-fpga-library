`include "svunit_defines.svh"

`undef SVUNIT_TIMEOUT
`define SVUNIT_TIMEOUT 100us

module htable_multi_rr_unit_test;
    import svunit_pkg::svunit_testcase;
    import htable_pkg::*;
    import db_verif_pkg::*;

    string name = "htable_multi_rr_ut";
    svunit_testcase svunit_ut;

    // DUT and storage interfaces
    localparam int NUM_TABLES = 3;
    localparam int TABLE_DEPTH = 16;
    typedef bit [7:0] KEY_T;
    typedef bit [31:0] VALUE_T;
    localparam int ENTRY_WID = $bits(KEY_T) + $bits(VALUE_T);
    logic clk, srst, init_done;
    logic tbl_init [NUM_TABLES];
    logic tbl_init_done [NUM_TABLES];
    KEY_T lookup_key, update_key;
    hash_t lookup_hash [NUM_TABLES], update_hash [NUM_TABLES];
    db_info_intf info_if ();
    db_intf #(.KEY_WID(8), .VALUE_WID(32)) lookup_if (.clk), update_if (.clk);
    db_ctrl_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_ctrl_if [NUM_TABLES] (.clk);
    db_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_wr_if [NUM_TABLES] (.clk);
    db_intf #(.KEY_WID($bits(hash_t)), .VALUE_WID(ENTRY_WID)) tbl_rd_if [NUM_TABLES] (.clk);

    htable_multi_core #(
        .KEY_WID ( 8 ),
        .VALUE_WID ( 32 ),
        .NUM_TABLES ( NUM_TABLES ),
        .TABLE_SIZE ( '{default: TABLE_DEPTH} ),
        .INSERT_MODE ( HTABLE_MULTI_INSERT_MODE_ROUND_ROBIN )
    ) DUT (.*);

    // Direct-indexed test hashes and independent backing stores
    int writes [NUM_TABLES];
    for (genvar g = 0; g < NUM_TABLES; g++) begin : g__table
        assign lookup_hash[g] = hash_t'(lookup_key);
        assign update_hash[g] = hash_t'(update_key);
        db_store_array #(
            .KEY_WID ( $clog2(TABLE_DEPTH) ),
            .VALUE_WID ( ENTRY_WID )
        ) store (
            .clk, .srst,
            .init ( tbl_init[g] ),
            .init_done ( tbl_init_done[g] ),
            .db_wr_if ( tbl_wr_if[g] ),
            .db_rd_if ( tbl_rd_if[g] )
        );
        db_ctrl_intf_controller_term ctrl_term (.to_peripheral(tbl_ctrl_if[g]));
        always @(posedge clk) begin
            if (srst) writes[g] <= 0;
            else if (tbl_wr_if[g].req && tbl_wr_if[g].rdy) writes[g] <= writes[g] + 1;
        end
    end

    // Clocked stimulus and reset
    db_intf_agent #(KEY_T, VALUE_T) reader, writer;
    std_reset_intf reset_if (.clk);
    assign srst = reset_if.reset;
    assign reset_if.ready = init_done;
    `SVUNIT_CLK_GEN(clk, 2ns);
    clocking cb @(posedge clk);
        input writes;
    endclocking

    function void build();
        svunit_ut = new(name);
        reader = new("reader");
        reader.db_vif = lookup_if;
        writer = new("writer");
        writer.db_vif = update_if;
    endfunction

    task reset();
        bit timeout;
        reset_if.pulse(8);
        reset_if.wait_ready(timeout, 64);
        `FAIL_IF(timeout);
    endtask

    task setup();
        svunit_ut.setup();
        reader.idle();
        writer.idle();
        reset();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // Exercise non-power-of-two wrap and restart selection after reset.
    `SVUNIT_TESTS_BEGIN
    `SVTEST(distribution_and_reset)
        bit valid, error, timeout;
        VALUE_T value;
        for (int pass = 0; pass < 2; pass++) begin
            if (pass != 0) reset();
            for (int i = 0; i < 7; i++) begin
                writer.update(KEY_T'(i), 1, VALUE_T'(100+i), error, timeout);
                `FAIL_IF(error || timeout);
                writer.wait_n(1);
                for (int t = 0; t < NUM_TABLES; t++) begin
                    `FAIL_UNLESS_EQUAL(cb.writes[t], (i+NUM_TABLES-t)/NUM_TABLES);
                end
            end
            for (int i = 0; i < 7; i++) begin
                reader.query(KEY_T'(i), valid, value, error, timeout);
                `FAIL_IF(error || timeout);
                `FAIL_UNLESS(valid);
                `FAIL_UNLESS_EQUAL(value, VALUE_T'(100+i));
            end
        end
    `SVTEST_END
    `SVUNIT_TESTS_END
endmodule : htable_multi_rr_unit_test
