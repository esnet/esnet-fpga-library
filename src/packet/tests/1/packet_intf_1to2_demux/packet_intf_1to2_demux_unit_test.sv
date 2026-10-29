`include "svunit_defines.svh"

module packet_intf_1to2_demux_unit_test;

    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "packet_intf_1to2_demux_ut";
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

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) from_tx (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) to_rx_0 (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) to_rx_1 (.clk);

    packet_intf_1to2_demux DUT (.*);

    //===================================
    // Testbench
    //===================================
    packet_intf_driver  #(DATA_BYTE_WID, META_T) driver;
    packet_intf_monitor #(DATA_BYTE_WID, META_T) monitor_0;
    packet_intf_monitor #(DATA_BYTE_WID, META_T) monitor_1;

    `SVUNIT_CLK_GEN(clk, 4ns);

    function void build();
        svunit_ut = new(name);

        driver = new("driver");
        driver.packet_vif = from_tx;
        monitor_0 = new("monitor_0");
        monitor_0.packet_vif = to_rx_0;
        monitor_1 = new("monitor_1");
        monitor_1.packet_vif = to_rx_1;
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
        driver.idle();
        to_rx_0.rdy <= 1'b1;
        to_rx_1.rdy <= 1'b1;
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
                driver.send(make_pkt("p", 40, 8'h10, 16'hA0A0));
                monitor_0.receive(rx);
                begin
                    repeat (60) begin
                        @(posedge clk);
                        `FAIL_IF_LOG(to_rx_1.vld, "unselected output active")
                    end
                end
            join
            check_pkt(rx, 40, 8'h10, 16'hA0A0);
        `SVTEST_END

        `SVTEST(select_1)
            packet#(META_T) rx;
            sel <= 1'b1;
            repeat (4) @(posedge clk);
            fork
                driver.send(make_pkt("p", 40, 8'h20, 16'hB1B1));
                monitor_1.receive(rx);
                begin
                    repeat (60) begin
                        @(posedge clk);
                        `FAIL_IF_LOG(to_rx_0.vld, "unselected output active")
                    end
                end
            join
            check_pkt(rx, 40, 8'h20, 16'hB1B1);
        `SVTEST_END

        // A change in sel mid-packet takes effect at the next packet boundary.
        `SVTEST(switch_waits_for_packet_boundary)
            packet#(META_T) rx0, rx1;
            fork
                begin
                    driver.send(make_pkt("p0", 80, 8'h40, 16'hD3D3));
                    driver.send(make_pkt("p1", 32, 8'h50, 16'hE4E4));
                end
                begin
                    wait (from_tx.vld);
                    @(posedge clk);
                    sel <= 1'b1;
                end
                monitor_0.receive(rx0);
                monitor_1.receive(rx1);
            join
            check_pkt(rx0, 80, 8'h40, 16'hD3D3);
            check_pkt(rx1, 32, 8'h50, 16'hE4E4);
        `SVTEST_END

        // Backpressure from the selected destination stalls the source; the
        // other destination's ready is ignored.
        `SVTEST(rdy_follows_selected)
            packet#(META_T) rx;
            to_rx_0.rdy <= 1'b0;
            fork
                driver.send(make_pkt("p", 16, 8'h60, 16'h0F0F));
                begin
                    repeat (20) @(posedge clk);
                    `FAIL_IF_LOG(from_tx.rdy, "source accepted while selected destination stalled")
                    to_rx_0.rdy <= 1'b1;
                end
                monitor_0.receive(rx);
            join
            check_pkt(rx, 16, 8'h60, 16'h0F0F);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
