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

// Memory read interface N:1 mux.
module mem_rd_intf_mux #(
    parameter int N = 2, // number of ingress mem_rd interfaces.
    // Derived parameters (don't override)
    parameter int SEL_WID = N > 1 ? $clog2(N) : 1
) (
    mem_rd_intf.peripheral from_controller [N],
    mem_rd_intf.controller to_peripheral,
    input logic [SEL_WID-1:0] sel
);

    localparam ADDR_WID = to_peripheral.ADDR_WID;
    localparam DATA_WID = to_peripheral.DATA_WID;

    localparam int N_POW2 = 2**SEL_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_controller[0].ADDR_WID, to_peripheral.ADDR_WID, "from_controller[0].ADDR_WID");
        std_pkg::param_check(from_controller[0].DATA_WID, to_peripheral.DATA_WID, "from_controller[0].DATA_WID");
    end

    logic                rst  [N_POW2];
    logic                req  [N_POW2];
    logic [ADDR_WID-1:0] addr [N_POW2];

    // Convert between array of signals and array of interfaces.
    generate
        for (genvar g_if = 0; g_if < N; g_if++) begin : g__if
            assign rst [g_if] = from_controller[g_if].rst;
            assign req [g_if] = from_controller[g_if].req;
            assign addr[g_if] = from_controller[g_if].addr;

            assign from_controller[g_if].data = (sel == g_if) ? to_peripheral.data : '0;
            assign from_controller[g_if].rdy  = (sel == g_if) ? to_peripheral.rdy  : '0;
            assign from_controller[g_if].ack  = (sel == g_if) ? to_peripheral.ack  : '0;
        end : g__if
        // Specify 'out-of-range' values
        for (genvar g_if = N; g_if < N_POW2; g_if++) begin : g__if_out_of_range
            assign rst [g_if] = '0;
            assign req [g_if] = '0;
            assign addr[g_if] = '0;
        end : g__if_out_of_range
    endgenerate

    always_comb begin
        to_peripheral.rst  = rst  [sel];
        to_peripheral.req  = req  [sel];
        to_peripheral.addr = addr [sel];
    end

endmodule : mem_rd_intf_mux
