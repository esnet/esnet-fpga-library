interface fifo_wr_mon_intf (
    input wire logic clk
);

    // Signals
    bit          reset;
    bit          full;
    bit          oflow;
    logic [31:0] count;
    logic [31:0] ptr;

    modport controller(
        input  clk,
        input  reset,
        input  full,
        input  oflow,
        input  count,
        input  ptr
    );

    modport peripheral(
        input  clk,
        output reset,
        output full,
        output oflow,
        output count,
        output ptr
    );
endinterface : fifo_wr_mon_intf

(* autopipeline_module = "true" *) module fifo_wr_mon_intf_pipe (
    fifo_wr_mon_intf.controller fifo_wr_mon_if_from_peripheral,
    fifo_wr_mon_intf.peripheral fifo_wr_mon_if_to_controller
);
    (* autopipeline_limit=8 *) logic reset;
    (* autopipeline_limit=8 *) logic full;
    (* autopipeline_limit=8 *) logic oflow;
    (* autopipeline_limit=8 *) logic [31:0] count;
    (* autopipeline_limit=8 *) logic [31:0] ptr;
    
    always_ff @(posedge fifo_wr_mon_if_from_peripheral.clk) begin
        reset <= fifo_wr_mon_if_from_peripheral.reset;
        full  <= fifo_wr_mon_if_from_peripheral.full;
        oflow <= fifo_wr_mon_if_from_peripheral.oflow;
        count <= fifo_wr_mon_if_from_peripheral.count;
        ptr   <= fifo_wr_mon_if_from_peripheral.ptr;
    end

    assign fifo_wr_mon_if_to_controller.reset = reset;
    assign fifo_wr_mon_if_to_controller.full  = full;
    assign fifo_wr_mon_if_to_controller.oflow = oflow;
    assign fifo_wr_mon_if_to_controller.count = count;
    assign fifo_wr_mon_if_to_controller.ptr   = ptr;

endmodule : fifo_wr_mon_intf_pipe
