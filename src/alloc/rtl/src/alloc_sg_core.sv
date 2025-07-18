module alloc_sg_core #(
    parameter int  SCATTER_CONTEXTS = 1,
    parameter int  GATHER_CONTEXTS = 1,
    parameter type PTR_T = logic,
    parameter int  BUFFER_SIZE = 1,
    parameter int  MAX_FRAME_SIZE = 16384,
    parameter type META_T = logic,
    parameter int  STORE_Q_DEPTH = 64,
    parameter bit  STORE_Q_FC = 1'b1, // Can flow control store interface
    parameter int  LOAD_Q_DEPTH = 32,
    parameter bit  LOAD_FC = 1'b1,    // Can flow control dealloc interface,
    parameter int  RECYCLE_Q_DEPTH = 32,
    parameter bit  RECYCLE_FC = 1'b1,
    // Derived parameters (don't override)
    parameter int  PTR_WID = $bits(PTR_T),
    parameter int  SIZE_WID = $clog2(BUFFER_SIZE),
    parameter type SIZE_T = logic [SIZE_WID-1:0],
    parameter int  FRAME_SIZE_WID = $clog2(MAX_FRAME_SIZE+1),
    parameter type FRAME_SIZE_T = logic [FRAME_SIZE_WID-1:0],
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1, // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
) (
    // Clock/reset
    input logic            clk,
    input logic            srst,

    // Control
    input  logic           en,

    // Status
    output logic           init_done,

    // Buffer allocation limit (or set to 0 for no limit, i.e. BUFFERS = 2**PTR_WID)
    input  logic           [PTR_WID:0] BUFFERS = 0,

    // Scatter interface
    alloc_intf.store_rx    scatter_if [SCATTER_CONTEXTS],

    // Gather interface
    alloc_intf.load_rx     gather_if  [GATHER_CONTEXTS],

    // Recycle interface
    input  logic           recycle_req,
    output logic           recycle_rdy,
    input  PTR_T           recycle_ptr,

    // Descriptor memory interface
    mem_wr_intf.controller desc_mem_wr_if,
    mem_rd_intf.controller desc_mem_rd_if,
    input  logic           desc_mem_init_done,

    // Frame completion interface
    output logic           frame_valid [SCATTER_CONTEXTS],
    output logic           frame_error,
    output PTR_T           frame_ptr,
    output FRAME_SIZE_T    frame_size
);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(desc_mem_wr_if.DATA_WID, desc_mem_rd_if.DATA_WID, "mem_if.DATA_WID");
    end
    generate
        for (genvar i = 0; i < SCATTER_CONTEXTS; i++) begin : g__scatter_ctxt
            initial begin
                std_pkg::param_check(scatter_if[i].BUFFER_SIZE, BUFFER_SIZE, $sformatf("scatter_if[%0d].BUFFER_SIZE", i));
                std_pkg::param_check($bits(scatter_if[i].PTR_T), PTR_WID, $sformatf("scatter_if[%0d].PTR_T", i));
                std_pkg::param_check($bits(scatter_if[i].META_T), $bits(META_T), $sformatf("scatter_if[%0d].META_T", i));
            end
        end : g__scatter_ctxt
        for (genvar i = 0; i < GATHER_CONTEXTS; i++) begin : g__gather_ctxt
            initial begin
                std_pkg::param_check(gather_if[i].BUFFER_SIZE, BUFFER_SIZE, $sformatf("gather_if[%0d].BUFFER_SIZE", i));
                std_pkg::param_check($bits(gather_if[i].PTR_T), PTR_WID, $sformatf("gather_if[%0d].PTR_T", i));
                std_pkg::param_check($bits(gather_if[i].META_T), $bits(META_T), $sformatf("gather_if[%0d].META_T", i));
            end
        end : g__gather_ctxt
    endgenerate

    // -----------------------------
    // Signals
    // -----------------------------
    logic         alloc_init_done;

    logic         alloc_req;
    logic         alloc_rdy;
    PTR_T         alloc_ptr;

    logic         dealloc_req;
    logic         dealloc_rdy;
    PTR_T         dealloc_ptr;

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_mon_intf alloc_mon_if__unused (.clk);

    // -----------------------------
    // Status
    // -----------------------------
    assign init_done = alloc_init_done && desc_mem_init_done;

    // -----------------------------
    // Buffer pointer allocator (bit-vector allocator, on-chip)
    // -----------------------------
    alloc_bv  #(
        .PTR_T ( PTR_T ),
        .SIM__FAST_INIT ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL ( SIM__RAM_MODEL )
    ) i_alloc_bv__ptr (
        .clk,
        .srst,
        .en,
        .scan_en     ( 1'b1 ),
        .init_done   ( alloc_init_done ),
        .PTRS        ( BUFFERS ),
        .alloc_req,
        .alloc_rdy,
        .alloc_ptr,
        .dealloc_req ( dealloc_req ),
        .dealloc_rdy ( dealloc_rdy ),
        .dealloc_ptr ( dealloc_ptr ),
        .mon_if      ( alloc_mon_if__unused )
    );

    // -----------------------------
    // Scatter core
    // -----------------------------
    alloc_scatter_core #(
        .CONTEXTS       ( SCATTER_CONTEXTS ),
        .PTR_T          ( PTR_T ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE ( MAX_FRAME_SIZE ),
        .META_T         ( META_T ),
        .Q_DEPTH        ( STORE_Q_DEPTH ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_alloc_scatter_core (
        .*
    );

    // -----------------------------
    // Gather core
    // -----------------------------
    alloc_gather_core  #(
        .CONTEXTS       ( GATHER_CONTEXTS ),
        .PTR_T          ( PTR_T ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .META_T         ( META_T ),
        .Q_DEPTH        ( STORE_Q_DEPTH ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_alloc_gather_core (
        .*
    );

endmodule : alloc_sg_core
