`include "svunit_defines.svh"

module packet_intf_2to1_mux_unit_test;

    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "packet_intf_2to1_mux_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTE_WID = 8;
    localparam type META_T = logic[15:0];
    localparam int META_WID = $bits(META_T);

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;
    logic sel;

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) from_tx_0 (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) from_tx_1 (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) to_rx (.clk);

    packet_intf_2to1_mux DUT (.*);

    //===================================
    // Testbench
    //===================================
    packet_intf_driver  #(DATA_BYTE_WID, META_T) driver_0;
    packet_intf_driver  #(DATA_BYTE_WID, META_T) driver_1;
    packet_intf_monitor #(DATA_BYTE_WID, META_T) monitor;

    `SVUNIT_CLK_GEN(clk, 4ns);

    function void build();
        svunit_ut = new(name);

        driver_0 = new("driver_0");
        driver_0.packet_vif = from_tx_0;
        driver_1 = new("driver_1");
        driver_1.packet_vif = from_tx_1;
        monitor = new("monitor");
        monitor.packet_vif = to_rx;
    endfunction

    task setup();
        svunit_ut.setup();
        idle();
        sel <= 1'b0;
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
        driver_0.idle();
        driver_1.idle();
        to_rx.rdy <= 1'b1;
    endtask

    // Packet with a recognisable payload and meta
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

    //===================================
    // All tests run here
    //===================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(select_0)
            packet#(META_T) rx;
            fork
                driver_0.send(make_pkt("p", 40, 8'h10, 16'hA0A0));
                monitor.receive(rx);
            join
            check_pkt(rx, 40, 8'h10, 16'hA0A0);
        `SVTEST_END

        `SVTEST(select_1)
            packet#(META_T) rx;
            sel <= 1'b1;
            repeat (4) @(posedge clk);
            fork
                driver_1.send(make_pkt("p", 40, 8'h20, 16'hB1B1));
                monitor.receive(rx);
            join
            check_pkt(rx, 40, 8'h20, 16'hB1B1);
        `SVTEST_END

        // The deselected source is held, not dropped, and is delivered
        // once selected.
        `SVTEST(deselected_source_held)
            packet#(META_T) rx;
            fork
                driver_1.send(make_pkt("p", 24, 8'h30, 16'hC2C2));
                begin
                    repeat (50) begin
                        @(posedge clk);
                        `FAIL_IF_LOG(to_rx.vld, "deselected source leaked to output")
                    end
                    sel <= 1'b1;
                end
                begin
                    repeat (20) @(posedge clk);
                    monitor.receive(rx);
                end
            join
            check_pkt(rx, 24, 8'h30, 16'hC2C2);
        `SVTEST_END

        // A change in sel mid-packet takes effect at the next packet boundary.
        `SVTEST(switch_waits_for_packet_boundary)
            packet#(META_T) rx0, rx1;
            fork
                driver_0.send(make_pkt("p0", 80, 8'h40, 16'hD3D3));
                driver_1.send(make_pkt("p1", 32, 8'h50, 16'hE4E4));
                begin
                    // Flip select once the first packet is under way.
                    wait (to_rx.vld);
                    @(posedge clk);
                    sel <= 1'b1;
                end
                begin
                    monitor.receive(rx0);
                    monitor.receive(rx1);
                end
            join
            check_pkt(rx0, 80, 8'h40, 16'hD3D3);
            check_pkt(rx1, 32, 8'h50, 16'hE4E4);
        `SVTEST_END

        // A stalled output holds the selection.
        `SVTEST(stalled_beat_holds_selection)
            packet#(META_T) rx;
            to_rx.rdy <= 1'b0;
            fork
                driver_0.send(make_pkt("p0", 16, 8'h60, 16'h0F0F));
                begin
                    wait (to_rx.vld);
                    sel <= 1'b1;
                    repeat (10) @(posedge clk);
                    `FAIL_IF_LOG(from_tx_1.rdy, "selection changed while a beat was stalled")
                    to_rx.rdy <= 1'b1;
                end
                monitor.receive(rx);
            join
            check_pkt(rx, 16, 8'h60, 16'h0F0F);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
