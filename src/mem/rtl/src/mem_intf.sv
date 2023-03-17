interface mem_intf #(
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
    modport wr_controller(
        output rst,
        input  rdy,
        output en,
        output req,
        output addr,
        output data,
        input  ack
    );

    modport wr_peripheral(
        input  rst,
        output rdy,
        input  en,
        input  req,
        input  addr,
        input  data,
        output ack
    );

    modport rd_controller(
        output rst,
        input  rdy,
        output en,
        output req,
        output addr,
        input  data,
        input  ack
    );

    modport rd_peripheral(
        input  rst,
        output rdy,
        input  en,
        input  req,
        input  addr,
        output data,
        output ack
    );

endinterface : mem_intf

// Memory write interface (back-to-back) connector helper module
module mem_wr_intf_connector (
    mem_intf.wr_peripheral mem_wr_if_from_controller,
    mem_intf.wr_controller mem_wr_if_to_peripheral
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

// Memory read interface (back-to-back) connector helper module
module mem_rd_intf_connector (
    mem_intf.rd_peripheral mem_rd_if_from_controller,
    mem_intf.rd_controller mem_rd_if_to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign mem_rd_if_to_peripheral.rst  = mem_rd_if_from_controller.rst;
    assign mem_rd_if_to_peripheral.en   = mem_rd_if_from_controller.en;
    assign mem_rd_if_to_peripheral.req  = mem_rd_if_from_controller.req;
    assign mem_rd_if_to_peripheral.addr = mem_rd_if_from_controller.addr;

    // Connect signals (peripheral -> controller)
    assign mem_rd_if_from_controller.rdy  = mem_rd_if_to_peripheral.rdy;
    assign mem_rd_if_from_controller.data = mem_rd_if_to_peripheral.data;
    assign mem_rd_if_from_controller.ack  = mem_rd_if_to_peripheral.ack;
endmodule : mem_rd_intf_connector
