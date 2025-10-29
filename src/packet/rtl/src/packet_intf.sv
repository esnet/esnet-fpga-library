interface packet_intf #(
    parameter int DATA_BYTE_WID = 1,
    parameter int META_WID = 1
) (
    input logic clk,
    input logic srst = 1'b0
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

    logic  sop;

    // Modports
    modport tx(
        input  clk,
        input  srst,
        output vld,
        input  rdy,
        output data,
        input  sop,
        output eop,
        output mty,
        output err,
        output meta
    );

    modport rx(
        input  clk,
        input  srst,
        input  vld,
        output rdy,
        input  data,
        input  sop,
        input  eop,
        input  mty,
        input  err,
        input  meta
    );

    // Track SOP
    initial sop = 1'b1;
    always @(posedge clk) begin
        if (srst) sop <= 1'b1;
        else begin
            if (vld && rdy && eop) sop <= 1'b1;
            else if (vld && rdy)   sop <= 1'b0;
        end
    end

    clocking cb_tx @(posedge clk);
        output vld, data, eop, mty, err, meta;
        input rdy;
    endclocking

    clocking cb_rx @(posedge clk);
        input vld, data, eop, mty, err, meta;
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
        @(cb_tx);
        wait(cb_tx.rdy);
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
        @(cb_rx);
        wait(cb_rx.vld);
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
