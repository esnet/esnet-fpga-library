interface mem_intf #(
    parameter int ADDR_WID = 1,
    parameter int DATA_WID = 1
) (
    input logic clk
);

    // Signals
    logic                rst;
    logic                rdy;
    logic                req;
    logic                wr;
    logic [ADDR_WID-1:0] addr;
    logic [DATA_WID-1:0] wr_data;
    logic                wr_ack;
    logic [DATA_WID-1:0] rd_data;
    logic                rd_ack;

    // Modports
    modport controller(
        input  clk,
        output rst,
        input  rdy,
        output req,
        output wr,
        output addr,
        output wr_data,
        input  wr_ack,
        input  rd_data,
        input  rd_ack
    );

    modport peripheral(
        input  clk,
        input  rst,
        output rdy,
        input  req,
        input  wr,
        input  addr,
        input  wr_data,
        output wr_ack,
        output rd_data,
        output rd_ack
    );

    clocking cb @(posedge clk);
        output rst, wr, addr, wr_data;
        input rdy, rd_data, wr_ack, rd_ack;
        inout req;
    endclocking

    task idle();
        cb.req <= 1'b0;
        cb.wr <= 1'bx;
        cb.addr <= 'x;
        cb.wr_data <= 'x;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task send_req(
            input bit [ADDR_WID-1:0] _addr
        );
        cb.req <= 1'b1;
        cb.addr <= _addr;
        wait(cb.req && cb.rdy);
        cb.req <= 1'b0;
        cb.addr <= 'x;
    endtask

    task write(
            input bit [ADDR_WID-1:0] _addr,
            input bit [DATA_WID-1:0] _data
        );
        cb.wr_data <= _data;
        cb.wr <= 1'b1;
        send_req(_addr);
        wait(cb.wr_ack);
        cb.wr <= 1'b0;
        cb.wr_data <= 'x;
    endtask

    task read(
            input  bit [ADDR_WID-1:0] _addr,
            output bit [DATA_WID-1:0] _data
        );
        cb.wr <= 1'b0;
        send_req(_addr);
        wait(cb.rd_ack);
        _data = cb.rd_data;
    endtask

endinterface : mem_intf

// Memory interface (back-to-back) connector helper module
module mem_intf_connector (
    mem_intf.peripheral mem_if_from_controller,
    mem_intf.controller mem_if_to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign mem_if_to_peripheral.rst  = mem_if_from_controller.rst;
    assign mem_if_to_peripheral.req  = mem_if_from_controller.req;
    assign mem_if_to_peripheral.wr   = mem_if_from_controller.wr;
    assign mem_if_to_peripheral.addr = mem_if_from_controller.addr;
    assign mem_if_to_peripheral.wr_data = mem_if_from_controller.wr_data;

    // Connect signals (peripheral -> controller)
    assign mem_if_from_controller.rdy = mem_if_to_peripheral.rdy;
    assign mem_if_from_controller.wr_ack = mem_if_to_peripheral.wr_ack;
    assign mem_if_from_controller.rd_data = mem_if_to_peripheral.rd_data;
    assign mem_if_from_controller.rd_ack = mem_if_to_peripheral.rd_ack;
endmodule : mem_intf_connector
