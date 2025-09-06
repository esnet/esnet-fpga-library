interface mem_rd_intf #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32
) (
    input logic clk
);

    // Signals
    logic                rst;
    logic                rdy;
    logic                req;
    logic [ADDR_WID-1:0] addr;
    logic [DATA_WID-1:0] data;
    logic                ack;

    // Modports
    modport controller(
        input  clk,
        output rst,
        input  rdy,
        output req,
        output addr,
        input  data,
        input  ack
    );

    modport peripheral(
        input  clk,
        input  rst,
        output rdy,
        input  req,
        input  addr,
        output data,
        output ack
    );

    clocking cb @(posedge clk);
        output rst, addr;
        input rdy, data, ack;
        inout req;
    endclocking

    task idle();
        cb.rst <= 1'b0;
        cb.addr <= 'x;
        cb.req <= 1'b0;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task send_req(
            input bit [ADDR_WID-1:0] _addr
        );
        wait(rdy);
        cb.req <= 1'b1;
        cb.addr <= _addr;
        @(cb);
        wait(cb.req);
        cb.req <= 1'b0;
        cb.addr <= 'x;
    endtask

    task wait_resp(
            output bit [DATA_WID-1:0] _data
        );
        wait(cb.ack);
        _data = cb.data;
    endtask

    task read(
            input  bit [ADDR_WID-1:0] _addr,
            output bit [DATA_WID-1:0] _data
        );
        send_req(_addr);
        wait_resp(_data);
    endtask

endinterface : mem_rd_intf

// Memory read interface (back-to-back) connector helper module
module mem_rd_intf_connector (
    mem_rd_intf.peripheral from_controller,
    mem_rd_intf.controller to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign to_peripheral.rst  = from_controller.rst;
    assign to_peripheral.req  = from_controller.req;
    assign to_peripheral.addr = from_controller.addr;

    // Connect signals (peripheral -> controller)
    assign from_controller.rdy  = to_peripheral.rdy;
    assign from_controller.data = to_peripheral.data;
    assign from_controller.ack  = to_peripheral.ack;
endmodule : mem_rd_intf_connector

// Memory read interface controller termination
module mem_rd_intf_controller_term (
    input srst = 1'b0,
    mem_rd_intf.controller to_peripheral
);
    assign to_peripheral.rst = srst;
    assign to_peripheral.req = 1'b0;
endmodule : mem_rd_intf_controller_term

// Memory read interface peripheral termination
module mem_rd_intf_peripheral_term (
    input srst = 1'b0,
    mem_rd_intf.peripheral from_controller
);
    assign from_controller.rdy = 1'b0;
    assign from_controller.ack = 1'b0;
endmodule : mem_rd_intf_peripheral_term
