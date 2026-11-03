interface packet_intf #(
    parameter int DATA_BYTE_WID = 1,
    parameter int META_WID = 1
) (
    input logic clk
);
    initial begin
        std_pkg::param_check_gt(DATA_BYTE_WID, 1, "DATA_BYTE_WID");
        std_pkg::param_check_gt(META_WID,      1, "META_WID");
    end

    // Parameters
    localparam int MTY_WID = DATA_BYTE_WID > 1 ? $clog2(DATA_BYTE_WID) : 1;

    // Typedefs
    typedef logic [0:DATA_BYTE_WID-1][7:0] data_t;
    typedef logic [MTY_WID-1:0] mty_t;

    // Signals
    logic                          vld;
    logic                          rdy;
    logic [0:DATA_BYTE_WID-1][7:0] data;
    logic                          eop;
    logic [MTY_WID-1:0]            mty;
    logic                          err;
    logic [META_WID-1:0]           meta;

    // Modports
    modport tx(
        input  clk,
        output vld,
        input  rdy,
        output data,
        output eop,
        output mty,
        output err,
        output meta
    );

    modport rx(
        input  clk,
        input  vld,
        output rdy,
        input  data,
        input  eop,
        input  mty,
        input  err,
        input  meta
    );

    // mon_* signals are combinational mirrors of output-driven signals,
    // declared as separate nets so they can be listed as clocking block
    // inputs (sampled in the preponed region). The `input mon = sig` alias
    // syntax inside a clocking block is not supported by xsim.
    logic mon_tx_vld, mon_rx_rdy;
    assign mon_tx_vld = vld;
    assign mon_rx_rdy = rdy;

    clocking cb_tx @(posedge clk);
        output vld, data, eop, mty, err, meta;
        input rdy, mon_tx_vld;
    endclocking

    clocking cb_rx @(posedge clk);
        input vld, data, eop, mty, err, meta, mon_rx_rdy;
        output rdy;
    endclocking

    task idle_tx();
        cb_tx.vld <= 1'b0;
        cb_tx.data <= 'x;
        cb_tx.eop <= 'x;
        cb_tx.mty <= 'x;
        cb_tx.err <= 'x;
        cb_tx.meta <= 'x;
    endtask

    task idle_rx();
        cb_rx.rdy <= 1'b0;
    endtask

    task flush();
        cb_rx.rdy <= 1'b1;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb_tx);
    endtask

    task send(
            input bit [0:DATA_BYTE_WID-1][7:0] _data,
            input bit                _eop = 1'b0,
            input bit [MTY_WID-1:0]  _mty = '0,
            input bit                _err = 1'b0,
            input bit [META_WID-1:0] _meta = '0
        );
        cb_tx.vld <= 1'b1;
        cb_tx.data <= _data;
        cb_tx.eop <= _eop;
        cb_tx.mty <= _mty;
        cb_tx.err <= _err;
        cb_tx.meta <= _meta;
        @(cb_tx iff (cb_tx.mon_tx_vld && cb_tx.rdy));
        cb_tx.vld <= 1'b0;
        cb_tx.eop <= 1'b0;
    endtask

    task receive(
            output bit [0:DATA_BYTE_WID-1][7:0] _data,
            output bit                _eop,
            output bit [MTY_WID-1:0]  _mty,
            output bit                _err,
            output bit [META_WID-1:0] _meta
        );
        cb_rx.rdy <= 1'b1;
        @(cb_rx iff (cb_rx.vld && cb_rx.mon_rx_rdy));
        cb_rx.rdy <= 1'b0;
        _data = cb_rx.data;
        _eop = cb_rx.eop;
        _mty = cb_rx.mty;
        _err = cb_rx.err;
        _meta = cb_rx.meta;
    endtask

    task wait_ready(
            output bit _timeout,
            input  int TIMEOUT=0
        );
        fork
            begin
                fork
                    begin
                        wait(cb_tx.rdy);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

endinterface : packet_intf

// Packet interface (back-to-back) connector helper module
module packet_intf_connector (
    packet_intf.rx from_tx,
    packet_intf.tx to_rx
);
    // Parameter check
    initial begin
        std_pkg::param_check(to_rx.DATA_BYTE_WID, from_tx.DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check(to_rx.META_WID, from_tx.META_WID, "to_rx.META_WID");
    end

    // Connect signals (tx -> rx)
    assign to_rx.vld   = from_tx.vld;
    assign to_rx.data  = from_tx.data;
    assign to_rx.eop   = from_tx.eop;
    assign to_rx.mty   = from_tx.mty;
    assign to_rx.err   = from_tx.err;
    assign to_rx.meta  = from_tx.meta;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_intf_connector

// Packet transmitter termination
module packet_intf_tx_term (
    packet_intf.tx to_rx
);
    assign to_rx.vld = 1'b0;
    assign to_rx.data  = 'x;
    assign to_rx.eop   = 1'bx;
    assign to_rx.mty   = 'x;
    assign to_rx.err   = 1'bx;
    assign to_rx.meta  = 'x;

endmodule : packet_intf_tx_term

// Packet receiver termination (open circuit)
module packet_intf_rx_block (
    packet_intf.rx from_tx
);
    assign from_tx.rdy = 1'b0;
endmodule : packet_intf_rx_block

// Packet receiver termination (short circuit)
module packet_intf_rx_sink (
    packet_intf.rx from_tx
);
    assign from_tx.rdy = 1'b1;
endmodule : packet_intf_rx_sink

// Set packet metadata
module packet_intf_set_meta #(
    parameter int META_WID = 1
) (
    packet_intf.rx from_tx,
    packet_intf.tx to_rx,
    input logic [META_WID-1:0] meta
);
    // Parameter check
    initial begin
        std_pkg::param_check(to_rx.DATA_BYTE_WID, from_tx.DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check(to_rx.META_WID, META_WID, "to_rx.META_WID");
    end

    // Connect signals (tx -> rx)
    assign to_rx.vld   = from_tx.vld;
    assign to_rx.data  = from_tx.data;
    assign to_rx.eop   = from_tx.eop;
    assign to_rx.mty   = from_tx.mty;
    assign to_rx.err   = from_tx.err;
    assign to_rx.meta  = meta;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_intf_set_meta


// Packet interface N:1 mux
//
// Selects one of N packet streams to forward to a single destination.  The
// deselected sources are backpressured, so no packet is lost to the selection.
//
// A change in sel is applied only at a packet boundary on the output, so a
// packet already in flight completes from its original source and the new
// selection takes effect from the next packet.  The change is committed on a
// cycle in which no beat is offered and stalled: retracting vld before its
// handshake is forbidden, so a stalled beat holds the change off until it is
// accepted.  A destination that never accepts therefore holds the change off
// indefinitely.
//
// A sel value >= N selects no source (the output is idle).
//
// Routing is combinational: no latency is added.  sel is synchronous to
// to_rx.clk.
module packet_intf_mux #(
    parameter int N = 2,  // number of ingress packet interfaces
    // Derived parameters (don't override)
    parameter int SEL_WID = N > 1 ? $clog2(N) : 1
) (
    input  logic              srst,
    packet_intf.rx            from_tx [N],
    packet_intf.tx            to_rx,
    input  logic [SEL_WID-1:0] sel
);
    // Parameters
    localparam int DATA_BYTE_WID = to_rx.DATA_BYTE_WID;
    localparam int META_WID = to_rx.META_WID;
    localparam int MTY_WID = DATA_BYTE_WID > 1 ? $clog2(DATA_BYTE_WID) : 1;
    localparam int N_POW2 = 2**SEL_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx[0].DATA_BYTE_WID, DATA_BYTE_WID, "from_tx[*].DATA_BYTE_WID");
        std_pkg::param_check(from_tx[0].META_WID,      META_WID,      "from_tx[*].META_WID");
    end

    // Signals
    logic clk;
    assign clk = to_rx.clk;

    logic                          from_tx_vld  [N_POW2];
    logic [0:DATA_BYTE_WID-1][7:0] from_tx_data [N_POW2];
    logic                          from_tx_eop  [N_POW2];
    logic [MTY_WID-1:0]            from_tx_mty  [N_POW2];
    logic                          from_tx_err  [N_POW2];
    logic [META_WID-1:0]           from_tx_meta [N_POW2];

    logic [SEL_WID-1:0] sel_r;
    logic               sop;
    logic               sop_nxt;
    logic               arm;

    // Packet boundary tracking (on the output stream).  arm asserts when the
    // applied source may change at the end of the current cycle: no packet is
    // partially transferred once this cycle's handshake (if any) completes, and
    // no beat is being offered that has not been accepted.
    packet_sop i_packet_sop (
        .clk,
        .srst,
        .vld ( to_rx.vld ),
        .rdy ( to_rx.rdy ),
        .eop ( to_rx.eop ),
        .sop ( sop       )
    );

    assign sop_nxt = (to_rx.vld && to_rx.rdy) ? to_rx.eop : sop;
    assign arm     = sop_nxt && (!to_rx.vld || to_rx.rdy);

    // Applied source
    initial sel_r = '0;
    always @(posedge clk) begin
        if (srst)     sel_r <= '0;
        else if (arm) sel_r <= sel;
    end

    generate
        for (genvar g_input = 0; g_input < N; g_input++) begin : g__input
            assign from_tx_vld [g_input] = from_tx[g_input].vld;
            assign from_tx_data[g_input] = from_tx[g_input].data;
            assign from_tx_eop [g_input] = from_tx[g_input].eop;
            assign from_tx_mty [g_input] = from_tx[g_input].mty;
            assign from_tx_err [g_input] = from_tx[g_input].err;
            assign from_tx_meta[g_input] = from_tx[g_input].meta;
            assign from_tx[g_input].rdy  = (sel_r == g_input) ? to_rx.rdy : 1'b0;
        end : g__input
        // Specify 'out-of-range' values
        for (genvar g_input = N; g_input < N_POW2; g_input++) begin : g__input_out_of_range
            assign from_tx_vld [g_input] = 1'b0;
            assign from_tx_data[g_input] = '0;
            assign from_tx_eop [g_input] = 1'b0;
            assign from_tx_mty [g_input] = '0;
            assign from_tx_err [g_input] = 1'b0;
            assign from_tx_meta[g_input] = '0;
        end : g__input_out_of_range
    endgenerate

    // Mux logic
    assign to_rx.vld   = from_tx_vld [sel_r];
    assign to_rx.data  = from_tx_data[sel_r];
    assign to_rx.eop   = from_tx_eop [sel_r];
    assign to_rx.mty   = from_tx_mty [sel_r];
    assign to_rx.err   = from_tx_err [sel_r];
    assign to_rx.meta  = from_tx_meta[sel_r];

endmodule : packet_intf_mux


// Packet interface 2:1 mux
//
//   sel = 0 : from_tx_0 -> to_rx, from_tx_1 backpressured
//   sel = 1 : from_tx_1 -> to_rx, from_tx_0 backpressured
//
// A change in sel is applied at a packet boundary; see packet_intf_mux.
module packet_intf_2to1_mux (
    input  logic    srst,
    packet_intf.rx  from_tx_0,
    packet_intf.rx  from_tx_1,
    packet_intf.tx  to_rx,
    input  logic    sel
);
    localparam int DATA_BYTE_WID = to_rx.DATA_BYTE_WID;
    localparam int META_WID      = to_rx.META_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx_0.DATA_BYTE_WID, DATA_BYTE_WID, "from_tx_0.DATA_BYTE_WID");
        std_pkg::param_check(from_tx_1.DATA_BYTE_WID, DATA_BYTE_WID, "from_tx_1.DATA_BYTE_WID");
        std_pkg::param_check(from_tx_0.META_WID,      META_WID,      "from_tx_0.META_WID");
        std_pkg::param_check(from_tx_1.META_WID,      META_WID,      "from_tx_1.META_WID");
    end

    // Signals
    logic clk;
    assign clk = to_rx.clk;

    logic sel_r;
    logic sop;
    logic sop_nxt;
    logic arm;

    // Packet boundary tracking (on the output stream); see packet_intf_mux.
    packet_sop i_packet_sop (
        .clk,
        .srst,
        .vld ( to_rx.vld ),
        .rdy ( to_rx.rdy ),
        .eop ( to_rx.eop ),
        .sop ( sop       )
    );

    assign sop_nxt = (to_rx.vld && to_rx.rdy) ? to_rx.eop : sop;
    assign arm     = sop_nxt && (!to_rx.vld || to_rx.rdy);

    // Applied source
    initial sel_r = 1'b0;
    always @(posedge clk) begin
        if (srst)     sel_r <= 1'b0;
        else if (arm) sel_r <= sel;
    end

    // Mux
    assign to_rx.vld  = sel_r ? from_tx_1.vld  : from_tx_0.vld;
    assign to_rx.data = sel_r ? from_tx_1.data : from_tx_0.data;
    assign to_rx.eop  = sel_r ? from_tx_1.eop  : from_tx_0.eop;
    assign to_rx.mty  = sel_r ? from_tx_1.mty  : from_tx_0.mty;
    assign to_rx.err  = sel_r ? from_tx_1.err  : from_tx_0.err;
    assign to_rx.meta = sel_r ? from_tx_1.meta : from_tx_0.meta;

    // Demux rdy
    assign from_tx_0.rdy = !sel_r && to_rx.rdy;
    assign from_tx_1.rdy =  sel_r && to_rx.rdy;

endmodule : packet_intf_2to1_mux


// Packet interface 1:N demux
//
// Steers one packet stream to one of N destinations; the others are held idle.
//
// A change in sel is applied only at a packet boundary, so a packet already in
// flight completes at its original destination and the new routing takes effect
// from the next packet.  The change is committed on a cycle in which no beat is
// offered and stalled: retracting vld before its handshake is forbidden, so a
// stalled beat holds the change off until it is accepted.  A destination that
// never accepts therefore holds the change off indefinitely.
//
// A sel value >= N selects no destination: packets are accepted and discarded.
//
// Routing is combinational: no latency is added.  sel is synchronous to
// from_tx.clk.
module packet_intf_demux #(
    parameter int N = 2,  // number of egress packet interfaces
    // Derived parameters (don't override)
    parameter int SEL_WID = N > 1 ? $clog2(N) : 1
) (
    input  logic              srst,
    packet_intf.rx            from_tx,
    packet_intf.tx            to_rx [N],
    input  logic [SEL_WID-1:0] sel
);
    // Parameters
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int META_WID = from_tx.META_WID;
    localparam int N_POW2 = 2**SEL_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(to_rx[0].DATA_BYTE_WID, DATA_BYTE_WID, "to_rx[*].DATA_BYTE_WID");
        std_pkg::param_check(to_rx[0].META_WID,      META_WID,      "to_rx[*].META_WID");
    end

    // Signals
    logic clk;
    assign clk = from_tx.clk;

    logic rdy [N_POW2];

    logic [SEL_WID-1:0] sel_r;
    logic               sop;
    logic               sop_nxt;
    logic               arm;

    // Packet boundary tracking (on the input stream).  arm asserts when the
    // applied destination may change at the end of the current cycle: no packet
    // is partially transferred once this cycle's handshake (if any) completes,
    // and no beat is being offered that has not been accepted.
    packet_sop i_packet_sop (
        .clk,
        .srst,
        .vld ( from_tx.vld ),
        .rdy ( from_tx.rdy ),
        .eop ( from_tx.eop ),
        .sop ( sop         )
    );

    assign sop_nxt = (from_tx.vld && from_tx.rdy) ? from_tx.eop : sop;
    assign arm     = sop_nxt && (!from_tx.vld || from_tx.rdy);

    // Applied destination
    initial sel_r = '0;
    always @(posedge clk) begin
        if (srst)     sel_r <= '0;
        else if (arm) sel_r <= sel;
    end

    assign from_tx.rdy = rdy[sel_r];

    generate
        for (genvar g_output = 0; g_output < N; g_output++) begin : g__output
            assign rdy[g_output] = to_rx[g_output].rdy;

            assign to_rx[g_output].vld  = from_tx.vld && (sel_r == g_output);
            assign to_rx[g_output].data = from_tx.data;
            assign to_rx[g_output].eop  = from_tx.eop;
            assign to_rx[g_output].mty  = from_tx.mty;
            assign to_rx[g_output].err  = from_tx.err;
            assign to_rx[g_output].meta = from_tx.meta;
        end : g__output
        // Specify 'out-of-range' values
        for (genvar g_output = N; g_output < N_POW2; g_output++) begin : g__output_out_of_range
            assign rdy[g_output] = 1'b1;
        end : g__output_out_of_range
    endgenerate

endmodule : packet_intf_demux


// Packet interface 1:2 demux
//
//   sel = 0 : from_tx -> to_rx_0, to_rx_1 held idle
//   sel = 1 : from_tx -> to_rx_1, to_rx_0 held idle
//
// A change in sel is applied at a packet boundary; see packet_intf_demux.
module packet_intf_1to2_demux (
    input  logic    srst,
    packet_intf.rx  from_tx,
    packet_intf.tx  to_rx_0,
    packet_intf.tx  to_rx_1,
    input  logic    sel
);
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int META_WID      = from_tx.META_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(to_rx_0.DATA_BYTE_WID, DATA_BYTE_WID, "to_rx_0.DATA_BYTE_WID");
        std_pkg::param_check(to_rx_1.DATA_BYTE_WID, DATA_BYTE_WID, "to_rx_1.DATA_BYTE_WID");
        std_pkg::param_check(to_rx_0.META_WID,      META_WID,      "to_rx_0.META_WID");
        std_pkg::param_check(to_rx_1.META_WID,      META_WID,      "to_rx_1.META_WID");
    end

    // Signals
    logic clk;
    assign clk = from_tx.clk;

    logic sel_r;
    logic sop;
    logic sop_nxt;
    logic arm;

    // Packet boundary tracking (on the input stream); see packet_intf_demux.
    packet_sop i_packet_sop (
        .clk,
        .srst,
        .vld ( from_tx.vld ),
        .rdy ( from_tx.rdy ),
        .eop ( from_tx.eop ),
        .sop ( sop         )
    );

    assign sop_nxt = (from_tx.vld && from_tx.rdy) ? from_tx.eop : sop;
    assign arm     = sop_nxt && (!from_tx.vld || from_tx.rdy);

    // Applied destination
    initial sel_r = 1'b0;
    always @(posedge clk) begin
        if (srst)     sel_r <= 1'b0;
        else if (arm) sel_r <= sel;
    end

    // Demux
    assign to_rx_0.vld  = from_tx.vld && !sel_r;
    assign to_rx_0.data = from_tx.data;
    assign to_rx_0.eop  = from_tx.eop;
    assign to_rx_0.mty  = from_tx.mty;
    assign to_rx_0.err  = from_tx.err;
    assign to_rx_0.meta = from_tx.meta;

    assign to_rx_1.vld  = from_tx.vld && sel_r;
    assign to_rx_1.data = from_tx.data;
    assign to_rx_1.eop  = from_tx.eop;
    assign to_rx_1.mty  = from_tx.mty;
    assign to_rx_1.err  = from_tx.err;
    assign to_rx_1.meta = from_tx.meta;

    assign from_tx.rdy = sel_r ? to_rx_1.rdy : to_rx_0.rdy;

endmodule : packet_intf_1to2_demux
