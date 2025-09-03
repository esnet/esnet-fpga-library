interface mem_rd_intf #(
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
    logic  req;
    addr_t addr;
    data_t data;
    logic  ack;

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
            input addr_t _addr
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
            output data_t _data
        );
        wait(cb.ack);
        _data = cb.data;
    endtask

    task read(
            input addr_t _addr,
            output data_t _data
        );
        send_req(_addr);
        wait_resp(_data);
    endtask

endinterface : mem_rd_intf

// Memory read interface (back-to-back) connector helper module
module mem_rd_intf_connector (
    mem_rd_intf.peripheral mem_rd_if_from_controller,
    mem_rd_intf.controller mem_rd_if_to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign mem_rd_if_to_peripheral.rst  = mem_rd_if_from_controller.rst;
    assign mem_rd_if_to_peripheral.req  = mem_rd_if_from_controller.req;
    assign mem_rd_if_to_peripheral.addr = mem_rd_if_from_controller.addr;

    // Connect signals (peripheral -> controller)
    assign mem_rd_if_from_controller.rdy  = mem_rd_if_to_peripheral.rdy;
    assign mem_rd_if_from_controller.data = mem_rd_if_to_peripheral.data;
    assign mem_rd_if_from_controller.ack  = mem_rd_if_to_peripheral.ack;
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
