interface packet_intf #(
    parameter int  DATA_BYTE_WID = 1,
    parameter type META_T = logic
) (
    input wire logic clk,
    input wire logic srst = 1'b0
);

    // Parameters
    localparam int MTY_WID = $clog2(DATA_BYTE_WID);
    
    // Typedefs
    typedef logic [0:DATA_BYTE_WID-1][7:0] data_t;
    typedef logic [MTY_WID-1:0] mty_t;

    // Signals
    wire logic  valid;
    wire logic  rdy;
    wire data_t data;
    wire logic  eop;
    wire mty_t  mty;
    wire logic  err;
    wire META_T meta;
    
    var  logic  sop;

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
        input meta
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
    // Connect signals (tx -> rx)
    assign to_rx.valid = from_tx.valid;
    assign to_rx.data  = from_tx.data;
    assign to_rx.eop   = from_tx.eop;
    assign to_rx.mty   = from_tx.mty;
    assign to_rx.err   = from_tx.err;
    assign to_rx.meta  = from_tx.meta;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_intf_connector
