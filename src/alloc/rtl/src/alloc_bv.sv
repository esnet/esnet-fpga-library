// Pointer allocator with the list of allocated/unallocated pointers maintained
// as a bit vector in (on-chip) RAM. See underlying `alloc_bv_core` module for
// details.
module alloc_bv #(
    parameter type PTR_T = logic,
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
    // Derived parameters (don't override)
    parameter int  PTR_WID = $bits(PTR_T),
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1, // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
) (
    // Clock/reset
    input logic               clk,
    input logic               srst,

    // Control
    input  logic              en,
    input  logic              scan_en,

    // Status
    output logic              init_done,

    // Pointer allocation limit (or set to 0 for no limit, i.e. PTRS = 2**PTR_WID)
    input  logic              [PTR_WID:0] PTRS = 0,

    // Allocate interface
    input  logic              alloc_req,
    output logic              alloc_rdy,
    output PTR_T              alloc_ptr,

    // Deallocate interface   
    input  logic              dealloc_req,
    output logic              dealloc_rdy,
    input  PTR_T              dealloc_ptr,

    // Monitoring
    alloc_mon_intf.tx         mon_if
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int MAX_PTRS = 2**PTR_WID;
    localparam int NUM_COLS = MAX_PTRS > 256*1024 ? 64 :
                              MAX_PTRS > 64*1024  ? MAX_PTRS / 4096 :
                              MAX_PTRS > 16    ? 16 : 1;
    localparam int NUM_ROWS = MAX_PTRS / NUM_COLS;

    localparam int COL_WID = $clog2(NUM_COLS);
    localparam int ROW_WID = $clog2(NUM_ROWS);

    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ROW_WID,
        DATA_WID: NUM_COLS,
        ASYNC: 0,
        RESET_FSM: 1,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    localparam int MEM_RD_LATENCY = mem_pkg::get_rd_latency(MEM_SPEC);

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_wr_intf #(.ADDR_WID (ROW_WID), .DATA_WID(NUM_COLS)) mem_wr_if (.clk);
    mem_rd_intf #(.ADDR_WID (ROW_WID), .DATA_WID(NUM_COLS)) mem_rd_if (.clk);

    // -----------------------------
    // Signals
    // -----------------------------
    logic mem_init_done;

    // -----------------------------
    // Memory
    // -----------------------------
    mem_ram_sdp   #(
        .SPEC      ( MEM_SPEC ),
        .SIM__FAST_INIT ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL ( SIM__RAM_MODEL )
    ) i_mem_ram_sdp (
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

    assign mem_init_done = mem_wr_if.rdy;

    // -----------------------------
    // Allocator core
    // -----------------------------
    alloc_bv_core       #(
        .PTR_T           ( PTR_T ),
        .ALLOC_Q_DEPTH   ( ALLOC_Q_DEPTH ),
        .ALLOC_FC        ( ALLOC_FC ),
        .DEALLOC_Q_DEPTH ( DEALLOC_Q_DEPTH ),
        .DEALLOC_FC      ( DEALLOC_FC ),
        .MEM_RD_LATENCY  ( MEM_RD_LATENCY )
    ) i_alloc_bv_core (
        .*
    );

    assign init_done = mem_init_done;

endmodule : alloc_bv
