interface packet_intf #(
    parameter int  DATA_BYTE_WID = 1,
    parameter type META_T = logic
) (
    input logic clk,
    input logic srst = 1'b0
);

    // Parameters
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);

    // Typedefs
    typedef logic [0:DATA_BYTE_WID-1][7:0] data_t;
    typedef logic [MTY_WID-1:0] mty_t;

    // Signals
    logic  valid;
    logic  rdy;
    data_t data;
    logic  eop;
    mty_t  mty;
    logic  err;
    META_T meta;

    logic  sop;

    // Modports
    modport tx(
        input  clk,
        input  srst,
        output valid,
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
        input  valid,
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
        else if (valid && rdy && eop) sop <= 1'b1;
        else if (valid && rdy) sop <= 1'b0;
    end

    clocking cb_tx @(posedge clk);
        default input #1step output #1step;
        output valid, data, eop, mty, err, meta;
        input rdy;
    endclocking

    clocking cb_rx @(posedge clk);
        default input #1step output #1step;
        input valid, data, eop, mty, err, meta;
        output rdy;
    endclocking

    task idle_tx();
        cb_tx.valid <= 1'b0;
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
            input data_t _data,
            input logic  _eop = 1'b0,
            input mty_t  _mty = '0,
            input logic  _err = 1'b0,
            input META_T _meta = '0
        );
        cb_tx.valid <= 1'b1;
        cb_tx.data <= _data;
        cb_tx.eop <= _eop;
        cb_tx.mty <= _mty;
        cb_tx.err <= _err;
        cb_tx.meta <= _meta;
        @(cb_tx);
        wait(cb_tx.rdy);
        cb_tx.valid <= 1'b0;
        cb_tx.eop <= 1'b0;
    endtask

    task receive(
            output data_t _data,
            output logic  _eop,
            output mty_t  _mty,
            output logic  _err,
            output META_T _meta
        );
        cb_rx.rdy <= 1'b1;
        @(cb_rx);
        wait(cb_rx.valid);
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
    // Parameters
    localparam int DATA_BYTE_WID = $bits(from_tx.DATA_BYTE_WID);
    localparam int DATA_WID = DATA_BYTE_WID * 8;
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    localparam int META_WID = $bits(from_tx.META_T);

    // Parameter checking
    initial begin
        std_pkg::param_check($bits(to_rx.DATA_BYTE_WID), DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check($bits(to_rx.META_T), META_WID, "to_rx.META_T");
    end

    // Signals
    logic                valid;
    logic                rdy;
    logic [DATA_WID-1:0] data;
    logic                eop;
    logic [MTY_WID-1:0]  mty;
    logic                err;
    logic [META_WID-1:0] meta;

    // Connect signals (tx -> rx)
    assign valid = from_tx.valid;
    assign data  = from_tx.data;
    assign eop   = from_tx.eop;
    assign mty   = from_tx.mty;
    assign err   = from_tx.err;
    assign meta  = from_tx.meta;

    assign to_rx.valid = valid;
    assign to_rx.data  = data;
    assign to_rx.eop   = eop;
    assign to_rx.mty   = mty;
    assign to_rx.err   = err;
    assign to_rx.meta  = meta;

    // Connect signals (rx -> tx)
    assign rdy = to_rx.rdy;

    assign from_tx.rdy = rdy;

endmodule : packet_intf_connector

// Packet transmitter termination
module packet_intf_tx_term (
    packet_intf.tx to_rx
);
    assign to_rx.valid = 1'b0;
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
    logic rdy;
    assign rdy = 1'b0;

    assign from_tx.rdy = rdy;
endmodule : packet_intf_rx_block

// Packet receiver termination (short circuit)
module packet_intf_rx_sink (
    packet_intf.rx from_tx
);
    logic rdy;
    assign rdy = 1'b1;

    assign from_tx.rdy = rdy;
endmodule : packet_intf_rx_sink
