// Linked-list allocator with AXI-L interface for control/monitoring
// See alloc_ll_core module for details.
module alloc_axil_ll_core #(
    parameter int  LIST_CONTEXTS = 1,
    parameter int  PTR_WID = 1,
    parameter int  META_WID = 1,
    parameter int  STORE_Q_DEPTH = 16,
    parameter bit  STORE_FC = 1'b1, // Can flow control store interface
    parameter int  LOAD_Q_DEPTH = 16,
    parameter bit  LOAD_FC = 1'b1,   // Can flow control dealloc interface
    parameter int  N_ALLOC = 1,      // (powers of 2 only) Controls parallelism of allocator logic; can be
                                     // used to increase allocation throughput. See alloc_bv for details.
    parameter int  NUM_RD_TRANSACTIONS = 8,
    // Derived parameters (don't override)
    parameter int  LIST_SEL_WID = LIST_CONTEXTS > 1 ? $clog2(LIST_CONTEXTS) : 1,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1, // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
) (
    // Clock/reset
    input logic                     clk,
    input logic                     srst,

    // Control
    input  logic                    en,

    // Status
    output logic                    init_done,

    // Buffer allocation limit (or set to 0 for no limit, i.e. BUFFERS = 2**PTR_WID)
    input  logic [PTR_WID:0]        BUFFERS = 0,

    // Write interface
    input  logic                    store_req,
    output logic                    store_rdy,
    input  logic [LIST_SEL_WID-1:0] store_list_sel,
    input  logic [META_WID-1:0]     store_meta,
    output logic                    store_ack,
    output logic                    store_nack,

    // Read interface
    input  logic                    load_req,
    output logic                    load_rdy,
    input  logic [LIST_SEL_WID-1:0] load_list_sel,
    output logic [META_WID-1:0]     load_meta,
    output logic                    load_ack,
    output logic                    load_nack,

    // Descriptor memory interface
    mem_wr_intf.controller          mem_wr_if,
    mem_rd_intf.controller          mem_rd_if,
    input  logic                    mem_init_done,

    // AXI-L control/monitoring
    axi4l_intf.peripheral           axil_if
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
    // LL allocator instantiation
    // -----------------------------
    alloc_ll_core        #(
        .LIST_CONTEXTS    ( LIST_CONTEXTS ),
        .PTR_WID          ( PTR_WID ),
        .META_WID         ( META_WID ),
        .STORE_Q_DEPTH    ( STORE_Q_DEPTH ),
        .STORE_FC         ( STORE_FC ),
        .LOAD_Q_DEPTH     ( LOAD_Q_DEPTH ),
        .LOAD_FC          ( LOAD_FC ),
        .N_ALLOC          ( N_ALLOC ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .SIM__FAST_INIT   ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL   ( SIM__RAM_MODEL )
    ) i_alloc_ll_core (
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

endmodule : alloc_axil_ll_core
