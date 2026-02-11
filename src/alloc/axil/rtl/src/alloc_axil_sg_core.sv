// Scatter/gather allocator with AXI-L interface for control/monitoring.
// See alloc_sg_core module for details.
module alloc_axil_sg_core #(
    parameter int  SCATTER_CONTEXTS = 1,
    parameter int  GATHER_CONTEXTS = 1,
    parameter int  PTR_WID = 1,
    parameter int  BUFFER_SIZE = 1,
    parameter int  MAX_FRAME_SIZE = 16384,
    parameter int  META_WID = 1,
    parameter int  STORE_Q_DEPTH = 64,
    parameter bit  STORE_FC = 1'b1, // Can flow control store interface
    parameter int  LOAD_Q_DEPTH = 32,
    parameter bit  LOAD_FC = 1'b1,    // Can flow control dealloc interface
    parameter int  N_ALLOC = 1,
    parameter int  MEM_WR_LATENCY = 8,
    // Derived parameters (don't override)
    parameter int  FRAME_SIZE_WID = $clog2(MAX_FRAME_SIZE+1),
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1, // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
) (
    // Clock/reset
    input logic                clk,
    input logic                srst,

    // Control
    input  logic               en,

    // Status
    output logic               init_done,

    // Scatter interface
    alloc_intf.store_rx        scatter_if [SCATTER_CONTEXTS],

    // Gather interface
    alloc_intf.load_rx         gather_if  [GATHER_CONTEXTS],

    // Recycle interface
    input  logic               recycle_req,
    output logic               recycle_rdy,
    input  logic [PTR_WID-1:0] recycle_ptr,
    output logic               recycle_ack,

    // Descriptor memory interface
    mem_wr_intf.controller     desc_mem_wr_if,
    mem_rd_intf.controller     desc_mem_rd_if,
    input  logic               desc_mem_init_done,

    // Frame completion interface
    output logic                      frame_valid [SCATTER_CONTEXTS],
    output logic                      frame_error,
    output logic [PTR_WID-1:0]        frame_ptr,
    output logic [FRAME_SIZE_WID-1:0] frame_size,

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
    alloc_sg_core        #(
        .SCATTER_CONTEXTS ( SCATTER_CONTEXTS ),
        .GATHER_CONTEXTS  ( GATHER_CONTEXTS ),
        .PTR_WID          ( PTR_WID ),
        .BUFFER_SIZE      ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE   ( MAX_FRAME_SIZE ),
        .META_WID         ( META_WID ),
        .STORE_Q_DEPTH    ( STORE_Q_DEPTH ),
        .STORE_FC         ( STORE_FC ),
        .LOAD_Q_DEPTH     ( LOAD_Q_DEPTH ),
        .LOAD_FC          ( LOAD_FC ),
        .N_ALLOC          ( N_ALLOC ),
        .MEM_WR_LATENCY   ( MEM_WR_LATENCY ),
        .SIM__FAST_INIT   ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL   ( SIM__RAM_MODEL )
    ) i_alloc_sg_core (
        .clk,
        .srst    ( ctrl_reset ),
        .en      ( ctrl_en ),
        .BUFFERS ( 0 ),
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

endmodule : alloc_axil_sg_core
