interface mem_wr_intf #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32
) (
    input logic clk
);

    // Signals
    logic                rst;
    logic                rdy;
    logic                en;
    logic                req;
    logic [ADDR_WID-1:0] addr;
    logic [DATA_WID-1:0] data;
    logic                ack;

    // Modports
    modport controller(
        input  clk,
        output rst,
        input  rdy,
        output en,
        output req,
        output addr,
        output data,
        input  ack
    );

    modport peripheral(
        input  clk,
        input  rst,
        output rdy,
        input  en,
        input  req,
        input  addr,
        input  data,
        output ack
    );

    clocking cb @(posedge clk);
        output en, rst, addr, data;
        input rdy, ack;
        inout req;
    endclocking

    task idle();
        cb.rst <= 1'b0;
        cb.en <= 1'b0;
        cb.req <= 1'b0;
        cb.addr <= 'x;
        cb.data <= 'x;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task send_req(
            input bit [ADDR_WID-1:0] _addr,
            input bit [DATA_WID-1:0] _data
        );
        cb.en <= 1'b1;
        wait(rdy);
        cb.req <= 1'b1;
        cb.addr <= _addr;
        cb.data <= _data;
        @(cb);
        wait(cb.req);
        cb.en <= 1'b0;
        cb.req <= 1'b0;
        cb.addr <= 'x;
        cb.data <= 'x;
    endtask

    task wait_resp();
        wait(cb.ack);
    endtask

    task write(
            input bit [ADDR_WID-1:0] _addr,
            input bit [DATA_WID-1:0] _data
        );
        send_req(_addr, _data);
        wait_resp();
    endtask

endinterface : mem_wr_intf

// Memory write interface (back-to-back) connector helper module
module mem_wr_intf_connector (
    mem_wr_intf.peripheral from_controller,
    mem_wr_intf.controller to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign to_peripheral.rst  = from_controller.rst;
    assign to_peripheral.en   = from_controller.en;
    assign to_peripheral.req  = from_controller.req;
    assign to_peripheral.addr = from_controller.addr;
    assign to_peripheral.data = from_controller.data;

    // Connect signals (peripheral -> controller)
    assign from_controller.rdy = to_peripheral.rdy;
    assign from_controller.ack = to_peripheral.ack;
endmodule : mem_wr_intf_connector

// Memory write interface controller termination
module mem_wr_intf_controller_term (
    input srst = 1'b0,
    mem_wr_intf.controller to_peripheral
);
    assign to_peripheral.rst = srst;
    assign to_peripheral.en = 1'b0;
    assign to_peripheral.req = 1'b0;
endmodule : mem_wr_intf_controller_term

// Memory write interface peripheral termination
module mem_wr_intf_peripheral_term (
    input srst = 1'b0,
    mem_wr_intf.peripheral from_controller
);
    assign from_controller.rdy = 1'b0;
    assign from_controller.ack = 1'b0;
endmodule : mem_wr_intf_peripheral_term
