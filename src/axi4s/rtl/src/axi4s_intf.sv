interface axi4s_intf
    import axi4s_pkg::*;
#(
    parameter axi4s_mode_t MODE = STANDARD,
    parameter axi4s_tuser_mode_t TUSER_MODE = USER,
    parameter int  DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
);
    // Signals
    logic                          aclk;
    logic                          aresetn;

    logic                          tvalid;
    logic                          tready;
    logic [DATA_BYTE_WID-1:0][7:0] tdata;
    logic [DATA_BYTE_WID-1:0]      tkeep;
    logic                          tlast;
    TID_T                          tid;
    TDEST_T                        tdest;
    TUSER_T                        tuser;

    // Status
    logic                          sop;

    // Modports
    modport tx (
        output aclk,
        output aresetn,
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

    modport tx_async (
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

    modport rx_async (
        output aclk,
        output aresetn,
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
            input TID_T                        _tid=0,
            input TDEST_T                      _tdest=0,
            input TUSER_T                      _tuser=0,
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
            output TID_T                        _tid,
            output TDEST_T                      _tdest,
            output TUSER_T                      _tuser,
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
            output TID_T _tid,
            output TDEST_T _tdest,
            output TUSER_T _tuser
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

// AXI4-Stream transmit termination helper module
module axi4s_intf_tx_term (
    input logic aclk = 1'b0,
    input logic aresetn = 1'b0,
    axi4s_intf.tx axi4s_if
);
    // Tie off transmit outputs
    assign axi4s_if.aclk = aclk;
    assign axi4s_if.aresetn = aresetn;
    assign axi4s_if.tvalid = 1'b0;
    assign axi4s_if.tdata = '0;
    assign axi4s_if.tkeep = '0;
    assign axi4s_if.tlast = 1'b0;
    assign axi4s_if.tid = '0;
    assign axi4s_if.tdest = '0;
    assign axi4s_if.tuser = '0;

endmodule : axi4s_intf_tx_term


// AXI4-Stream (blocking) receive termination helper module
module axi4s_intf_rx_block (
    axi4s_intf.rx axi4s_if
);
    // Tie off receive outputs
    assign axi4s_if.tready = 1'b0;

endmodule : axi4s_intf_rx_block


// AXI4-Stream (sink) receive termination helper module
module axi4s_intf_rx_sink (
    axi4s_intf.rx axi4s_if
);
    // Tie off receive outputs
    assign axi4s_if.tready = 1'b1;

endmodule : axi4s_intf_rx_sink


// AXI4-Stream (back-to-back) connector helper module
module axi4s_intf_connector (
    axi4s_intf.rx axi4s_from_tx,
    axi4s_intf.tx axi4s_to_rx
);
    import axi4s_pkg::*;

    // Connect signals (rx -> tx)
    assign axi4s_to_rx.aclk    = axi4s_from_tx.aclk;
    assign axi4s_to_rx.aresetn = axi4s_from_tx.aresetn;
    assign axi4s_to_rx.tvalid  = axi4s_from_tx.tvalid;
    assign axi4s_to_rx.tdata   = axi4s_from_tx.tdata;
    assign axi4s_to_rx.tkeep   = axi4s_from_tx.tkeep;
    assign axi4s_to_rx.tlast   = axi4s_from_tx.tlast;
    assign axi4s_to_rx.tid     = axi4s_from_tx.tid;
    assign axi4s_to_rx.tdest   = axi4s_from_tx.tdest;
    assign axi4s_to_rx.tuser   = axi4s_from_tx.tuser;

    // Connect signals (tx -> rx)
    assign axi4s_from_tx.tready = (axi4s_from_tx.MODE == IGNORES_TREADY) ? 1'b1 : axi4s_to_rx.tready;
endmodule : axi4s_intf_connector


// AXI4-Stream set TID helper module
module axi4s_intf_set_meta #(
    parameter type TID_T = logic,
    parameter type TDEST_T = logic,
    parameter type TUSER_T = logic
) (
    axi4s_intf.rx axi4s_from_tx,
    axi4s_intf.tx axi4s_to_rx,
    input TID_T tid = '0,
    input TDEST_T tdest = '0,
    input TUSER_T tuser = '0
);
    // Connect signals (rx -> tx)
    assign axi4s_to_rx.aclk    = axi4s_from_tx.aclk;
    assign axi4s_to_rx.aresetn = axi4s_from_tx.aresetn;
    assign axi4s_to_rx.tvalid  = axi4s_from_tx.tvalid;
    assign axi4s_to_rx.tdata   = axi4s_from_tx.tdata;
    assign axi4s_to_rx.tkeep   = axi4s_from_tx.tkeep;
    assign axi4s_to_rx.tlast   = axi4s_from_tx.tlast;
    assign axi4s_to_rx.tid     = tid;
    assign axi4s_to_rx.tdest   = tdest;
    assign axi4s_to_rx.tuser   = tuser;

    // Connect signals (tx -> rx)
    assign axi4s_from_tx.tready = axi4s_to_rx.tready;

endmodule

// AXI4-Stream monitor helper module
module axi4s_intf_monitor (
    axi4s_intf.rx  axi4s_from_tx,
    axi4s_intf.prb axi4s_to_prb
);
    import axi4s_pkg::*;

    // Connect signals (rx -> tx)
    assign axi4s_to_prb.aclk    = axi4s_from_tx.aclk;
    assign axi4s_to_prb.aresetn = axi4s_from_tx.aresetn;
    assign axi4s_to_prb.tvalid  = axi4s_from_tx.tvalid;
    assign axi4s_to_prb.tdata   = axi4s_from_tx.tdata;
    assign axi4s_to_prb.tkeep   = axi4s_from_tx.tkeep;
    assign axi4s_to_prb.tlast   = axi4s_from_tx.tlast;
    assign axi4s_to_prb.tid     = axi4s_from_tx.tid;
    assign axi4s_to_prb.tdest   = axi4s_from_tx.tdest;
    assign axi4s_to_prb.tuser   = axi4s_from_tx.tuser;
    assign axi4s_to_prb.tready  = axi4s_from_tx.tready;

endmodule : axi4s_intf_monitor


// AXI4-Stream pipeline helper module
module axi4s_intf_pipe
    import axi4s_pkg::*;
#(
    parameter axi4s_pipe_mode_t MODE = PULL
) (
    axi4s_intf.rx axi4s_if_from_tx,
    axi4s_intf.tx axi4s_if_to_rx
);
    logic ready;

    // ACLK
    assign axi4s_if_to_rx.aclk = axi4s_if_from_tx.aclk;

    // ARESETN
    initial axi4s_if_to_rx.aresetn = 1'b0;
    always @(posedge axi4s_if_from_tx.aclk) axi4s_if_to_rx.aresetn <= axi4s_if_from_tx.aresetn;

    // TVALID buffer
    initial axi4s_if_to_rx.tvalid = 1'b0;
    always @(posedge axi4s_if_from_tx.aclk) begin
        if (!axi4s_if_from_tx.aresetn)                               axi4s_if_to_rx.tvalid <= 1'b0;
        else if (axi4s_if_from_tx.tvalid && axi4s_if_from_tx.tready) axi4s_if_to_rx.tvalid <= 1'b1;
        else if (axi4s_if_to_rx.tready)                              axi4s_if_to_rx.tvalid <= 1'b0;
    end

    // TREADY
    initial ready = 1'b1;
    always @(posedge axi4s_if_from_tx.aclk) begin
        if (!axi4s_if_from_tx.aresetn)    ready <= 1'b1;
        else if (axi4s_if_from_tx.tvalid) ready <= 1'b0;
        else if (axi4s_if_to_rx.tready)   ready <= 1'b1;
    end
    assign axi4s_if_from_tx.tready = (MODE == PUSH) ? axi4s_if_to_rx.tready : (ready || axi4s_if_to_rx.tready);

    // Data
    always_ff @(posedge axi4s_if_from_tx.aclk) begin
        if (axi4s_if_from_tx.tready) begin
            axi4s_if_to_rx.tdata <= axi4s_if_from_tx.tdata;
            axi4s_if_to_rx.tkeep <= axi4s_if_from_tx.tkeep;
            axi4s_if_to_rx.tlast <= axi4s_if_from_tx.tlast;
            axi4s_if_to_rx.tid   <= axi4s_if_from_tx.tid;
            axi4s_if_to_rx.tdest <= axi4s_if_from_tx.tdest;
            axi4s_if_to_rx.tuser <= axi4s_if_from_tx.tuser;
        end
    end

endmodule : axi4s_intf_pipe


// axi4-stream tready pipeline helper module
module axi4s_tready_pipe (
    axi4s_intf.rx axi4s_if_from_tx,
    axi4s_intf.tx axi4s_if_to_rx
);
    import axi4s_pkg::*;

    localparam int  DATA_BYTE_WID = axi4s_if_from_tx.DATA_BYTE_WID;
    localparam type TID_T         = axi4s_if_from_tx.TID_T;
    localparam type TDEST_T       = axi4s_if_from_tx.TDEST_T;
    localparam type TUSER_T       = axi4s_if_from_tx.TUSER_T;

    logic  tready_falling;
    logic  fwft;
    logic  sample_enable;

    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) )
                axi4s_if_from_tx_p ();

    // aclk.
    assign axi4s_if_to_rx.aclk = axi4s_if_from_tx.aclk;

    // aresetn.
    initial axi4s_if_to_rx.aresetn = 1'b0;
    always @(posedge axi4s_if_from_tx.aclk) axi4s_if_to_rx.aresetn <= axi4s_if_from_tx.aresetn;

    logic axi4s_if_to_rx_tready_p = 0;
    always @(posedge axi4s_if_from_tx.aclk) begin
        if (!axi4s_if_from_tx.aresetn)  axi4s_if_to_rx_tready_p <= 1'b0;
        else                            axi4s_if_to_rx_tready_p <= axi4s_if_to_rx.tready;
    end

    assign fwft = axi4s_if_from_tx.tvalid && !axi4s_if_from_tx_p.tvalid && !axi4s_if_to_rx_tready_p;

    assign tready_falling = axi4s_if_to_rx_tready_p && !axi4s_if_to_rx.tready;

    // sample data flops if rx is deasserting tready, or if sample flops can receive next valid word (first-word-fall-through).
    assign sample_enable  = tready_falling || (fwft && !axi4s_if_to_rx.tready);


    // assert tready if rx is ready, or if sample flops can receive next valid word (first-word-fall-through).
    assign axi4s_if_from_tx.tready = axi4s_if_to_rx_tready_p || fwft;

    assign axi4s_if_from_tx_p.aclk    = axi4s_if_from_tx.aclk;
    assign axi4s_if_from_tx_p.aresetn = axi4s_if_from_tx.aresetn;

    // sample data flops, and deassert tvalid when flopped data is transferred.
    always_ff @(posedge axi4s_if_from_tx.aclk) begin
        if (!axi4s_if_from_tx.aresetn)                               axi4s_if_from_tx_p.tvalid <= '0;
        else if (axi4s_if_to_rx.tready && axi4s_if_from_tx_p.tvalid) axi4s_if_from_tx_p.tvalid <= '0;
        else if (sample_enable)                                      axi4s_if_from_tx_p.tvalid <= axi4s_if_from_tx.tvalid;

        if (!axi4s_if_from_tx_p.tvalid) begin
            axi4s_if_from_tx_p.tdata  <= axi4s_if_from_tx.tdata;
            axi4s_if_from_tx_p.tkeep  <= axi4s_if_from_tx.tkeep;
            axi4s_if_from_tx_p.tlast  <= axi4s_if_from_tx.tlast;
            axi4s_if_from_tx_p.tid    <= axi4s_if_from_tx.tid;
            axi4s_if_from_tx_p.tdest  <= axi4s_if_from_tx.tdest;
            axi4s_if_from_tx_p.tuser  <= axi4s_if_from_tx.tuser;
        end
    end

    // output mux logic.
    always_comb begin
       // select sample flops when a valid sample is captured.
       if (axi4s_if_from_tx_p.tvalid) begin
            axi4s_if_to_rx.tvalid = axi4s_if_from_tx_p.tvalid;
            axi4s_if_to_rx.tdata  = axi4s_if_from_tx_p.tdata;
            axi4s_if_to_rx.tkeep  = axi4s_if_from_tx_p.tkeep;
            axi4s_if_to_rx.tlast  = axi4s_if_from_tx_p.tlast;
            axi4s_if_to_rx.tid    = axi4s_if_from_tx_p.tid;
            axi4s_if_to_rx.tdest  = axi4s_if_from_tx_p.tdest;
            axi4s_if_to_rx.tuser  = axi4s_if_from_tx_p.tuser;
       // otherwise select input data.
       end else begin
            axi4s_if_to_rx.tvalid = axi4s_if_from_tx.tvalid;
            axi4s_if_to_rx.tdata  = axi4s_if_from_tx.tdata;
            axi4s_if_to_rx.tkeep  = axi4s_if_from_tx.tkeep;
            axi4s_if_to_rx.tlast  = axi4s_if_from_tx.tlast;
            axi4s_if_to_rx.tid    = axi4s_if_from_tx.tid;
            axi4s_if_to_rx.tdest  = axi4s_if_from_tx.tdest;
            axi4s_if_to_rx.tuser  = axi4s_if_from_tx.tuser;
       end
    end

endmodule : axi4s_tready_pipe


// axi4-stream full (bidirectional) pipeline helper module
module axi4s_full_pipe
    import axi4s_pkg::*;
#(
    parameter axi4s_pipe_mode_t MODE = PULL
) (
    axi4s_intf.rx axi4s_if_from_tx,
    axi4s_intf.tx axi4s_if_to_rx
);
    import axi4s_pkg::*;

    localparam int  DATA_BYTE_WID = axi4s_if_from_tx.DATA_BYTE_WID;
    localparam type TID_T         = axi4s_if_from_tx.TID_T;
    localparam type TDEST_T       = axi4s_if_from_tx.TDEST_T;
    localparam type TUSER_T       = axi4s_if_from_tx.TUSER_T;

    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) )
                axi4s_if_from_tx_p ();

    axi4s_intf_pipe #(.MODE(MODE))  axi4s_intf_pipe_0   (.axi4s_if_from_tx(axi4s_if_from_tx),   .axi4s_if_to_rx(axi4s_if_from_tx_p));

    axi4s_tready_pipe axi4s_tready_pipe_0 (.axi4s_if_from_tx(axi4s_if_from_tx_p), .axi4s_if_to_rx(axi4s_if_to_rx));

endmodule : axi4s_full_pipe


// AXI-Stream interface N:1 mux
module axi4s_intf_mux
#(
    parameter int  N = 2,  // number of ingress axi4s interfaces.
    parameter int  DATA_BYTE_WID = 8,
    parameter type TID_T         = bit,
    parameter type TDEST_T       = bit,
    parameter type TUSER_T       = bit
) (
    axi4s_intf.rx                axi4s_in_if[N],
    axi4s_intf.tx                axi4s_out_if,
    input logic [$clog2(N)-1:0]  sel
);

    logic                          aresetn[N];
    logic                          tvalid[N];
    logic [DATA_BYTE_WID-1:0][7:0] tdata[N];
    logic [DATA_BYTE_WID-1:0]      tkeep[N];
    logic                          tlast[N];
    TID_T                          tid[N];
    TDEST_T                        tdest[N];
    TUSER_T                        tuser[N];

    logic                          tready[N];

    // Convert between array of signals and array of interfaces
    generate
        for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
            assign aresetn[g_if] = axi4s_in_if[g_if].aresetn;
            assign  tvalid[g_if] = axi4s_in_if[g_if].tvalid;
            assign   tdata[g_if] = axi4s_in_if[g_if].tdata;
            assign   tkeep[g_if] = axi4s_in_if[g_if].tkeep;
            assign   tlast[g_if] = axi4s_in_if[g_if].tlast;
            assign     tid[g_if] = axi4s_in_if[g_if].tid;
            assign   tdest[g_if] = axi4s_in_if[g_if].tdest;
            assign   tuser[g_if] = axi4s_in_if[g_if].tuser;

            assign axi4s_in_if[g_if].tready = (sel == g_if) ? axi4s_out_if.tready : 1'b0;
        end
    endgenerate

    always_comb begin
        // all interfaces must be synchronous to axi4s_in_if[0].
        axi4s_out_if.aclk    = axi4s_in_if[0].aclk;

        // mux logic
        axi4s_out_if.aresetn = aresetn [sel];
        axi4s_out_if.tvalid  = tvalid  [sel];
        axi4s_out_if.tlast   = tlast   [sel];
        axi4s_out_if.tkeep   = tkeep   [sel];
        axi4s_out_if.tdata   = tdata   [sel];
        axi4s_out_if.tid     = tid     [sel];
        axi4s_out_if.tdest   = tdest   [sel];
        axi4s_out_if.tuser   = tuser   [sel];
    end

endmodule


// AXI-Stream interface 2:1 mux
module axi4s_intf_2to1_mux (
    axi4s_intf.rx axi4s_in_if_0,
    axi4s_intf.rx axi4s_in_if_1,
    axi4s_intf.tx axi4s_out_if,
    input logic   mux_sel
);
    // All interfaces must be synchronous
    assign axi4s_out_if.aclk    = axi4s_in_if_0.aclk;
    assign axi4s_out_if.aresetn = mux_sel ? axi4s_in_if_1.aresetn : axi4s_in_if_0.aresetn;

    // Mux
    assign axi4s_out_if.tvalid = mux_sel ? axi4s_in_if_1.tvalid : axi4s_in_if_0.tvalid;
    assign axi4s_out_if.tlast  = mux_sel ? axi4s_in_if_1.tlast  : axi4s_in_if_0.tlast;
    assign axi4s_out_if.tkeep  = mux_sel ? axi4s_in_if_1.tkeep  : axi4s_in_if_0.tkeep;
    assign axi4s_out_if.tdata  = mux_sel ? axi4s_in_if_1.tdata  : axi4s_in_if_0.tdata;
    assign axi4s_out_if.tid    = mux_sel ? axi4s_in_if_1.tid    : axi4s_in_if_0.tid;
    assign axi4s_out_if.tdest  = mux_sel ? axi4s_in_if_1.tdest  : axi4s_in_if_0.tdest;
    assign axi4s_out_if.tuser  = mux_sel ? axi4s_in_if_1.tuser  : axi4s_in_if_0.tuser;

    // Demux TREADY
    assign axi4s_in_if_0.tready = mux_sel ? 1'b0 : axi4s_out_if.tready;
    assign axi4s_in_if_1.tready = mux_sel ? axi4s_out_if.tready : 1'b0;

endmodule


// AXI-Stream interface 1:N demux
module axi4s_intf_demux
#(
    parameter int N = 2  // number of egress axi4s interfaces.
) (
    axi4s_intf.rx  axi4s_in,
    axi4s_intf.tx  axi4s_out[N],

    input logic [$clog2(N)-1:0]  sel
);

    localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
    localparam type TID_T         = axi4s_in.TID_T;
    localparam type TDEST_T       = axi4s_in.TDEST_T;
    localparam type TUSER_T       = axi4s_in.TUSER_T;

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_in_p ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_out_p[N] ();

    logic tready[N];

    axi4s_intf_connector axi4s_intf_connector_in (.axi4s_from_tx(axi4s_in), .axi4s_to_rx(axi4s_in_p));

    // axis4s input interface signalling.
    assign axi4s_in_p.tready = tready[sel];

    generate
        for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
            assign tready[g_if] = axi4s_out_p[g_if].tready;

            // axis4s output interface signalling.
            assign axi4s_out_p[g_if].aclk    = axi4s_in_p.aclk;
            assign axi4s_out_p[g_if].aresetn = axi4s_in_p.aresetn;
            assign axi4s_out_p[g_if].tvalid  = (sel == g_if) ? axi4s_in_p.tvalid : 1'b0;
            assign axi4s_out_p[g_if].tdata   = axi4s_in_p.tdata;
            assign axi4s_out_p[g_if].tkeep   = axi4s_in_p.tkeep;
            assign axi4s_out_p[g_if].tlast   = axi4s_in_p.tlast;
            assign axi4s_out_p[g_if].tid     = axi4s_in_p.tid;
            assign axi4s_out_p[g_if].tdest   = axi4s_in_p.tdest;
            assign axi4s_out_p[g_if].tuser   = axi4s_in_p.tuser;

            axi4s_intf_pipe out_pipe (.axi4s_if_from_tx(axi4s_out_p[g_if]), .axi4s_if_to_rx(axi4s_out[g_if]));
        end

    endgenerate

endmodule


// AXI-Stream interface 1:2 demux
module axi4s_intf_1to2_demux (
    axi4s_intf.rx       axi4s_in,
    axi4s_intf.tx       axi4s_out0,
    axi4s_intf.tx       axi4s_out1,
    input logic         output_sel
);

    // axis4s input interface signalling.
    assign axi4s_in.tready = output_sel ? axi4s_out1.tready : axi4s_out0.tready;

    // axis4s output interface signalling.
    assign axi4s_out0.aclk    = axi4s_in.aclk;
    assign axi4s_out0.aresetn = axi4s_in.aresetn;
    assign axi4s_out0.tvalid  = axi4s_in.tvalid && !output_sel;
    assign axi4s_out0.tdata   = axi4s_in.tdata;
    assign axi4s_out0.tkeep   = axi4s_in.tkeep;
    assign axi4s_out0.tlast   = axi4s_in.tlast;
    assign axi4s_out0.tid     = axi4s_in.tid;
    assign axi4s_out0.tdest   = axi4s_in.tdest;
    assign axi4s_out0.tuser   = axi4s_in.tuser;

    assign axi4s_out1.aclk    = axi4s_in.aclk;
    assign axi4s_out1.aresetn = axi4s_in.aresetn;
    assign axi4s_out1.tvalid  = axi4s_in.tvalid && output_sel;
    assign axi4s_out1.tdata   = axi4s_in.tdata;
    assign axi4s_out1.tkeep   = axi4s_in.tkeep;
    assign axi4s_out1.tlast   = axi4s_in.tlast;
    assign axi4s_out1.tid     = axi4s_in.tid;
    assign axi4s_out1.tdest   = axi4s_in.tdest;
    assign axi4s_out1.tuser   = axi4s_in.tuser;

endmodule


// AXI-Stream interface bypass mux
module axi4s_intf_bypass_mux #(
    parameter int   PIPE_STAGES = 1,
    parameter int   DATA_BYTE_WID = 8,
    parameter type  TID_T = bit,
    parameter type  TDEST_T = bit,
    parameter type  TUSER_T = bit
) (
    axi4s_intf.rx axi4s_in,
    axi4s_intf.tx axi4s_to_block,
    axi4s_intf.rx axi4s_from_block,
    axi4s_intf.tx axi4s_out,
    input logic   bypass
);

    // interface instantiations
    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) )
                __axi4s_in ();

    axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) )
                axi4s_from_pipe ();

    // __axi4s_in assignments
    assign __axi4s_in.aclk    = axi4s_in.aclk;
    assign __axi4s_in.aresetn = axi4s_in.aresetn;
    assign __axi4s_in.tvalid  = bypass ? axi4s_in.tvalid  : 1'b0;
    assign __axi4s_in.tlast   = axi4s_in.tlast;
    assign __axi4s_in.tkeep   = axi4s_in.tkeep;
    assign __axi4s_in.tdata   = axi4s_in.tdata;
    assign __axi4s_in.tid     = axi4s_in.tid;
    assign __axi4s_in.tdest   = axi4s_in.tdest;
    assign __axi4s_in.tuser   = axi4s_in.tuser;

    // axi4s_to_block assignments
    assign axi4s_to_block.aclk    = axi4s_in.aclk;
    assign axi4s_to_block.aresetn = axi4s_in.aresetn;
    assign axi4s_to_block.tvalid  = bypass ? 1'b0 : axi4s_in.tvalid;
    assign axi4s_to_block.tlast   = axi4s_in.tlast;
    assign axi4s_to_block.tkeep   = axi4s_in.tkeep;
    assign axi4s_to_block.tdata   = axi4s_in.tdata;
    assign axi4s_to_block.tid     = axi4s_in.tid;
    assign axi4s_to_block.tdest   = axi4s_in.tdest;
    assign axi4s_to_block.tuser   = axi4s_in.tuser;

    // axi4s_in tready assignment
    assign axi4s_in.tready = bypass ? __axi4s_in.tready : axi4s_to_block.tready;

    // pipeline instantation
    generate
       if (PIPE_STAGES > 0) begin : g__bypass_pipe
          axi4s_intf  #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T) )
                          axi4s_bypass_pipe [PIPE_STAGES] ();

          axi4s_intf_pipe axi4s_intf_pipe_0
                (.axi4s_if_from_tx(__axi4s_in), .axi4s_if_to_rx(axi4s_bypass_pipe[0]));

          for (genvar i = 1; i < PIPE_STAGES; i++)
             axi4s_intf_pipe axi4s_intf_pipe
                (.axi4s_if_from_tx(axi4s_bypass_pipe[i-1]), .axi4s_if_to_rx(axi4s_bypass_pipe[i]));

          axi4s_intf_connector axi4s_intf_connector_out
                (.axi4s_from_tx(axi4s_bypass_pipe[PIPE_STAGES-1]), .axi4s_to_rx(axi4s_from_pipe));

       end : g__bypass_pipe

       else if (PIPE_STAGES == 0) begin : g__no_bypass_pipe
          axi4s_intf_connector axi4s_intf_connector_out (.axi4s_from_tx(__axi4s_in), .axi4s_to_rx(axi4s_from_pipe));

       end : g__no_bypass_pipe
    endgenerate

    // output mux instantation
    axi4s_intf_2to1_mux axi4s_intf_2to1_mux_0 (
       .axi4s_in_if_0(axi4s_from_block), .axi4s_in_if_1(axi4s_from_pipe), .axi4s_out_if(axi4s_out), .mux_sel(bypass)
    );

endmodule


// axi4s advance tlast module (used to eliminate all-zeros tlast transactions that result from packet joining).
module axi4s_adv_tlast (
    axi4s_intf.rx axi4s_if_from_tx,
    axi4s_intf.tx axi4s_if_to_rx
);
    import axi4s_pkg::*;

    localparam int  DATA_BYTE_WID = axi4s_if_from_tx.DATA_BYTE_WID;
    localparam type TID_T         = axi4s_if_from_tx.TID_T;
    localparam type TDEST_T       = axi4s_if_from_tx.TDEST_T;
    localparam type TUSER_T       = axi4s_if_from_tx.TUSER_T;

    axi4s_intf  #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T))
                axi4s_pipe ();

    axi4s_intf_pipe axi4s_intf_pipe_0 (.axi4s_if_from_tx(axi4s_if_from_tx), .axi4s_if_to_rx(axi4s_pipe));

    logic  adv_tlast;
    assign adv_tlast = axi4s_if_from_tx.tready && axi4s_if_from_tx.tvalid && axi4s_if_from_tx.tlast &&
                       axi4s_if_from_tx.tkeep == '0;

    logic skip;
    always @(posedge axi4s_if_from_tx.aclk) begin
        if (!axi4s_if_from_tx.aresetn) skip <= 0;
        else if (skip == 0) skip <= adv_tlast;
        else if (axi4s_pipe.tready && axi4s_pipe.tvalid) skip <= 0;  // skip == 1
    end

    // Connect output signals (pipe -> if_to_rx)
    assign axi4s_if_to_rx.aclk    = axi4s_pipe.aclk;
    assign axi4s_if_to_rx.aresetn = axi4s_pipe.aresetn;
    assign axi4s_if_to_rx.tvalid  = axi4s_pipe.tvalid && !skip;
    assign axi4s_if_to_rx.tdata   = axi4s_pipe.tdata;
    assign axi4s_if_to_rx.tkeep   = axi4s_pipe.tkeep;
    assign axi4s_if_to_rx.tlast   = axi4s_pipe.tlast || adv_tlast;
    assign axi4s_if_to_rx.tid     = axi4s_pipe.tid;
    assign axi4s_if_to_rx.tdest   = axi4s_pipe.tdest;
    assign axi4s_if_to_rx.tuser   = axi4s_pipe.tuser;

    assign axi4s_pipe.tready  = axi4s_if_to_rx.tready;

endmodule : axi4s_adv_tlast


// group flattened AXI-S signals (from tx) into interface (to rx)
module axi4s_intf_from_signals #(
    parameter int  DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) (
    // Signals (from tx)
    input  logic                          aclk,
    input  logic                          aresetn,
    input  logic                          tvalid,
    output logic                          tready,
    input  logic [DATA_BYTE_WID-1:0][7:0] tdata,
    input  logic [DATA_BYTE_WID-1:0]      tkeep,
    input  logic                          tlast,
    input  TID_T                          tid,
    input  TDEST_T                        tdest,
    input  TUSER_T                        tuser,
    // Interface (to rx)
    axi4s_intf.tx axi4s_if
);
    import axi4s_pkg::*;

    // Connect signals to interface (tx -> rx)
    assign axi4s_if.aclk = aclk;
    assign axi4s_if.aresetn = aresetn;
    assign axi4s_if.tvalid = tvalid;
    assign axi4s_if.tdata = tdata;
    assign axi4s_if.tkeep = tkeep;
    assign axi4s_if.tlast = tlast;
    assign axi4s_if.tid = tid;
    assign axi4s_if.tdest = tdest;
    assign axi4s_if.tuser = tuser;

    // Connect interface to signals (rx -> tx)
    assign tready = (axi4s_if.MODE == IGNORES_TREADY) ? 1'b1 : axi4s_if.tready;
endmodule : axi4s_intf_from_signals


// expand interface (from tx) into flattened AXI-S signals (to rx)
module axi4s_intf_to_signals #(
    parameter int  DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) (
    // Signals (to rx)
    output logic                          aclk,
    output logic                          aresetn,
    output logic                          tvalid,
    input  logic                          tready,
    output logic [DATA_BYTE_WID-1:0][7:0] tdata,
    output logic [DATA_BYTE_WID-1:0]      tkeep,
    output logic                          tlast,
    output TID_T                          tid,
    output TDEST_T                        tdest,
    output TUSER_T                        tuser,
    // Interface (from tx)
    axi4s_intf.rx axi4s_if
);
    import axi4s_pkg::*;

    // Connect interface to signals (tx -> rx)
    assign axi4s_if.tready = (axi4s_if.MODE == IGNORES_TREADY) ? 1'b1 : tready;

    // Connect signals to interface (tx -> rx)
    assign aclk    = axi4s_if.aclk;
    assign aresetn = axi4s_if.aresetn;
    assign tvalid  = axi4s_if.tvalid;
    assign tdata   = axi4s_if.tdata;
    assign tkeep   = axi4s_if.tkeep;
    assign tlast   = axi4s_if.tlast;
    assign tid     = axi4s_if.tid;
    assign tdest   = axi4s_if.tdest;
    assign tuser   = axi4s_if.tuser;
endmodule : axi4s_intf_to_signals
