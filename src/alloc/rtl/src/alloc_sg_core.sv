module alloc_sg_core #(
    parameter int  SCATTER_CONTEXTS = 1,
    parameter int  GATHER_CONTEXTS = 1,
    parameter int  PTR_WID = 1,
    parameter int  BUFFER_SIZE = 1,
    parameter int  MAX_FRAME_SIZE = 16384,
    parameter int  META_WID = 1,
    parameter int  STORE_Q_DEPTH = 64,
    parameter bit  STORE_FC = 1'b1, // Can flow control store interface
    parameter int  LOAD_Q_DEPTH = 32,
    parameter bit  LOAD_FC = 1'b1,   // Can flow control dealloc interface
    parameter int  N_ALLOC = 1,      // (powers of 2 only) Controls parallelism of allocator logic; can be
                                             // used to increase allocation throughput. See alloc_bv for details.
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

    // Buffer allocation limit (or set to 0 for no limit, i.e. BUFFERS = 2**PTR_WID)
    input  logic [PTR_WID:0]   BUFFERS = 0,

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

    // Allocator monitor
    alloc_mon_intf.tx         mon_if
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
                std_pkg::param_check(scatter_if[i].PTR_WID, PTR_WID, $sformatf("scatter_if[%0d].PTR_WID", i));
                std_pkg::param_check(scatter_if[i].META_WID, META_WID, $sformatf("scatter_if[%0d].META_WID", i));
            end
        end : g__scatter_ctxt
        for (genvar i = 0; i < GATHER_CONTEXTS; i++) begin : g__gather_ctxt
            initial begin
                std_pkg::param_check(gather_if[i].BUFFER_SIZE, BUFFER_SIZE, $sformatf("gather_if[%0d].BUFFER_SIZE", i));
                std_pkg::param_check(gather_if[i].PTR_WID, PTR_WID, $sformatf("gather_if[%0d].PTR_WID", i));
                std_pkg::param_check(gather_if[i].META_WID, META_WID, $sformatf("gather_if[%0d].META_WID", i));
            end
        end : g__gather_ctxt
    endgenerate

    // -----------------------------
    // Signals
    // -----------------------------
    logic               alloc_init_done;

    logic               alloc_req;
    logic               alloc_rdy;
    logic [PTR_WID-1:0] alloc_ptr;

    logic               dealloc_req;
    logic               dealloc_rdy;
    logic [PTR_WID-1:0] dealloc_ptr;

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_intf #(.BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)) __gather_if [GATHER_CONTEXTS+1] (.clk);

    // -----------------------------
    // Status
    // -----------------------------
    assign init_done = alloc_init_done && desc_mem_init_done;

    // -----------------------------
    // Buffer pointer allocator (bit-vector allocator, on-chip)
    // -----------------------------
    alloc_bv  #(
        .PTR_WID         ( PTR_WID ),
        .ALLOC_Q_DEPTH   ( STORE_Q_DEPTH ),
        .ALLOC_FC        ( STORE_FC ),
        .DEALLOC_Q_DEPTH ( LOAD_Q_DEPTH ),
        .DEALLOC_FC      ( LOAD_FC ),
        .NUM_SLICES      ( N_ALLOC ),
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
        .dealloc_req,
        .dealloc_rdy,
        .dealloc_ptr,
        .mon_if
    );

    // -----------------------------
    // Scatter core
    // -----------------------------
    alloc_scatter_core #(
        .CONTEXTS       ( SCATTER_CONTEXTS ),
        .PTR_WID        ( PTR_WID ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .MAX_FRAME_SIZE ( MAX_FRAME_SIZE ),
        .META_WID       ( META_WID ),
        .Q_DEPTH        ( STORE_Q_DEPTH ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_alloc_scatter_core (
        .*
    );

    // -----------------------------
    // Gather core
    // -----------------------------
    alloc_gather_core  #(
        .CONTEXTS       ( GATHER_CONTEXTS + 1),
        .PTR_WID        ( PTR_WID ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .META_WID       ( META_WID ),
        .Q_DEPTH        ( STORE_Q_DEPTH ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_alloc_gather_core (
        .gather_if      ( __gather_if ),
        .*
    );

    // Most of the gather interfaces are driven from external controllers...
    generate
        for (genvar i = 0; i < GATHER_CONTEXTS; i++) begin : g__ctxt
            alloc_intf_load_connector i_alloc_intf_load_connector (
                .from_tx ( gather_if[i] ),
                .to_rx   ( __gather_if[i] )
            );
        end : g__ctxt
    endgenerate

    // ... but the last one is used as the 'recycle' interface
    //
    //   'gather' transactions on this interface just follow the linked
    //   list of descriptors and deallocate the buffers referenced
    assign __gather_if[GATHER_CONTEXTS].req = recycle_req;
    assign recycle_rdy = __gather_if[GATHER_CONTEXTS].rdy;
    assign __gather_if[GATHER_CONTEXTS].ptr = recycle_ptr;
    assign __gather_if[GATHER_CONTEXTS].ack = 1'b1;
    assign recycle_ack = __gather_if[GATHER_CONTEXTS].vld && __gather_if[GATHER_CONTEXTS].eof;

endmodule : alloc_sg_core
