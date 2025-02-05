interface fifo_rd_mon_intf (
    input wire logic clk
); 

    // Signals
    bit          reset;
    bit          empty;
    bit          uflow;
    logic [31:0] count;
    logic [31:0] ptr;

    modport controller(
        input  clk,
        input  reset,
        input  empty,
        input  uflow,
        input  count,
        input  ptr
    );

    modport peripheral(
        input  clk,
        output reset,
        output empty,
        output uflow,
        output count,
        output ptr
    );
endinterface : fifo_rd_mon_intf

(* autopipeline_module = "true" *) module fifo_rd_mon_intf_pipe (
    fifo_rd_mon_intf.controller fifo_rd_mon_if_from_peripheral,
    fifo_rd_mon_intf.peripheral fifo_rd_mon_if_to_controller
);
    (* autopipeline_limit=8 *) logic reset;
    (* autopipeline_limit=8 *) logic empty;
    (* autopipeline_limit=8 *) logic uflow;
    (* autopipeline_limit=8 *) logic [31:0] count;
    (* autopipeline_limit=8 *) logic [31:0] ptr;
    
    always_ff @(posedge fifo_rd_mon_if_from_peripheral.clk) begin
        reset <= fifo_rd_mon_if_from_peripheral.reset;
        empty <= fifo_rd_mon_if_from_peripheral.empty;
        uflow <= fifo_rd_mon_if_from_peripheral.uflow;
        count <= fifo_rd_mon_if_from_peripheral.count;
        ptr   <= fifo_rd_mon_if_from_peripheral.ptr;
    end

    assign fifo_rd_mon_if_to_controller.reset = reset;
    assign fifo_rd_mon_if_to_controller.empty = empty;
    assign fifo_rd_mon_if_to_controller.uflow = uflow;
    assign fifo_rd_mon_if_to_controller.count = count;
    assign fifo_rd_mon_if_to_controller.ptr   = ptr;

endmodule : fifo_rd_mon_intf_pipe
