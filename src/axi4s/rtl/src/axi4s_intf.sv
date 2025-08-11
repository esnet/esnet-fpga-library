interface axi4s_intf #(
    parameter int DATA_BYTE_WID = 8,
    parameter int TID_WID   = 1,
    parameter int TDEST_WID = 1,
    parameter int TUSER_WID = 1
) (
    input logic aclk,
    input logic aresetn = 1'b1
);
    // Parameter validation
    initial begin
        std_pkg::param_check_gt(DATA_BYTE_WID, 1, "DATA_BYTE_WID");
        std_pkg::param_check_gt(TID_WID,       1, "TID_WID");
        std_pkg::param_check_gt(TDEST_WID,     1, "TDEST_WID");
        std_pkg::param_check_gt(TUSER_WID,     1, "TUSER_WID");
    end

    // Signals
    logic                          tvalid;
    logic                          tready;
    logic [DATA_BYTE_WID-1:0][7:0] tdata;
    logic [DATA_BYTE_WID-1:0]      tkeep;
    logic                          tlast;
    logic [TID_WID-1:0]            tid;
    logic [TDEST_WID-1:0]          tdest;
    logic [TUSER_WID-1:0]          tuser;

    // Status
    logic                          sop;

    // Modports
    modport tx (
        input  aclk,
        input  aresetn,
        output tvalid,
        input  tready,
        output tdata,
        output tkeep,
        output tlast,
        output tid,
        output tdest,
        output tuser,
        // Status
        input  sop
    );

    modport rx (
        input  aclk,
        input  aresetn,
        input  tvalid,
        output tready,
        input  tdata,
        input  tkeep,
        input  tlast,
        input  tid,
        input  tdest,
        input  tuser,
        // Status
        input  sop
    );

    modport prb (
        input  aclk,
        input  aresetn,
        input  tvalid,
        input  tready,
        input  tdata,
        input  tkeep,
        input  tlast,
        input  tid,
        input  tdest,
        input  tuser,
        // Status
        input  sop
    );

    clocking cb_tx @(posedge aclk);
        default input #1step output #1step;
        output tdata, tkeep, tlast, tid, tdest, tuser;
        input tready;
        inout tvalid;
    endclocking

    clocking cb_rx @(posedge aclk);
        default input #1step output #1step;
        input tvalid, tdata, tkeep, tlast, tid, tdest, tuser;
        inout tready;
    endclocking

    clocking cb @(posedge aclk);
        default input #1step output #1step;
        input tvalid, tready, tdata, tkeep, tlast, tid, tdest, tuser;
    endclocking

    task idle_tx();
        cb_tx.tvalid <= 1'b0;
        cb_tx.tlast  <= 1'b0;
        cb_tx.tkeep  <= '0;
        cb_tx.tdata  <= '0;
        cb_tx.tid    <= '0;
        cb_tx.tdest  <= '0;
        cb_tx.tuser  <= '0;
    endtask

    task idle_rx();
        cb_rx.tready <= 1'b0;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task send(
            input bit [DATA_BYTE_WID-1:0][7:0] _tdata,
            input bit [DATA_BYTE_WID-1:0]      _tkeep,
            input bit                          _tlast,
            input bit [TID_WID-1:0]            _tid=0,
            input bit [TDEST_WID-1:0]          _tdest=0,
            input bit [TUSER_WID-1:0]          _tuser=0,
            input int twait = 0
        );
        if (twait > 0) begin
            cb_tx.tvalid <= 1'b0;
            _wait(twait);
        end
        cb_tx.tvalid <= 1'b1;
        cb_tx.tlast <= _tlast;
        cb_tx.tkeep <= _tkeep;
        cb_tx.tdata <= _tdata;
        cb_tx.tid <= _tid;
        cb_tx.tdest <= _tdest;
        cb_tx.tuser <= _tuser;
        @(cb_tx);
        wait (cb_tx.tvalid && cb_tx.tready);
        cb_tx.tvalid <= 1'b0;
        cb_tx.tlast <= 1'b0;
    endtask

    task receive(
            output bit [DATA_BYTE_WID-1:0][7:0] _tdata,
            output bit [DATA_BYTE_WID-1:0]      _tkeep,
            output bit                          _tlast,
            output bit [TID_WID-1:0]            _tid,
            output bit [TDEST_WID-1:0]          _tdest,
            output bit [TUSER_WID-1:0]          _tuser,
            input  int tpause = 0
        );
        if (tpause > 0) begin
            cb_rx.tready <= 1'b0;
            _wait(tpause);
        end
        cb_rx.tready <= 1'b1;
        @(cb_rx);
        wait (cb_rx.tvalid && cb_rx.tready);
        cb_rx.tready <= 1'b0;
        _tdata = cb_rx.tdata;
        _tkeep = cb_rx.tkeep;
        _tlast = cb_rx.tlast;
        _tid   = cb_rx.tid;
        _tdest = cb_rx.tdest;
        _tuser = cb_rx.tuser;
    endtask

    task sample(
            output bit [DATA_BYTE_WID-1:0][7:0] _tdata,
            output bit [DATA_BYTE_WID-1:0]      _tkeep,
            output bit                          _tlast,
            output bit [TID_WID-1:0]            _tid,
            output bit [TDEST_WID-1:0]          _tdest,
            output bit [TUSER_WID-1:0]          _tuser
        );
        do @(cb); while (!(cb.tvalid && cb.tready));
        _tdata = cb.tdata;
        _tkeep = cb.tkeep;
        _tlast = cb.tlast;
        _tid = cb.tid;
        _tdest = cb.tdest;
        _tuser = cb.tuser;
    endtask

    task wait_ready(
            output bit _timeout,
            input  int TIMEOUT=0
        );
        fork
            begin
                fork
                    begin
                        wait(cb_tx.tready);
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

    // Synthesize SOP
    initial sop = 1;
    always @(posedge aclk) begin
        if (!aresetn) sop <= 1'b1;
        else begin
            if (tvalid && tready && tlast)  sop <= 1'b1;
            else if (tvalid && tready)      sop <= 1'b0;
        end
    end

endinterface : axi4s_intf

module axi4s_intf_parameter_check (
    axi4s_intf from_tx,
    axi4s_intf to_rx
);
    initial begin
        std_pkg::param_check(from_tx.DATA_BYTE_WID, to_rx.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(from_tx.TID_WID,       to_rx.TID_WID,       "TID_WID");
        std_pkg::param_check(from_tx.TDEST_WID,     to_rx.TDEST_WID,     "TDEST_WID");
        std_pkg::param_check(from_tx.TUSER_WID,     to_rx.TUSER_WID,     "TUSER_WID");
    end
endmodule

// AXI4-Stream transmit termination helper module
module axi4s_intf_tx_term (
    axi4s_intf.tx to_rx
);
    // Tie off transmit outputs
    assign to_rx.tvalid = 1'b0;
    assign to_rx.tdata = '0;
    assign to_rx.tkeep = '0;
    assign to_rx.tlast = 1'b0;
    assign to_rx.tid = '0;
    assign to_rx.tdest = '0;
    assign to_rx.tuser = '0;

endmodule : axi4s_intf_tx_term


// AXI4-Stream (blocking) receive termination helper module
module axi4s_intf_rx_block (
    axi4s_intf.rx from_tx
);
    // Tie off receive outputs
    assign from_tx.tready = 1'b0;

endmodule : axi4s_intf_rx_block


// AXI4-Stream (sink) receive termination helper module
module axi4s_intf_rx_sink (
    axi4s_intf.rx from_tx
);
    // Tie off receive outputs
    assign from_tx.tready = 1'b1;

endmodule : axi4s_intf_rx_sink


// AXI4-Stream (back-to-back) connector helper module
module axi4s_intf_connector #(
    parameter bit IGNORE_TREADY = 0
) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx
);
    axi4s_intf_parameter_check param_check_0 (.*);

    // Connect signals (rx -> tx)
    assign to_rx.tvalid  = from_tx.tvalid;
    assign to_rx.tdata   = from_tx.tdata;
    assign to_rx.tkeep   = from_tx.tkeep;
    assign to_rx.tlast   = from_tx.tlast;
    assign to_rx.tid     = from_tx.tid;
    assign to_rx.tdest   = from_tx.tdest;
    assign to_rx.tuser   = from_tx.tuser;

    // Connect signals (tx -> rx)
    assign from_tx.tready = IGNORE_TREADY ? 1'b1 : to_rx.tready;
endmodule : axi4s_intf_connector


// AXI4-Stream set metadata helper module
module axi4s_intf_set_meta #(
    parameter int TID_WID = 1,
    parameter int TDEST_WID = 1,
    parameter int TUSER_WID = 1
) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx,
    input logic [TID_WID-1:0]   tid = '0,
    input logic [TDEST_WID-1:0] tdest = '0,
    input logic [TUSER_WID-1:0] tuser = '0
);

    // Parameter check
    initial begin
        std_pkg::param_check(to_rx.DATA_BYTE_WID, from_tx.DATA_BYTE_WID, "DATA_BYTE_WID");
    end

    // Connect signals (rx -> tx)
    assign to_rx.tvalid  = from_tx.tvalid;
    assign to_rx.tdata   = from_tx.tdata;
    assign to_rx.tkeep   = from_tx.tkeep;
    assign to_rx.tlast   = from_tx.tlast;
    assign to_rx.tid     = tid;
    assign to_rx.tdest   = tdest;
    assign to_rx.tuser   = tuser;

    // Connect signals (tx -> rx)
    assign from_tx.tready = to_rx.tready;

endmodule

// AXI4-Stream monitor helper module
module axi4s_intf_monitor (
    axi4s_intf.rx  from_tx,
    axi4s_intf.prb to_prb
);
    axi4s_intf_parameter_check param_check_0 (.from_tx, .to_rx(to_prb));

    // Connect signals (rx -> tx)
    assign to_prb.tvalid  = from_tx.tvalid;
    assign to_prb.tdata   = from_tx.tdata;
    assign to_prb.tkeep   = from_tx.tkeep;
    assign to_prb.tlast   = from_tx.tlast;
    assign to_prb.tid     = from_tx.tid;
    assign to_prb.tdest   = from_tx.tdest;
    assign to_prb.tuser   = from_tx.tuser;
    assign to_prb.tready  = from_tx.tready;

endmodule : axi4s_intf_monitor


// AXI4-Stream pipeline helper module
module axi4s_intf_pipe
    import axi4s_pkg::*;
#(
    parameter axi4s_pipe_mode_t MODE = PULL
) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx
);
    axi4s_intf_parameter_check param_check_0 (.*);

    logic ready;

    // TVALID buffer
    initial to_rx.tvalid = 1'b0;
    always @(posedge from_tx.aclk) begin
        if (!from_tx.aresetn)                      to_rx.tvalid <= 1'b0;
        else if (from_tx.tvalid && from_tx.tready) to_rx.tvalid <= 1'b1;
        else if (to_rx.tready)                     to_rx.tvalid <= 1'b0;
    end

    // TREADY
    initial ready = 1'b1;
    always @(posedge from_tx.aclk) begin
        if (!from_tx.aresetn)    ready <= 1'b1;
        else if (from_tx.tvalid) ready <= 1'b0;
        else if (to_rx.tready)   ready <= 1'b1;
    end
    assign from_tx.tready = (MODE == PUSH) ? to_rx.tready : (ready || to_rx.tready);

    // Data
    always_ff @(posedge from_tx.aclk) begin
        if (from_tx.tready) begin
            to_rx.tdata <= from_tx.tdata;
            to_rx.tkeep <= from_tx.tkeep;
            to_rx.tlast <= from_tx.tlast;
            to_rx.tid   <= from_tx.tid;
            to_rx.tdest <= from_tx.tdest;
            to_rx.tuser <= from_tx.tuser;
        end
    end

endmodule : axi4s_intf_pipe


// axi4-stream tready pipeline helper module
module axi4s_tready_pipe (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx
);
    import axi4s_pkg::*;

    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TID_WID       = from_tx.TID_WID;
    localparam int TDEST_WID     = from_tx.TDEST_WID;
    localparam int TUSER_WID     = from_tx.TUSER_WID;

    axi4s_intf_parameter_check param_check_0 (.*);

    logic  tready_falling;
    logic  fwft;
    logic  sample_enable;

    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID) )
                from_tx_p (.aclk (from_tx.aclk), .aresetn(from_tx.aresetn));

    logic to_rx_tready_p = 0;
    always @(posedge from_tx.aclk) begin
        if (!from_tx.aresetn)  to_rx_tready_p <= 1'b0;
        else                   to_rx_tready_p <= to_rx.tready;
    end

    assign fwft = from_tx.tvalid && !from_tx_p.tvalid && !to_rx_tready_p;

    assign tready_falling = to_rx_tready_p && !to_rx.tready;

    // sample data flops if rx is deasserting tready, or if sample flops can receive next valid word (first-word-fall-through).
    assign sample_enable  = tready_falling || (fwft && !to_rx.tready);


    // assert tready if rx is ready, or if sample flops can receive next valid word (first-word-fall-through).
    assign from_tx.tready = to_rx_tready_p || fwft;

    // sample data flops, and deassert tvalid when flopped data is transferred.
    always_ff @(posedge from_tx.aclk) begin
        if (!from_tx.aresetn)                      from_tx_p.tvalid <= '0;
        else if (to_rx.tready && from_tx_p.tvalid) from_tx_p.tvalid <= '0;
        else if (sample_enable)                    from_tx_p.tvalid <= from_tx.tvalid;

        if (!from_tx_p.tvalid) begin
            from_tx_p.tdata  <= from_tx.tdata;
            from_tx_p.tkeep  <= from_tx.tkeep;
            from_tx_p.tlast  <= from_tx.tlast;
            from_tx_p.tid    <= from_tx.tid;
            from_tx_p.tdest  <= from_tx.tdest;
            from_tx_p.tuser  <= from_tx.tuser;
        end
    end

    // output mux logic.
    always_comb begin
       // select sample flops when a valid sample is captured.
       if (from_tx_p.tvalid) begin
            to_rx.tvalid = from_tx_p.tvalid;
            to_rx.tdata  = from_tx_p.tdata;
            to_rx.tkeep  = from_tx_p.tkeep;
            to_rx.tlast  = from_tx_p.tlast;
            to_rx.tid    = from_tx_p.tid;
            to_rx.tdest  = from_tx_p.tdest;
            to_rx.tuser  = from_tx_p.tuser;
       // otherwise select input data.
       end else begin
            to_rx.tvalid = from_tx.tvalid;
            to_rx.tdata  = from_tx.tdata;
            to_rx.tkeep  = from_tx.tkeep;
            to_rx.tlast  = from_tx.tlast;
            to_rx.tid    = from_tx.tid;
            to_rx.tdest  = from_tx.tdest;
            to_rx.tuser  = from_tx.tuser;
       end
    end

endmodule : axi4s_tready_pipe


// axi4-stream full (bidirectional) pipeline helper module
module axi4s_full_pipe
    import axi4s_pkg::*;
#(
    parameter axi4s_pipe_mode_t MODE = PULL
) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx
);
    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TID_WID       = from_tx.TID_WID;
    localparam int TDEST_WID     = from_tx.TDEST_WID;
    localparam int TUSER_WID     = from_tx.TUSER_WID;

    axi4s_intf_parameter_check param_check_0 (.*);

    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID) )
                from_tx_p (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));

    axi4s_intf_pipe #(.MODE(MODE))  axi4s_intf_pipe_0   (.from_tx, .to_rx(from_tx_p));

    axi4s_tready_pipe axi4s_tready_pipe_0 (.from_tx(from_tx_p), .to_rx);

endmodule : axi4s_full_pipe


// AXI-Stream interface N:1 mux
module axi4s_intf_mux #(
    parameter int N = 2  // number of ingress axi4s interfaces.
) (
    axi4s_intf.rx                from_tx[N],
    axi4s_intf.tx                to_rx,
    input logic [$clog2(N)-1:0]  sel
);

    localparam int DATA_BYTE_WID = to_rx.DATA_BYTE_WID;
    localparam int TID_WID       = to_rx.TID_WID;
    localparam int TDEST_WID     = to_rx.TDEST_WID;
    localparam int TUSER_WID     = to_rx.TUSER_WID;

    axi4s_intf_parameter_check param_check (.from_tx(from_tx[0]), .to_rx);

    logic                          tvalid[N];
    logic [DATA_BYTE_WID-1:0][7:0] tdata[N];
    logic [DATA_BYTE_WID-1:0]      tkeep[N];
    logic                          tlast[N];
    logic [TID_WID-1:0]            tid[N];
    logic [TDEST_WID-1:0]          tdest[N];
    logic [TUSER_WID-1:0]          tuser[N];

    logic                          tready[N];

    // Convert between array of signals and array of interfaces
    generate
        for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
            assign  tvalid[g_if] = from_tx[g_if].tvalid;
            assign   tdata[g_if] = from_tx[g_if].tdata;
            assign   tkeep[g_if] = from_tx[g_if].tkeep;
            assign   tlast[g_if] = from_tx[g_if].tlast;
            assign     tid[g_if] = from_tx[g_if].tid;
            assign   tdest[g_if] = from_tx[g_if].tdest;
            assign   tuser[g_if] = from_tx[g_if].tuser;

            assign from_tx[g_if].tready = (sel == g_if) ? to_rx.tready : 1'b0;
        end
    endgenerate

    always_comb begin
        // mux logic
        to_rx.tvalid  = tvalid  [sel];
        to_rx.tlast   = tlast   [sel];
        to_rx.tkeep   = tkeep   [sel];
        to_rx.tdata   = tdata   [sel];
        to_rx.tid     = tid     [sel];
        to_rx.tdest   = tdest   [sel];
        to_rx.tuser   = tuser   [sel];
    end

endmodule


// AXI-Stream interface 2:1 mux
module axi4s_intf_2to1_mux (
    axi4s_intf.rx from_tx_0,
    axi4s_intf.rx from_tx_1,
    axi4s_intf.tx to_rx,
    input logic   mux_sel
);
    axi4s_intf_parameter_check param_check_0 (.from_tx(from_tx_0), .to_rx);
    axi4s_intf_parameter_check param_check_1 (.from_tx(from_tx_1), .to_rx);

    // Mux
    assign to_rx.tvalid = mux_sel ? from_tx_1.tvalid : from_tx_0.tvalid;
    assign to_rx.tlast  = mux_sel ? from_tx_1.tlast  : from_tx_0.tlast;
    assign to_rx.tkeep  = mux_sel ? from_tx_1.tkeep  : from_tx_0.tkeep;
    assign to_rx.tdata  = mux_sel ? from_tx_1.tdata  : from_tx_0.tdata;
    assign to_rx.tid    = mux_sel ? from_tx_1.tid    : from_tx_0.tid;
    assign to_rx.tdest  = mux_sel ? from_tx_1.tdest  : from_tx_0.tdest;
    assign to_rx.tuser  = mux_sel ? from_tx_1.tuser  : from_tx_0.tuser;

    // Demux TREADY
    assign from_tx_0.tready = mux_sel ? 1'b0 : to_rx.tready;
    assign from_tx_1.tready = mux_sel ? to_rx.tready : 1'b0;

endmodule


// AXI-Stream interface 1:N demux
module axi4s_intf_demux #(
    parameter int N = 2  // number of egress axi4s interfaces.
) (
    axi4s_intf.rx  from_tx,
    axi4s_intf.tx  to_rx[N],

    input logic [$clog2(N)-1:0]  sel
);

    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TID_WID       = from_tx.TID_WID;
    localparam int TDEST_WID     = from_tx.TDEST_WID;
    localparam int TUSER_WID     = from_tx.TUSER_WID;

    axi4s_intf_parameter_check param_check (.from_tx, .to_rx(to_rx[0]));

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) from_tx_p (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID)) to_rx_p[N] (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));

    logic tready[N];

    axi4s_intf_connector axi4s_intf_connector_in (.from_tx, .to_rx(from_tx_p));

    // axis4s input interface signalling.
    assign from_tx_p.tready = tready[sel];

    generate
        for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
            assign tready[g_if] = to_rx_p[g_if].tready;

            // axis4s output interface signalling.
            assign to_rx_p[g_if].tvalid  = (sel == g_if) ? from_tx_p.tvalid : 1'b0;
            assign to_rx_p[g_if].tdata   = from_tx_p.tdata;
            assign to_rx_p[g_if].tkeep   = from_tx_p.tkeep;
            assign to_rx_p[g_if].tlast   = from_tx_p.tlast;
            assign to_rx_p[g_if].tid     = from_tx_p.tid;
            assign to_rx_p[g_if].tdest   = from_tx_p.tdest;
            assign to_rx_p[g_if].tuser   = from_tx_p.tuser;

            axi4s_intf_pipe out_pipe (.from_tx(to_rx_p[g_if]), .to_rx(to_rx[g_if]));
        end

    endgenerate

endmodule


// AXI-Stream interface 1:2 demux
module axi4s_intf_1to2_demux (
    axi4s_intf.rx       from_tx,
    axi4s_intf.tx       to_rx_0,
    axi4s_intf.tx       to_rx_1,
    input logic         output_sel
);

    axi4s_intf_parameter_check param_check_0 (.from_tx, .to_rx(to_rx_0));
    axi4s_intf_parameter_check param_check_1 (.from_tx, .to_rx(to_rx_1));

    // axis4s input interface signalling.
    assign from_tx.tready = output_sel ? to_rx_1.tready : to_rx_0.tready;

    // axis4s output interface signalling.
    assign to_rx_0.tvalid = from_tx.tvalid && !output_sel;
    assign to_rx_0.tdata  = from_tx.tdata;
    assign to_rx_0.tkeep  = from_tx.tkeep;
    assign to_rx_0.tlast  = from_tx.tlast;
    assign to_rx_0.tid    = from_tx.tid;
    assign to_rx_0.tdest  = from_tx.tdest;
    assign to_rx_0.tuser  = from_tx.tuser;

    assign to_rx_1.tvalid = from_tx.tvalid && output_sel;
    assign to_rx_1.tdata  = from_tx.tdata;
    assign to_rx_1.tkeep  = from_tx.tkeep;
    assign to_rx_1.tlast  = from_tx.tlast;
    assign to_rx_1.tid    = from_tx.tid;
    assign to_rx_1.tdest  = from_tx.tdest;
    assign to_rx_1.tuser  = from_tx.tuser;

endmodule


// AXI-Stream interface bypass mux
module axi4s_intf_bypass_mux #(
    parameter int PIPE_STAGES = 1
) (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_block,
    axi4s_intf.rx from_block,
    axi4s_intf.tx to_rx,
    input logic   bypass
);
    axi4s_intf_parameter_check param_check_port          (.*);
    axi4s_intf_parameter_check param_check_block         (.from_tx(from_block), .to_rx(to_block));
    axi4s_intf_parameter_check param_check_port_to_block (.from_tx, .to_rx(to_block));

    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TID_WID       = from_tx.TID_WID;
    localparam int TDEST_WID     = from_tx.TDEST_WID;
    localparam int TUSER_WID     = from_tx.TUSER_WID;

    // interface instantiations
    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID) )
                __from_tx (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));

    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID) )
                from_pipe (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));

    // __from_tx assignments
    assign __from_tx.tvalid  = bypass ? from_tx.tvalid  : 1'b0;
    assign __from_tx.tlast   = from_tx.tlast;
    assign __from_tx.tkeep   = from_tx.tkeep;
    assign __from_tx.tdata   = from_tx.tdata;
    assign __from_tx.tid     = from_tx.tid;
    assign __from_tx.tdest   = from_tx.tdest;
    assign __from_tx.tuser   = from_tx.tuser;

    // from_tx assignments
    assign to_block.tvalid  = bypass ? 1'b0 : from_tx.tvalid;
    assign to_block.tlast   = from_tx.tlast;
    assign to_block.tkeep   = from_tx.tkeep;
    assign to_block.tdata   = from_tx.tdata;
    assign to_block.tid     = from_tx.tid;
    assign to_block.tdest   = from_tx.tdest;
    assign to_block.tuser   = from_tx.tuser;

    // from_tx tready assignment
    assign from_tx.tready = bypass ? __from_tx.tready : to_block.tready;

    // pipeline instantation
    generate
       if (PIPE_STAGES > 0) begin : g__bypass_pipe
          axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID) )
                          axi4s_bypass_pipe [PIPE_STAGES] (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));

          axi4s_intf_pipe axi4s_intf_pipe_0
                (.from_tx(__from_tx), .to_rx(axi4s_bypass_pipe[0]));

          for (genvar i = 1; i < PIPE_STAGES; i++)
             axi4s_intf_pipe axi4s_intf_pipe
                (.from_tx(axi4s_bypass_pipe[i-1]), .to_rx(axi4s_bypass_pipe[i]));

          axi4s_intf_connector axi4s_intf_connector_out
                (.from_tx(axi4s_bypass_pipe[PIPE_STAGES-1]), .to_rx(from_pipe));

       end : g__bypass_pipe

       else if (PIPE_STAGES == 0) begin : g__no_bypass_pipe
          axi4s_intf_connector axi4s_intf_connector_out (.from_tx(__from_tx), .to_rx(from_pipe));

       end : g__no_bypass_pipe
    endgenerate

    // output mux instantation
    axi4s_intf_2to1_mux axi4s_intf_2to1_mux_0 (
       .from_tx_0(from_block), .from_tx_1(from_pipe), .to_rx, .mux_sel(bypass)
    );

endmodule


// axi4s advance tlast module (used to eliminate all-zeros tlast transactions that result from packet joining).
module axi4s_adv_tlast (
    axi4s_intf.rx from_tx,
    axi4s_intf.tx to_rx
);
    import axi4s_pkg::*;

    axi4s_intf_parameter_check param_check_port (.*);

    localparam int DATA_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int TID_WID       = from_tx.TID_WID;
    localparam int TDEST_WID     = from_tx.TDEST_WID;
    localparam int TUSER_WID     = from_tx.TUSER_WID;

    axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_WID(TID_WID), .TDEST_WID(TDEST_WID), .TUSER_WID(TUSER_WID))
                from_tx_p (.aclk(from_tx.aclk), .aresetn(from_tx.aresetn));

    axi4s_intf_pipe axi4s_intf_pipe_0 (.from_tx(from_tx), .to_rx(from_tx_p));

    logic  adv_tlast;
    assign adv_tlast = from_tx.tready && from_tx.tvalid && from_tx.tlast &&
                       from_tx.tkeep == '0;

    logic skip;
    always @(posedge from_tx.aclk) begin
        if (!from_tx.aresetn) skip <= 0;
        else if (skip == 0) skip <= adv_tlast;
        else if (from_tx_p.tready && from_tx_p.tvalid) skip <= 0;  // skip == 1
    end

    // Connect output signals (pipe -> if_to_rx)
    assign to_rx.tvalid  = from_tx_p.tvalid && !skip;
    assign to_rx.tdata   = from_tx_p.tdata;
    assign to_rx.tkeep   = from_tx_p.tkeep;
    assign to_rx.tlast   = from_tx_p.tlast || adv_tlast;
    assign to_rx.tid     = from_tx_p.tid;
    assign to_rx.tdest   = from_tx_p.tdest;
    assign to_rx.tuser   = from_tx_p.tuser;

    assign from_tx_p.tready  = to_rx.tready;

endmodule : axi4s_adv_tlast


// group flattened AXI-S signals (from tx) into interface (to rx)
module axi4s_intf_from_signals
    import axi4s_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int TID_WID   = 1,
    parameter int TDEST_WID = 1,
    parameter int TUSER_WID = 1,
    parameter axi4s_mode_t MODE = STANDARD
) (
    // Signals (from tx)
    input  logic                          tvalid,
    output logic                          tready,
    input  logic [DATA_BYTE_WID-1:0][7:0] tdata,
    input  logic [DATA_BYTE_WID-1:0]      tkeep,
    input  logic                          tlast,
    input  logic [TID_WID-1:0]            tid,
    input  logic [TDEST_WID-1:0]          tdest,
    input  logic [TUSER_WID-1:0]          tuser,
    // Interface (to rx)
    axi4s_intf.tx axi4s_if
);
    // Parameter checking
    initial begin
        std_pkg::param_check(DATA_BYTE_WID, axi4s_if.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(TID_WID, axi4s_if.TID_WID, "TID_WID");
        std_pkg::param_check(TDEST_WID, axi4s_if.TDEST_WID, "TDEST_WID");
        std_pkg::param_check(TUSER_WID, axi4s_if.TUSER_WID, "TUSER_WID");
    end

    // Connect signals to interface (tx -> rx)
    assign axi4s_if.tvalid = tvalid;
    assign axi4s_if.tdata = tdata;
    assign axi4s_if.tkeep = tkeep;
    assign axi4s_if.tlast = tlast;
    assign axi4s_if.tid   = tid;
    assign axi4s_if.tdest = tdest;
    assign axi4s_if.tuser = tuser;

    // Connect interface to signals (rx -> tx)
    assign tready = (MODE == IGNORES_TREADY) ? 1'b1 : axi4s_if.tready;
endmodule : axi4s_intf_from_signals


// expand interface (from tx) into flattened AXI-S signals (to rx)
module axi4s_intf_to_signals
    import axi4s_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int TID_WID = 1,
    parameter int TDEST_WID = 1,
    parameter int TUSER_WID = 1,
    parameter axi4s_mode_t MODE = STANDARD
) (
    // Signals (to rx)
    output logic                          tvalid,
    input  logic                          tready,
    output logic [DATA_BYTE_WID-1:0][7:0] tdata,
    output logic [DATA_BYTE_WID-1:0]      tkeep,
    output logic                          tlast,
    output logic [TID_WID-1:0]            tid,
    output logic [TDEST_WID-1:0]          tdest,
    output logic [TUSER_WID-1:0]          tuser,
    // Interface (from tx)
    axi4s_intf.rx axi4s_if
);
    // Parameter checking
    initial begin
        std_pkg::param_check(DATA_BYTE_WID, axi4s_if.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(TID_WID, axi4s_if.TID_WID, "TID_WID");
        std_pkg::param_check(TDEST_WID, axi4s_if.TDEST_WID, "TDEST_WID");
        std_pkg::param_check(TUSER_WID, axi4s_if.TUSER_WID, "TUSER_WID");
    end

    // Connect interface to signals (tx -> rx)
    assign axi4s_if.tready = (MODE == IGNORES_TREADY) ? 1'b1 : tready;

    // Connect signals to interface (tx -> rx)
    assign tvalid  = axi4s_if.tvalid;
    assign tdata   = axi4s_if.tdata;
    assign tkeep   = axi4s_if.tkeep;
    assign tlast   = axi4s_if.tlast;
    assign tid     = axi4s_if.tid;
    assign tdest   = axi4s_if.tdest;
    assign tuser   = axi4s_if.tuser;
endmodule : axi4s_intf_to_signals
