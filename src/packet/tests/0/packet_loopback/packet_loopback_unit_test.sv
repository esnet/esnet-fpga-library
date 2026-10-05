`include "svunit_defines.svh"

module packet_loopback_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "packet_loopback_ut";
    svunit_testcase svunit_ut;

    `define SVUNIT_TIMEOUT 2ms

    localparam int DATA_BYTE_WID = 8;
    localparam int META_WID      = 8;
    localparam int MTY_WID       = $clog2(DATA_BYTE_WID);

    // =========================================================================
    // Clock and reset
    // =========================================================================
    logic clk  = 1'b0;
    logic srst = 1'b1;

    always #2ns clk = ~clk;

    // =========================================================================
    // Interfaces
    // =========================================================================
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) tx_in  (.clk(clk));
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) tx_out (.clk(clk));
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) rx_in  (.clk(clk));
    packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) rx_out (.clk(clk));

    logic en = 1'b0;
    logic en_mon;
    logic switching;

    // Drive all stimulus from time 0 so nothing is X before setup() runs.
    initial begin
        tx_in.vld = 1'b0; tx_in.data = '0; tx_in.eop = 1'b0;
        tx_in.mty = '0;   tx_in.err  = 1'b0; tx_in.meta = '0;
        rx_in.vld = 1'b0; rx_in.data = '0; rx_in.eop = 1'b0;
        rx_in.mty = '0;   rx_in.err  = 1'b0; rx_in.meta = '0;
        tx_out.rdy = 1'b1;
        rx_out.rdy = 1'b1;
    end

    // =========================================================================
    // DUT
    // =========================================================================
    packet_loopback DUT (
        .srst,
        .packet_tx_in  ( tx_in  ),
        .packet_tx_out ( tx_out ),
        .packet_rx_in  ( rx_in  ),
        .packet_rx_out ( rx_out ),
        .en,
        .en_mon,
        .switching
    );

    // =========================================================================
    // Protocol assertions
    //
    // The obligation this module could plausibly break: once vld is asserted
    // it must stay asserted, payload stable, until the handshake completes.
    // Gating rdy is always legal; retracting vld is not.
    // =========================================================================
    a_tx_out_stable: assert property (@(posedge clk) disable iff (srst)
        (tx_out.vld && !tx_out.rdy) |=> (tx_out.vld && $stable(tx_out.data) &&
            $stable(tx_out.eop) && $stable(tx_out.mty) && $stable(tx_out.err) &&
            $stable(tx_out.meta)));

    a_rx_out_stable: assert property (@(posedge clk) disable iff (srst)
        (rx_out.vld && !rx_out.rdy) |=> (rx_out.vld && $stable(rx_out.data) &&
            $stable(rx_out.eop) && $stable(rx_out.mty) && $stable(rx_out.err) &&
            $stable(rx_out.meta)));

    // Nothing may reach the far end while loopback is applied.
    a_tx_out_idle_when_looped: assert property (@(posedge clk) disable iff (srst)
        en_mon |-> !tx_out.vld);

    // =========================================================================
    // Packet model
    //
    // Every beat is self-describing: byte 0 is the packet id, byte 1 the beat
    // index, byte 2 the declared beat count. A monitor can therefore detect a
    // truncated packet, a dropped or duplicated beat, or two packets spliced
    // together, without being told what to expect.
    // =========================================================================
    typedef struct {
        int id;
        int beats;
        bit ok;
    } rx_pkt_t;

    rx_pkt_t tx_out_q [$];
    rx_pkt_t rx_out_q [$];

    function automatic logic [0:DATA_BYTE_WID-1][7:0] mk_beat(int id, int idx, int beats);
        logic [0:DATA_BYTE_WID-1][7:0] d;
        d = '0;
        d[0] = 8'(id);
        d[1] = 8'(idx);
        d[2] = 8'(beats);
        for (int b = 3; b < DATA_BYTE_WID; b++) d[b] = 8'(id + idx + b);
        return d;
    endfunction

    task automatic send_tx(input int id, input int beats);
        for (int i = 0; i < beats; i++)
            tx_in.send(mk_beat(id, i, beats), (i == beats-1), '0, 1'b0, META_WID'(id));
    endtask

    task automatic send_rx(input int id, input int beats);
        for (int i = 0; i < beats; i++)
            rx_in.send(mk_beat(id, i, beats), (i == beats-1), '0, 1'b0, META_WID'(id));
    endtask

    // =========================================================================
    // Output monitors
    //
    // Free-running; each captures one packet at a time and self-checks its
    // internal consistency. A reset abandons any packet in progress so a test
    // that resets mid-packet does not corrupt the next test's queue.
    // =========================================================================
    initial forever begin
        fork
            begin : mon_tx
                rx_pkt_t p;
                int idx;
                p.ok = 1'b1;
                @(posedge clk iff (tx_out.vld && tx_out.rdy));
                p.id    = tx_out.data[0];
                p.beats = tx_out.data[2];
                if (tx_out.data[1] != 0) p.ok = 1'b0;
                idx = 1;
                while (!tx_out.eop) begin
                    @(posedge clk iff (tx_out.vld && tx_out.rdy));
                    if (tx_out.data[0] != p.id)    p.ok = 1'b0;
                    if (tx_out.data[1] != idx)     p.ok = 1'b0;
                    if (tx_out.data[2] != p.beats) p.ok = 1'b0;
                    idx++;
                end
                if (idx != p.beats) p.ok = 1'b0;
                if (tx_out.meta != META_WID'(p.id)) p.ok = 1'b0;
                tx_out_q.push_back(p);
            end : mon_tx
            begin : rst_tx
                @(posedge srst);
            end : rst_tx
        join_any
        disable fork;
    end

    initial forever begin
        fork
            begin : mon_rx
                rx_pkt_t p;
                int idx;
                p.ok = 1'b1;
                @(posedge clk iff (rx_out.vld && rx_out.rdy));
                p.id    = rx_out.data[0];
                p.beats = rx_out.data[2];
                if (rx_out.data[1] != 0) p.ok = 1'b0;
                idx = 1;
                while (!rx_out.eop) begin
                    @(posedge clk iff (rx_out.vld && rx_out.rdy));
                    if (rx_out.data[0] != p.id)    p.ok = 1'b0;
                    if (rx_out.data[1] != idx)     p.ok = 1'b0;
                    if (rx_out.data[2] != p.beats) p.ok = 1'b0;
                    idx++;
                end
                if (idx != p.beats) p.ok = 1'b0;
                if (rx_out.meta != META_WID'(p.id)) p.ok = 1'b0;
                rx_out_q.push_back(p);
            end : mon_rx
            begin : rst_rx
                @(posedge srst);
            end : rst_rx
        join_any
        disable fork;
    end

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        srst <= 1'b1;
        repeat (4) @(posedge clk);
        srst <= 1'b0;
        repeat (4) @(posedge clk);
        tx_out_q.delete();
        rx_out_q.delete();
    endtask

    // Request a mode and wait for it to be applied.
    task automatic set_mode(input bit mode);
        en <= mode;
        @(posedge clk);
        forever begin
            @(posedge clk);
            if (!switching && (en_mon === mode)) break;
        end
    endtask

    task automatic wait_settled();
        while (switching) @(posedge clk);
    endtask

    task automatic wait_tx_out(input int n);
        while (tx_out_q.size() < n) @(posedge clk);
    endtask

    task automatic wait_rx_out(input int n);
        while (rx_out_q.size() < n) @(posedge clk);
    endtask

    // Retire stimulus left asserted by a driver abandoned via disable fork.
    task automatic force_idle();
        repeat (2) @(posedge clk);
        tx_in.vld = 1'b0; tx_in.eop = 1'b0;
        rx_in.vld = 1'b0; rx_in.eop = 1'b0;
        @(posedge clk);
    endtask

    task automatic quiet(input int cycles);
        repeat (cycles) @(posedge clk);
    endtask

    task automatic check_pkt(input rx_pkt_t p, input int id, input int beats);
        `FAIL_UNLESS_EQUAL(p.id, id);
        `FAIL_UNLESS_EQUAL(p.beats, beats);
        `FAIL_UNLESS_LOG(p.ok, "packet content check failed (truncated/spliced/reordered)");
    endtask

    task automatic expect_tx_out(input int id, input int beats);
        rx_pkt_t p;
        p = tx_out_q.pop_front();
        check_pkt(p, id, beats);
    endtask

    task automatic expect_rx_out(input int id, input int beats);
        rx_pkt_t p;
        p = rx_out_q.pop_front();
        check_pkt(p, id, beats);
    endtask

    // Drain a queue, requiring every packet to be internally consistent.
    task automatic drain_tx_out(output int n);
        rx_pkt_t p;
        n = 0;
        while (tx_out_q.size() > 0) begin
            p = tx_out_q.pop_front();
            `FAIL_UNLESS_LOG(p.ok, "tx_out packet corrupted");
            n++;
        end
    endtask

    task automatic drain_rx_out(output int n);
        rx_pkt_t p;
        n = 0;
        while (rx_out_q.size() > 0) begin
            p = rx_out_q.pop_front();
            `FAIL_UNLESS_LOG(p.ok, "rx_out packet corrupted");
            n++;
        end
    endtask

    // =========================================================================
    // Build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        en <= 1'b0;
        tx_out.rdy <= 1'b1;
        rx_out.rdy <= 1'b1;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    `SVUNIT_TESTS_BEGIN

        `SVTEST(compile)
        `SVTEST_END

        // Normal mode: the outbound stream reaches the far end.
        `SVTEST(normal_tx_path)
            send_tx(.id(1), .beats(4));
            wait_tx_out(1);
            expect_tx_out(1, 4);
            `FAIL_UNLESS_EQUAL(rx_out_q.size(), 0);
        `SVTEST_END

        // Normal mode: the inbound stream reaches the near end.
        `SVTEST(normal_rx_path)
            send_rx(.id(2), .beats(3));
            wait_rx_out(1);
            expect_rx_out(2, 3);
            `FAIL_UNLESS_EQUAL(tx_out_q.size(), 0);
        `SVTEST_END

        // Normal mode: both directions run independently and concurrently.
        `SVTEST(normal_concurrent)
            fork
                send_tx(.id(3), .beats(5));
                send_rx(.id(4), .beats(7));
            join
            wait_tx_out(1); wait_rx_out(1);
            expect_tx_out(3, 5);
            expect_rx_out(4, 7);
        `SVTEST_END

        // Loopback: the outbound stream is reflected onto the inbound one.
        `SVTEST(loopback_reflects_tx_to_rx_out)
            set_mode(1'b1);
            send_tx(.id(5), .beats(4));
            wait_rx_out(1);
            expect_rx_out(5, 4);
            `FAIL_UNLESS_EQUAL(tx_out_q.size(), 0);
        `SVTEST_END

        // Loopback: the inbound stream is consumed and discarded, and the
        // source is not stalled by the mode.
        `SVTEST(loopback_sinks_rx_in)
            set_mode(1'b1);
            send_rx(.id(6), .beats(4));   // completes only if rx_in is accepted
            quiet(32);
            `FAIL_UNLESS_EQUAL(rx_out_q.size(), 0);
            `FAIL_UNLESS_EQUAL(tx_out_q.size(), 0);
        `SVTEST_END

        // Enabling loopback part-way through an outbound packet: that packet
        // must still complete at its original destination, and only the next
        // one is reflected.
        `SVTEST(flip_midpacket_tx)
            for (int k = 1; k <= 5; k++) begin
                en <= 1'b0;
                reset_dut();
                fork
                    send_tx(.id(10+k), .beats(6));
                    begin
                        repeat (k) @(posedge clk iff (tx_in.vld && tx_in.rdy));
                        en <= 1'b1;
                    end
                join
                wait_tx_out(1);
                expect_tx_out(10+k, 6);
                `FAIL_UNLESS_EQUAL(rx_out_q.size(), 0);
                wait_settled();
                `FAIL_UNLESS(en_mon);
                send_tx(.id(20+k), .beats(3));
                wait_rx_out(1);
                expect_rx_out(20+k, 3);
                `FAIL_UNLESS_EQUAL(tx_out_q.size(), 0);
            end
        `SVTEST_END

        // Same, part-way through an inbound packet.
        `SVTEST(flip_midpacket_rx)
            for (int k = 1; k <= 5; k++) begin
                en <= 1'b0;
                reset_dut();
                fork
                    send_rx(.id(30+k), .beats(6));
                    begin
                        repeat (k) @(posedge clk iff (rx_in.vld && rx_in.rdy));
                        en <= 1'b1;
                    end
                join
                wait_rx_out(1);
                expect_rx_out(30+k, 6);
                wait_settled();
                `FAIL_UNLESS(en_mon);
            end
        `SVTEST_END

        // Both paths mid-packet when the mode changes.
        `SVTEST(flip_both_midpacket)
            fork
                send_tx(.id(40), .beats(8));
                send_rx(.id(41), .beats(6));
                begin
                    repeat (3) @(posedge clk iff (tx_in.vld && tx_in.rdy));
                    en <= 1'b1;
                end
            join
            wait_tx_out(1); wait_rx_out(1);
            expect_tx_out(40, 8);
            expect_rx_out(41, 6);
            wait_settled();
            `FAIL_UNLESS(en_mon);
        `SVTEST_END

        // Mode change requested while a beat is offered but backpressured.
        // The beat must not be dropped and vld must not retract; the stable
        // assertions above are the real check.
        `SVTEST(flip_while_backpressured)
            tx_out.rdy <= 1'b0;
            fork
                send_tx(.id(50), .beats(4));
                begin
                    repeat (4) @(posedge clk);
                    en <= 1'b1;                 // requested while stalled at SOP
                    repeat (8) @(posedge clk);
                    `FAIL_UNLESS_LOG(switching, "mode change should be held off by the stall");
                    tx_out.rdy <= 1'b1;          // release
                end
            join
            wait_tx_out(1);
            expect_tx_out(50, 4);
            wait_settled();
            `FAIL_UNLESS(en_mon);
        `SVTEST_END

        // Request withdrawn before it is applied: the FSM must return to the
        // original mode with both paths running.
        `SVTEST(rapid_double_flip)
            en <= 1'b1;
            @(posedge clk);
            en <= 1'b0;
            quiet(16);
            `FAIL_IF(switching);
            `FAIL_IF(en_mon);
            send_tx(.id(60), .beats(4));
            wait_tx_out(1);
            expect_tx_out(60, 4);
        `SVTEST_END

        // Back-to-back single-beat packets at full rate, across a mode change.
        `SVTEST(back_to_back_single_beat)
            fork
                begin
                    for (int i = 0; i < 16; i++) send_tx(.id(70+i), .beats(1));
                end
                begin
                    repeat (6) @(posedge clk iff (tx_in.vld && tx_in.rdy));
                    en <= 1'b1;
                end
            join
            wait_settled();
            quiet(16);
            // Every packet must land intact somewhere, and none may be lost.
            begin
                int n_tx, n_rx;
                drain_tx_out(n_tx);
                drain_rx_out(n_rx);
                `FAIL_UNLESS_EQUAL(n_tx + n_rx, 16);
            end
        `SVTEST_END

        // Randomised soak: random traffic, random backpressure, random mode
        // toggles. Checks that no packet is ever corrupted or spliced.
        `SVTEST(random_soak)
            int n_sent;
            n_sent = 0;
            fork
                begin : tx_src
                    for (int i = 0; i < 40; i++) begin
                        send_tx(.id(i), .beats($urandom_range(1, 6)));
                        n_sent++;
                        quiet($urandom_range(0, 3));
                    end
                end : tx_src
                begin : mode_toggle
                    repeat (20) begin
                        quiet($urandom_range(1, 50));
                        en <= $urandom_range(0, 1);
                    end
                end : mode_toggle
                begin : bp
                    repeat (200) begin
                        quiet($urandom_range(1, 10));
                        tx_out.rdy <= $urandom_range(0, 1);
                        rx_out.rdy <= $urandom_range(0, 1);
                    end
                    tx_out.rdy <= 1'b1;
                    rx_out.rdy <= 1'b1;
                end : bp
            join_any
            disable fork;
            force_idle();
            tx_out.rdy <= 1'b1;
            rx_out.rdy <= 1'b1;
            en <= 1'b0;
            quiet(64);
            // Every delivered packet must be internally consistent, and the
            // total delivered must not exceed what was sent.
            begin
                int n_tx, n_rx;
                drain_tx_out(n_tx);
                drain_rx_out(n_rx);
                `FAIL_UNLESS(n_tx + n_rx <= n_sent);
            end
        `SVTEST_END

        // Reset asserted while a mode change is pending must land in a
        // consistent state, with the requested mode eventually applied.
        `SVTEST(reset_during_quiesce)
            // Offer a beat that is never accepted, so the mode change cannot
            // commit.  Driven directly rather than through a driver process,
            // so the reset below has nothing left in flight to abandon.
            tx_out.rdy <= 1'b0;
            @(posedge clk);
            tx_in.vld  <= 1'b1;
            tx_in.data <= mk_beat(80, 0, 4);
            tx_in.eop  <= 1'b0;
            tx_in.meta <= META_WID'(80);
            repeat (4) @(posedge clk);
            en <= 1'b1;
            repeat (4) @(posedge clk);
            `FAIL_UNLESS_LOG(switching, "mode change should be pending while stalled");

            srst      <= 1'b1;                 // reset mid-QUIESCE
            tx_in.vld <= 1'b0;
            tx_in.eop <= 1'b0;
            repeat (4) @(posedge clk);
            srst       <= 1'b0;
            tx_out.rdy <= 1'b1;
            repeat (4) @(posedge clk);
            tx_out_q.delete();
            rx_out_q.delete();
            wait_settled();
            `FAIL_UNLESS_LOG(en_mon, "requested mode should be applied after reset");
            tx_out_q.delete();
            rx_out_q.delete();
            // Still functional afterwards
            send_tx(.id(81), .beats(3));
            wait_rx_out(1);
            expect_rx_out(81, 3);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : packet_loopback_unit_test
