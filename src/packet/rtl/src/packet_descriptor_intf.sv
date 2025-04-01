interface packet_descriptor_intf #(
    parameter type ADDR_T = logic,
    parameter type META_T = logic,
    parameter type SIZE_T = logic[15:0]
) (
    input logic clk,
    input logic srst = 1'b0
);
    import packet_pkg::*;

    // Signals
    logic        valid;
    logic        rdy;
    ADDR_T       addr;
    SIZE_T       size;
    logic        err;
    META_T       meta;
    
    // Modports
    modport tx(
        input  clk,
        input  srst,
        output valid,
        input  rdy,
        output addr,
        output size,
        output err,
        output meta
    );

    modport rx(
        input  clk,
        input  srst,
        input  valid,
        output rdy,
        input  addr,
        input  size,
        input  err,
        input  meta
    );

    clocking cb_tx @(posedge clk);
        default input #1step output #1step;
        output valid, addr, size, err, meta;
        input rdy;
    endclocking

    clocking cb_rx @(posedge clk);
        default input #1step output #1step;
        input valid, addr, size, err, meta;
        output rdy;
    endclocking

    task idle_tx();
        cb_tx.valid <= 1'b0;
        cb_tx.addr <= 'x;
        cb_tx.size <= 'x;
        cb_tx.err  <= 1'bx;
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
            input ADDR_T   _addr,
            input int      _size,
            input META_T   _meta = '0,
            input logic    _err = 1'b0
        );
        cb_tx.valid  <= 1'b1;
        cb_tx.addr   <= _addr;
        cb_tx.size   <= SIZE_T'(_size);
        cb_tx.err    <= _err;
        cb_tx.meta   <= _meta;
        @(cb_tx);
        wait (cb_tx.rdy);
        cb_tx.valid  <= 1'b0;
    endtask

    task receive(
            output ADDR_T   _addr,
            output int      _size,
            output META_T   _meta,
            output logic    _err
        );
        cb_rx.rdy <= 1'b1;
        @(cb_rx);
        wait(cb_rx.valid);
        cb_rx.rdy <= 1'b0;
        _addr   = cb_rx.addr;
        _size   = cb_rx.size;
        _meta   = cb_rx.meta;
        _err    = cb_rx.err;
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

endinterface : packet_descriptor_intf

// Packet descriptor interface (back-to-back) connector helper module
module packet_descriptor_intf_connector (
    packet_descriptor_intf.rx from_tx,
    packet_descriptor_intf.tx to_rx
);
    // Parameters
    localparam int ADDR_WID = $bits(from_tx.ADDR_T);
    localparam int META_WID = $bits(from_tx.META_T);
    localparam int SIZE_WID = $bits(from_tx.SIZE_T);

    // Parameter checking
    initial begin
        std_pkg::param_check($bits(to_rx.ADDR_T), ADDR_WID, "to_rx.ADDR_T");
        std_pkg::param_check($bits(to_rx.META_T), META_WID, "to_rx.META_T");
        std_pkg::param_check($bits(to_rx.SIZE_T), SIZE_WID, "to_rx.SIZE_T");
    end

    // Signals
    logic                valid;
    logic                rdy;
    logic [ADDR_WID-1:0] addr;
    logic [SIZE_WID-1:0] size;
    logic                err;
    logic [META_WID-1:0] meta;

    // Connect signals (tx -> rx)
    assign valid = from_tx.valid;
    assign addr  = from_tx.addr;
    assign size  = from_tx.size;
    assign err   = from_tx.err;
    assign meta  = from_tx.meta;

    assign to_rx.valid = valid;
    assign to_rx.addr  = addr;
    assign to_rx.size  = size;
    assign to_rx.err   = err;
    assign to_rx.meta  = meta;

    // Connect signals (rx -> tx)
    assign rdy = to_rx.rdy;

    assign from_tx.rdy = rdy;

endmodule : packet_descriptor_intf_connector
