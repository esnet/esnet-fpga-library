`include "svunit_defines.svh"

module packet_intf_mux_unit_test;

    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

    string name = "packet_intf_mux_ut";
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

    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) from_tx [N] (.clk);
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) to_rx (.clk);

    packet_intf_mux #(.N(N)) DUT (.*);

    //===================================
    // Testbench
    //===================================
    packet_intf_driver  #(DATA_BYTE_WID, META_T) driver [N];
    packet_intf_monitor #(DATA_BYTE_WID, META_T) monitor;

    `SVUNIT_CLK_GEN(clk, 4ns);

    function void build();
        svunit_ut = new(name);

        for (int i = 0; i < N; i++) driver[i] = new($sformatf("driver_%0d", i));
        driver[0].packet_vif = from_tx[0];
        driver[1].packet_vif = from_tx[1];
        driver[2].packet_vif = from_tx[2];
        monitor = new("monitor");
        monitor.packet_vif = to_rx;
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
        for (int i = 0; i < N; i++) driver[i].idle();
        to_rx.rdy <= 1'b1;
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

    // Send one packet from input i with sel already set to i
    task automatic pass_one(input int i);
        packet#(META_T) rx;
        sel <= SEL_WID'(i);
        repeat (4) @(posedge clk);
        fork
            driver[i].send(make_pkt("p", 40, byte'(8'h10 * (i+1)), META_T'(16'hA000 + i)));
            monitor.receive(rx);
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

        // sel beyond N-1 selects nothing: the output stays idle and the
        // inputs are held.
        `SVTEST(out_of_range_sel_idle)
            sel <= SEL_WID'(N);
            repeat (4) @(posedge clk);
            fork
                driver[0].send(make_pkt("p", 16, 8'h01, 16'h1111));
                begin
                    repeat (50) begin
                        @(posedge clk);
                        `FAIL_IF_LOG(to_rx.vld, "output active with out-of-range sel")
                        `FAIL_IF_LOG(from_tx[0].rdy, "input accepted with out-of-range sel")
                    end
                end
            join_any
            disable fork;
        `SVTEST_END

        // Deselected sources are held, not dropped, and delivered once selected.
        `SVTEST(deselected_source_held)
            packet#(META_T) rx;
            fork
                driver[2].send(make_pkt("p", 24, 8'h30, 16'hC2C2));
                begin
                    repeat (50) begin
                        @(posedge clk);
                        `FAIL_IF_LOG(to_rx.vld, "deselected source leaked to output")
                    end
                    sel <= SEL_WID'(2);
                end
                monitor.receive(rx);
            join
            check_pkt(rx, 24, 8'h30, 16'hC2C2);
        `SVTEST_END

        // A change in sel mid-packet takes effect at the next packet boundary.
        `SVTEST(switch_waits_for_packet_boundary)
            packet#(META_T) rx0, rx2;
            fork
                driver[0].send(make_pkt("p0", 80, 8'h40, 16'hD3D3));
                driver[2].send(make_pkt("p2", 32, 8'h50, 16'hE4E4));
                begin
                    wait (to_rx.vld);
                    @(posedge clk);
                    sel <= SEL_WID'(2);
                end
                begin
                    monitor.receive(rx0);
                    monitor.receive(rx2);
                end
            join
            check_pkt(rx0, 80, 8'h40, 16'hD3D3);
            check_pkt(rx2, 32, 8'h50, 16'hE4E4);
        `SVTEST_END

        // A stalled beat holds the selection.
        `SVTEST(stalled_beat_holds_selection)
            packet#(META_T) rx;
            to_rx.rdy <= 1'b0;
            fork
                driver[0].send(make_pkt("p0", 16, 8'h60, 16'h0F0F));
                begin
                    wait (to_rx.vld);
                    sel <= SEL_WID'(1);
                    repeat (10) @(posedge clk);
                    `FAIL_IF_LOG(from_tx[1].rdy, "selection changed while a beat was stalled")
                    to_rx.rdy <= 1'b1;
                end
                monitor.receive(rx);
            join
            check_pkt(rx, 16, 8'h60, 16'h0F0F);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
