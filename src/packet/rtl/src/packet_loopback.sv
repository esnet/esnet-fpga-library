// Module: packet_loopback
//
// Description: Loopback switch for a bidirectional packet path.
//
//              Carries an outbound (tx) and an inbound (rx) packet stream.
//              When loopback is disabled the two streams pass through
//              independently; when enabled, the outbound stream is reflected
//              onto the inbound one and the far-end connections are quiesced.
//
//                en = 0 : packet_tx_in -> packet_tx_out
//                         packet_rx_in -> packet_rx_out
//
//                en = 1 : packet_tx_in -> packet_rx_out
//                         packet_tx_out held idle, packet_rx_in sunk
//
//              All four interfaces must share the clock supplied on
//              packet_tx_in.clk.
//
//              Mode changes are applied only at a packet boundary on both
//              paths.  A change in en quiesces each path as it reaches its
//              next boundary, waits until both are held, then commits the new
//              routing during a cycle in which no output is valid.  A packet
//              already in flight when en changes therefore completes at its
//              original destination, and the new routing takes effect from the
//              next packet.  Convergence is bounded by the longer of the two
//              in-flight packets rather than waiting for a chance idle.
//
//              While loopback is enabled packet_rx_in is sunk rather than
//              backpressured, so an upstream source is not stalled by the mode.
//              Because the mode only ever commits at a packet boundary, the
//              sink discards whole packets.
//
//              Routing is combinational: no latency is added in either mode.
//              If the packet_rx_out.rdy -> packet_tx_in.rdy path becomes
//              timing-critical, pipeline it outside this module; an internal
//              skid buffer would reintroduce in-flight beats that the mode
//              change logic would then have to track.
//
module packet_loopback (
    input  logic    srst,

    // Outbound path
    packet_intf.rx  packet_tx_in,
    packet_intf.tx  packet_tx_out,

    // Inbound path
    packet_intf.rx  packet_rx_in,
    packet_intf.tx  packet_rx_out,

    // Loopback enable (synchronous to packet_tx_in.clk)
    input  logic    en,

    // Mode actually applied, and an indication that a change is in progress.
    // en_mon lags en across a mode change; switching is held throughout.
    output logic    en_mon,
    output logic    switching
);
    localparam int DATA_BYTE_WID = packet_tx_in.DATA_BYTE_WID;
    localparam int META_WID      = packet_tx_in.META_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(packet_tx_out.DATA_BYTE_WID, DATA_BYTE_WID, "packet_tx_out.DATA_BYTE_WID");
        std_pkg::param_check(packet_rx_in.DATA_BYTE_WID,  DATA_BYTE_WID, "packet_rx_in.DATA_BYTE_WID");
        std_pkg::param_check(packet_rx_out.DATA_BYTE_WID, DATA_BYTE_WID, "packet_rx_out.DATA_BYTE_WID");
        std_pkg::param_check(packet_tx_out.META_WID,      META_WID,      "packet_tx_out.META_WID");
        std_pkg::param_check(packet_rx_in.META_WID,       META_WID,      "packet_rx_in.META_WID");
        std_pkg::param_check(packet_rx_out.META_WID,      META_WID,      "packet_rx_out.META_WID");
    end

    // Typedefs
    typedef enum logic [1:0] {
        RUN,
        QUIESCE,
        COMMIT
    } state_t;

    // Signals
    state_t state;
    state_t nxt_state;
    logic   hold_set;
    logic   hold_clr;
    logic   mode_commit;
    logic   hold_tx;
    logic   hold_rx;
    logic   sop_tx;
    logic   sop_rx;
    logic   sop_nxt_tx;
    logic   sop_nxt_rx;
    logic   arm_tx;
    logic   arm_rx;

    logic   clk;
    assign  clk = packet_tx_in.clk;

    // =========================================================================
    // Packet boundary tracking
    //
    // arm_* asserts when a path may be frozen at the end of the current cycle.
    // Two conditions must hold:
    //
    //   - The SOP state that will apply on the following cycle is set, i.e. no
    //     packet is partially transferred once this cycle's handshake (if any)
    //     completes.
    //   - No beat is being offered that has not been accepted.  Freezing on a
    //     stalled beat would drop vld before its handshake, which the
    //     valid/ready protocol forbids; gating rdy is always legal, retracting
    //     vld is not.  A destination that never accepts therefore holds the
    //     mode change off indefinitely, which switching reports.
    // =========================================================================
    packet_sop i_packet_sop__tx (
        .clk,
        .srst,
        .vld ( packet_tx_in.vld ),
        .rdy ( packet_tx_in.rdy ),
        .eop ( packet_tx_in.eop ),
        .sop ( sop_tx           )
    );

    packet_sop i_packet_sop__rx (
        .clk,
        .srst,
        .vld ( packet_rx_in.vld ),
        .rdy ( packet_rx_in.rdy ),
        .eop ( packet_rx_in.eop ),
        .sop ( sop_rx           )
    );

    assign sop_nxt_tx = (packet_tx_in.vld && packet_tx_in.rdy) ? packet_tx_in.eop : sop_tx;
    assign sop_nxt_rx = (packet_rx_in.vld && packet_rx_in.rdy) ? packet_rx_in.eop : sop_rx;

    assign arm_tx = sop_nxt_tx && (!(packet_tx_in.vld && !hold_tx) || packet_tx_in.rdy);
    assign arm_rx = sop_nxt_rx && (!(packet_rx_in.vld && !hold_rx) || packet_rx_in.rdy);

    // =========================================================================
    // Mode change sequencing
    //
    //   RUN      both paths running in the applied mode
    //   QUIESCE  a change is requested; park each path as it reaches a packet
    //            boundary, and wait until both are parked
    //   COMMIT   routing switched, both paths still parked for one cycle
    // =========================================================================
    initial state = RUN;
    always @(posedge clk) begin
        if (srst) state <= RUN;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state   = state;
        hold_set    = 1'b0;
        hold_clr    = 1'b0;
        mode_commit = 1'b0;
        case (state)
            RUN : begin
                hold_clr = 1'b1;
                if (en != en_mon) nxt_state = QUIESCE;
            end
            QUIESCE : begin
                hold_set = 1'b1;
                if (en == en_mon) nxt_state = RUN;  // request withdrawn
                else if ((hold_tx || arm_tx) && (hold_rx || arm_rx)) begin
                    mode_commit = 1'b1;
                    nxt_state   = COMMIT;
                end
            end
            COMMIT : begin
                nxt_state = RUN;
            end
            default : begin
                nxt_state = RUN;
            end
        endcase
    end

    // Hold latches. Set as each path reaches a boundary and sticky from there,
    // so a path that is already parked stays parked while the other drains.
    // Held through COMMIT and released on the way back to RUN.
    initial begin
        hold_tx = 1'b0;
        hold_rx = 1'b0;
    end
    always @(posedge clk) begin
        if (srst || hold_clr) begin
            hold_tx <= 1'b0;
            hold_rx <= 1'b0;
        end else if (hold_set) begin
            if (arm_tx) hold_tx <= 1'b1;
            if (arm_rx) hold_rx <= 1'b1;
        end
    end

    // Applied mode. Updated on entry to COMMIT, by which point both hold
    // latches are set, so the routing change lands in a cycle with no valid
    // output on either path.
    initial en_mon = 1'b0;
    always @(posedge clk) begin
        if (srst)             en_mon <= 1'b0;
        else if (mode_commit) en_mon <= en;
    end

    assign switching = (state != RUN);

    // =========================================================================
    // Routing
    // =========================================================================
    assign packet_tx_out.vld  = packet_tx_in.vld && !hold_tx && !en_mon;
    assign packet_tx_out.data = packet_tx_in.data;
    assign packet_tx_out.eop  = packet_tx_in.eop;
    assign packet_tx_out.mty  = packet_tx_in.mty;
    assign packet_tx_out.err  = packet_tx_in.err;
    assign packet_tx_out.meta = packet_tx_in.meta;

    assign packet_rx_out.vld  = en_mon ? (packet_tx_in.vld && !hold_tx)
                                       : (packet_rx_in.vld && !hold_rx);
    assign packet_rx_out.data = en_mon ? packet_tx_in.data : packet_rx_in.data;
    assign packet_rx_out.eop  = en_mon ? packet_tx_in.eop  : packet_rx_in.eop;
    assign packet_rx_out.mty  = en_mon ? packet_tx_in.mty  : packet_rx_in.mty;
    assign packet_rx_out.err  = en_mon ? packet_tx_in.err  : packet_rx_in.err;
    assign packet_rx_out.meta = en_mon ? packet_tx_in.meta : packet_rx_in.meta;

    assign packet_tx_in.rdy = !hold_tx && (en_mon ? packet_rx_out.rdy : packet_tx_out.rdy);
    assign packet_rx_in.rdy = !hold_rx && (en_mon ? 1'b1              : packet_rx_out.rdy);

endmodule : packet_loopback
