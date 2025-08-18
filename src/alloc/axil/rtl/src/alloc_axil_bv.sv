// Pointer allocator with the list of allocated/unallocated pointers maintained
// as a bit vector in RAM. Includes AXI-L interface for control/monitoring.
//
// See alloc_bv_core module for details.
module alloc_axil_bv #(
    parameter int  PTR_WID = 1,
    parameter int  ALLOC_Q_DEPTH = 64,   // Scan process finds unallocated pointers and fills queue;
                                         // scan is a 'background' task and is 'slow', and therefore
                                         // allocation requests can be received faster than they can
                                         // be serviced. The size of the allocation queue determines
                                         // the burst behaviour of the allocator
    parameter bit  ALLOC_FC = 1'b1,      // Can flow control alloc interface,
                                         // i.e. requester waits on alloc_rdy
    parameter int  DEALLOC_Q_DEPTH = 32, // Deallocation requests can be received faster than they are
                                         // retired; the depth of the dealloc queue determines the burst
                                         // behaviour of the deallocator
    parameter bit  DEALLOC_FC = 1'b1,    // Can flow control dealloc interface,
                                         // i.e. requester waits on dealloc_rdy
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1,    // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
) (
    // Clock/reset
    input logic                clk,
    input logic                srst,

    // Control
    input  logic               en,

    // Status
    output logic               init_done,

    // Allocate interface
    input  logic               alloc_req,
    output logic               alloc_rdy,
    output logic [PTR_WID-1:0] alloc_ptr,

    // Deallocate interface
    input  logic               dealloc_req,
    output logic               dealloc_rdy,
    input  logic [PTR_WID-1:0] dealloc_ptr,

    // AXI-L control/monitoring
    axi4l_intf.peripheral  axil_if
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic ctrl_reset;
    logic ctrl_en;
    logic ctrl_alloc_en;

    logic [7:0] state_mon [2];

    logic [PTR_WID:0] PTRS = 0;

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_mon_intf mon_if (.clk);

    // -----------------------------
    // BV allocator instantiation
    // -----------------------------
    alloc_bv            #(
        .PTR_WID         ( PTR_WID ),
        .ALLOC_Q_DEPTH   ( ALLOC_Q_DEPTH ),
        .ALLOC_FC        ( ALLOC_FC ),
        .DEALLOC_Q_DEPTH ( DEALLOC_Q_DEPTH ),
        .DEALLOC_FC      ( DEALLOC_FC ),
        .SIM__FAST_INIT  ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL  ( SIM__RAM_MODEL )
    ) i_alloc_bv (
        .clk,
        .srst    ( ctrl_reset ),
        .en      ( ctrl_en ),
        .scan_en ( ctrl_alloc_en ),
        .*
    );

    assign state_mon[0] = '0;
    assign state_mon[1] = '0;

    // -----------------------------
    // AXI-L control/monitor core
    // -----------------------------
    alloc_axil_core #(.PTR_WID(PTR_WID)) i_alloc_axil_core (
        .*
    );

endmodule : alloc_axil_bv
