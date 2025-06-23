interface mem_wr_intf #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32
) (
    input logic clk
);

    // Typedefs
    typedef logic [ADDR_WID-1:0] addr_t;
    typedef logic [DATA_WID-1:0] data_t;

    // Signals
    logic  rst;
    logic  rdy;
    logic  en;
    logic  req;
    addr_t addr;
    data_t data;
    logic  ack;

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
        default input #1step output #1step;
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
            input addr_t _addr,
            input data_t _data
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
            input addr_t _addr,
            input data_t _data
        );
        send_req(_addr, _data);
        wait_resp();
    endtask

endinterface : mem_wr_intf

// Memory write interface (back-to-back) connector helper module
module mem_wr_intf_connector (
    mem_wr_intf.peripheral mem_wr_if_from_controller,
    mem_wr_intf.controller mem_wr_if_to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign mem_wr_if_to_peripheral.rst  = mem_wr_if_from_controller.rst;
    assign mem_wr_if_to_peripheral.en   = mem_wr_if_from_controller.en;
    assign mem_wr_if_to_peripheral.req  = mem_wr_if_from_controller.req;
    assign mem_wr_if_to_peripheral.addr = mem_wr_if_from_controller.addr;
    assign mem_wr_if_to_peripheral.data = mem_wr_if_from_controller.data;

    // Connect signals (peripheral -> controller)
    assign mem_wr_if_from_controller.rdy = mem_wr_if_to_peripheral.rdy;
    assign mem_wr_if_from_controller.ack = mem_wr_if_to_peripheral.ack;
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
