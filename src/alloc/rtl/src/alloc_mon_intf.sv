// Allocator monitor interface
interface alloc_mon_intf (
    input wire logic clk
); 

    // Signals
    logic        alloc;
    logic        alloc_fail;
    logic        alloc_err;
    logic        dealloc;
    logic        dealloc_fail;
    logic        dealloc_err;  
    logic [31:0] ptr;  

    modport controller(
        input  clk,
        input  alloc,
        input  alloc_fail,
        input  alloc_err,
        input  dealloc,
        input  dealloc_fail,
        input  dealloc_err,
        input  ptr
    );

    modport peripheral(
        input  clk,
        output alloc,
        output alloc_fail,
        output alloc_err,
        output dealloc,
        output dealloc_fail,
        output dealloc_err,
        output ptr
    );
endinterface : alloc_mon_intf

(* autopipeline_module = "true" *) module alloc_mon_intf_pipe (
    alloc_mon_intf.controller alloc_mon_if_from_peripheral,
    alloc_mon_intf.peripheral alloc_mon_if_to_controller
);
    (* autopipeline_limit=8 *) logic alloc;
    (* autopipeline_limit=8 *) logic alloc_fail;
    (* autopipeline_limit=8 *) logic dealloc;
    (* autopipeline_limit=8 *) logic dealloc_fail;
    (* autopipeline_limit=8, autopipeline_group="err" *) logic alloc_err;
    (* autopipeline_limit=8, autopipeline_group="err" *) logic dealloc_err;
    (* autopipeline_limit=8, autopipeline_group="err" *) logic[31:0] ptr;
    
    always_ff @(posedge alloc_mon_if_from_peripheral.clk) begin
        alloc        <= alloc_mon_if_from_peripheral.alloc;
        alloc_fail   <= alloc_mon_if_from_peripheral.alloc_fail;
        alloc_err    <= alloc_mon_if_from_peripheral.alloc_err;
        dealloc      <= alloc_mon_if_from_peripheral.dealloc;
        dealloc_fail <= alloc_mon_if_from_peripheral.dealloc_fail;
        dealloc_err  <= alloc_mon_if_from_peripheral.dealloc_err;
        ptr          <= alloc_mon_if_from_peripheral.ptr;
    end

    assign alloc_mon_if_to_controller.alloc        = alloc;
    assign alloc_mon_if_to_controller.alloc_fail   = alloc_fail;
    assign alloc_mon_if_to_controller.alloc_err    = alloc_err;
    assign alloc_mon_if_to_controller.dealloc      = dealloc;
    assign alloc_mon_if_to_controller.dealloc_fail = dealloc_fail;
    assign alloc_mon_if_to_controller.dealloc_err  = dealloc_err;
    assign alloc_mon_if_to_controller.ptr          = ptr;

endmodule : alloc_mon_intf_pipe
