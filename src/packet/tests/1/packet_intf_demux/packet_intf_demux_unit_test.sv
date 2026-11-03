`include "svunit_defines.svh"

module packet_intf_demux_unit_test;

    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "packet_intf_demux_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int N = 3;
    localparam int SEL_WID = $clog2(N);
    localparam int DATA_BYTE_WID = 8;
    localparam type META_T = logic[15:0];
    localparam int META_WID = $bits(META_T);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;
    logic [SEL_WID-1:0] sel;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) from_tx (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) to_rx [N] (.clk);

    packet_intf_demux #(.N(N)) DUT (.*);

    // Per-output vld / rdy as plain vectors (interface arrays cannot be
    // indexed by a variable)
    logic [N-1:0] out_vld;
    logic [N-1:0] out_rdy;

    generate
        for (genvar g = 0; g < N; g++) begin : g__out
            assign out_vld[g]     = to_rx[g].vld;
            assign to_rx[g].rdy   = out_rdy[g];
        end : g__out
    endgenerate

    //===================================
    // Testbench
    //===================================
    packet_intf_driver  #(DATA_BYTE_WID, META_T) driver;
    packet_intf_monitor #(DATA_BYTE_WID, META_T) monitor [N];

    `SVUNIT_CLK_GEN(clk, 4ns);

    function void build();
        svunit_ut = new(name);

        driver = new("driver");
        driver.packet_vif = from_tx;
        for (int i = 0; i < N; i++) monitor[i] = new($sformatf("monitor_%0d", i));
        monitor[0].packet_vif = to_rx[0];
        monitor[1].packet_vif = to_rx[1];
        monitor[2].packet_vif = to_rx[2];
    endfunction

    task setup();
        svunit_ut.setup();
        idle();
        sel <= '0;
        srst <= 1'b1;
        repeat (8) @(posedge clk);
        srst <= 1'b0;
        repeat (8) @(posedge clk);
    endtask

    task teardown();
        svunit_ut.teardown();
        idle();
    endtask

    task idle();
        driver.idle();
        out_rdy <= '1;
    endtask

    function automatic packet#(META_T) make_pkt(input string nm, input int len, input byte seed, input META_T meta);
        byte data[] = new[len];
        for (int i = 0; i < len; i++) data[i] = seed + i;
        return packet_raw#(META_T)::create_from_bytes(nm, data, meta, 1'b0);
    endfunction

    task automatic check_pkt(input packet#(META_T) pkt, input int len, input byte seed, input META_T meta);
        byte data[] = pkt.to_bytes();
        `FAIL_UNLESS_EQUAL(pkt.size(), len)
        for (int i = 0; i < len; i++) `FAIL_UNLESS_EQUAL(data[i], byte'(seed + i))
        `FAIL_UNLESS_EQUAL(pkt.get_meta(), meta)
    endtask

    // Send one packet with sel = i; only output i may see it.
    task automatic pass_one(input int i);
        packet#(META_T) rx;
        sel <= SEL_WID'(i);
        repeat (4) @(posedge clk);
        fork
            driver.send(make_pkt("p", 40, byte'(8'h10 * (i+1)), META_T'(16'hA000 + i)));
            monitor[i].receive(rx);
            begin
                repeat (60) begin
                    @(posedge clk);
                    for (int j = 0; j < N; j++)
                        if (j != i) `FAIL_IF_LOG(out_vld[j], "unselected output active")
                end
            end
        join
        check_pkt(rx, 40, byte'(8'h10 * (i+1)), META_T'(16'hA000 + i));
    endtask

    //===================================
    // All tests run here
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(select_0)  pass_one(0); `SVTEST_END
        `SVTEST(select_1)  pass_one(1); `SVTEST_END
        `SVTEST(select_2)  pass_one(2); `SVTEST_END

        // sel beyond N-1 selects no destination: the packet is accepted and
        // discarded, and no output sees it.
        `SVTEST(out_of_range_sel_discards)
            sel <= SEL_WID'(N);
            repeat (4) @(posedge clk);
            fork
                driver.send(make_pkt("p", 16, 8'h01, 16'h1111));
                begin
                    repeat (50) begin
                        @(posedge clk);
                        for (int j = 0; j < N; j++)
                            `FAIL_IF_LOG(out_vld[j], "output active with out-of-range sel")
                    end
                end
            join
        `SVTEST_END

        // A change in sel mid-packet takes effect at the next packet boundary.
        `SVTEST(switch_waits_for_packet_boundary)
            packet#(META_T) rx0, rx2;
            fork
                begin
                    driver.send(make_pkt("p0", 80, 8'h40, 16'hD3D3));
                    driver.send(make_pkt("p2", 32, 8'h50, 16'hE4E4));
                end
                begin
                    wait (from_tx.vld);
                    @(posedge clk);
                    sel <= SEL_WID'(2);
                end
                monitor[0].receive(rx0);
                monitor[2].receive(rx2);
            join
            check_pkt(rx0, 80, 8'h40, 16'hD3D3);
            check_pkt(rx2, 32, 8'h50, 16'hE4E4);
        `SVTEST_END

        // Backpressure from the selected destination stalls the source; other
        // destinations' ready is ignored.
        `SVTEST(rdy_follows_selected)
            packet#(META_T) rx;
            sel <= SEL_WID'(1);
            repeat (4) @(posedge clk);
            out_rdy[1] <= 1'b0;
            fork
                driver.send(make_pkt("p", 16, 8'h60, 16'h0F0F));
                begin
                    repeat (20) @(posedge clk);
                    `FAIL_IF_LOG(from_tx.rdy, "source accepted while selected destination stalled")
                    out_rdy[1] <= 1'b1;
                end
                monitor[1].receive(rx);
            join
            check_pkt(rx, 16, 8'h60, 16'h0F0F);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
