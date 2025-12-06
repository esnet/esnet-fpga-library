// Pointer allocator with the list of allocated/unallocated pointers maintained
// as a bit vector in (on-chip) RAM. See underlying `alloc_bv_core` module for
// details.
module alloc_bv #(
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
    parameter int  NUM_SLICES = 1,       // (power of 2) Implements allocator as 1, 2, 4 etc independent slices
                                         //              to improve allocation throughput
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1, // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
) (
    // Clock/reset
    input logic                clk,
    input logic                srst,

    // Control
    input  logic               en,
    input  logic               scan_en,

    // Status
    output logic               init_done,

    // Pointer allocation limit (or set to 0 for no limit, i.e. PTRS = 2**PTR_WID)
    input  logic [PTR_WID:0]   PTRS = 0,

    // Allocate interface
    input  logic               alloc_req,
    output logic               alloc_rdy,
    output logic [PTR_WID-1:0] alloc_ptr,

    // Deallocate interface
    input  logic               dealloc_req,
    output logic               dealloc_rdy,
    input  logic [PTR_WID-1:0] dealloc_ptr,

    // Monitoring
    alloc_mon_intf.tx          mon_if
);

    // -----------------------------
    // Parameter checks
    // -----------------------------
    initial begin
        std_pkg::param_check(NUM_SLICES, 2**$clog2(NUM_SLICES), "NUM_SLICES must be a power of two.");
    end

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int MAX_PTRS = 2**PTR_WID;

    localparam int SLICE_MAX_PTRS = MAX_PTRS/NUM_SLICES;
    localparam int SLICE_PTR_WID = $clog2(SLICE_MAX_PTRS);


    localparam int NUM_COLS = SLICE_MAX_PTRS > 256*1024 ? 64 :
                              SLICE_MAX_PTRS > 64*1024  ? SLICE_MAX_PTRS / 4096 :
                              SLICE_MAX_PTRS > 16    ? 16 : 1;
    localparam int NUM_ROWS = SLICE_MAX_PTRS / NUM_COLS;

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
    alloc_mon_intf __mon_if [NUM_SLICES] (.clk);

    // -----------------------------
    // Signals
    // -----------------------------
    logic [NUM_SLICES-1:0]                    mem_init_done;
    logic [NUM_SLICES-1:0]                    __alloc_req;
    logic [NUM_SLICES-1:0]                    __alloc_rdy;
    logic [NUM_SLICES-1:0][SLICE_PTR_WID-1:0] __alloc_ptr;

    logic [NUM_SLICES-1:0]                    __dealloc_req;
    logic [NUM_SLICES-1:0]                    __dealloc_rdy;
    logic [SLICE_PTR_WID-1:0]                 __dealloc_ptr;

    generate
        for (genvar g_slice = 0; g_slice < NUM_SLICES; g_slice++) begin : g__slice
            // -----------------------------
            // (Local) interfaces
            // -----------------------------
            mem_wr_intf #(.ADDR_WID (ROW_WID), .DATA_WID(NUM_COLS)) mem_wr_if (.clk);
            mem_rd_intf #(.ADDR_WID (ROW_WID), .DATA_WID(NUM_COLS)) mem_rd_if (.clk);

            // -----------------------------
            // (Local) signals
            // -----------------------------
            logic [SLICE_PTR_WID:0]   __PTRS;

            // -----------------------------
            // Allocator core
            // -----------------------------
            always @(posedge clk) __PTRS <= PTRS/NUM_SLICES + (PTRS % NUM_SLICES > g_slice);

            alloc_bv_core       #(
                .PTR_WID         ( SLICE_PTR_WID ),
                .ALLOC_Q_DEPTH   ( ALLOC_Q_DEPTH ),
                .ALLOC_FC        ( ALLOC_FC ),
                .DEALLOC_Q_DEPTH ( DEALLOC_Q_DEPTH ),
                .DEALLOC_FC      ( DEALLOC_FC ),
                .MEM_RD_LATENCY  ( MEM_RD_LATENCY )
            ) i_alloc_bv_core (
                .PTRS (__PTRS),
                .alloc_req ( __alloc_req[g_slice] ),
                .alloc_rdy ( __alloc_rdy[g_slice] ),
                .alloc_ptr ( __alloc_ptr[g_slice] ),
                .dealloc_req ( __dealloc_req[g_slice] ),
                .dealloc_rdy ( __dealloc_rdy[g_slice] ),
                .dealloc_ptr ( __dealloc_ptr ),
                .mon_if      ( __mon_if[g_slice] ),
                .mem_init_done ( mem_init_done[g_slice] ),
                .*
            );

            assign mem_init_done[g_slice] = mem_wr_if.rdy;

            // -----------------------------
            // Memory
            // -----------------------------
            mem_ram_sdp   #(
                .SPEC      ( MEM_SPEC ),
                .SIM__FAST_INIT ( SIM__FAST_INIT ),
                .SIM__RAM_MODEL ( SIM__RAM_MODEL )
            ) i_mem_ram_sdp ( .* );

        end : g__slice
    endgenerate

    assign init_done = &mem_init_done;

    generate
        if (NUM_SLICES > 1) begin : g__slice_arb
            // -----------------------------
            // (Local) parameters
            // -----------------------------
            localparam int SLICE_SEL_WID = $clog2(NUM_SLICES);

            // -----------------------------
            // (Local) signals
            // -----------------------------
            logic                     alloc_q_wr_rdy;
            logic                     alloc_q_wr;
            logic [PTR_WID-1:0]       alloc_q_wr_ptr;
            logic [SLICE_SEL_WID-1:0] alloc_slice_sel;
            logic [NUM_SLICES-1:0]    alloc_slice_grant;

            logic                     alloc;
            logic                     alloc_fail;
            logic                     alloc_err     [NUM_SLICES];
            logic [SLICE_PTR_WID-1:0] alloc_err_ptr [NUM_SLICES];

            logic                     dealloc_q_rd;
            logic                     dealloc_q_rd_ack;
            logic [PTR_WID-1:0]       dealloc_q_rd_ptr;
            logic [SLICE_SEL_WID-1:0] dealloc_slice_sel;

            logic [SLICE_SEL_WID-1:0] dealloc         [NUM_SLICES];
            logic                     dealloc_fail;
            logic                     dealloc_err     [NUM_SLICES];
            logic [SLICE_PTR_WID-1:0] dealloc_err_ptr [NUM_SLICES];

            logic                     alloc_dealloc_sel_n;
            logic [SLICE_SEL_WID-1:0] mon_slice_sel;
            logic [PTR_WID-1:0]       err_ptr;

            // Allocation queue
            fifo_sync    #(
                .DATA_WID ( PTR_WID ),
                .DEPTH    ( NUM_SLICES ),
                .FWFT     ( 1 )
            ) i_alloc_q   (
                .clk,
                .srst,
                .wr_rdy  ( alloc_q_wr_rdy ),
                .wr      ( alloc_q_wr ),
                .wr_data ( alloc_q_wr_ptr ),
                .wr_count( ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( alloc_req ),
                .rd_ack  ( alloc_rdy ),
                .rd_data ( alloc_ptr ),
                .rd_count( ),
                .empty   ( ),
                .uflow   ( )
            );

            // Work-conserving round-robin arbiter
            arb_rr #(
                .MODE ( arb_pkg::WCRR ),
                .N    ( NUM_SLICES )
            ) i_arb_rr__ctxt (
                .clk,
                .srst,
                .en    ( 1'b1 ),
                .req   ( __alloc_rdy ),
                .grant ( alloc_slice_grant ),
                .ack   ( '1 ),
                .sel   ( alloc_slice_sel )
            );

            assign alloc_q_wr     = __alloc_rdy[alloc_slice_sel];
            assign alloc_q_wr_ptr = __alloc_ptr[alloc_slice_sel] << SLICE_SEL_WID | alloc_slice_sel;
            assign __alloc_req = alloc_slice_grant & {NUM_SLICES{alloc_q_wr_rdy}};

            assign alloc = alloc_req && alloc_rdy;
            assign alloc_fail = ALLOC_FC ? 1'b0 : alloc_req && !alloc_rdy;

            // Deallocation queue
            fifo_sync    #(
                .DATA_WID ( PTR_WID ),
                .DEPTH    ( NUM_SLICES ),
                .FWFT     ( 1 )
            ) i_dealloc_q   (
                .clk,
                .srst,
                .wr_rdy  ( dealloc_rdy ),
                .wr      ( dealloc_req ),
                .wr_data ( dealloc_ptr ),
                .wr_count( ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( dealloc_q_rd ),
                .rd_ack  ( dealloc_q_rd_ack ),
                .rd_data ( dealloc_q_rd_ptr ),
                .rd_count( ),
                .empty   ( ),
                .uflow   ( )
            );

            assign dealloc_slice_sel = dealloc_q_rd_ptr[SLICE_SEL_WID-1:0];
            assign __dealloc_ptr = dealloc_q_rd_ptr >> SLICE_SEL_WID;
            assign dealloc_q_rd = __dealloc_rdy[dealloc_slice_sel];
            always_comb begin
                for (int i = 0; i < NUM_SLICES; i++) begin
                    if (i == dealloc_slice_sel) __dealloc_req[i] = dealloc_q_rd_ack;
                    else                        __dealloc_req[i] = 1'b0;
                end
            end

            assign dealloc_fail = DEALLOC_FC ? 1'b0 : dealloc_req && !dealloc_rdy;

            // Mux monitor signals from independent slices into single context
            for (genvar g_slice = 0; g_slice < NUM_SLICES; g_slice++) begin : g__slice
                initial begin
                    dealloc    [g_slice] = '0;
                    alloc_err  [g_slice] = 1'b0;
                    dealloc_err[g_slice] = 1'b0;
                end
                always @(posedge clk) begin
                    if (srst) begin
                        dealloc    [g_slice] <= '0;
                        alloc_err  [g_slice] <= 1'b0;
                        dealloc_err[g_slice] <= 1'b0;
                    end else begin
                        // Dealloc
                        if (__mon_if[g_slice].dealloc) dealloc[g_slice]                        <= dealloc[g_slice] + 1;
                        if (dealloc[g_slice] > 0 && mon_slice_sel == g_slice) dealloc[g_slice] <= dealloc[g_slice] - 1;
                        // Alloc errors
                        if (__mon_if[g_slice].alloc_err)   alloc_err  [g_slice] <= 1'b1;
                        else if ( alloc_dealloc_sel_n && mon_slice_sel == g_slice) alloc_err  [g_slice] <= 1'b0;
                        // Dealloc errors
                        if (__mon_if[g_slice].dealloc_err) dealloc_err[g_slice] <= 1'b1;
                        else if (!alloc_dealloc_sel_n && mon_slice_sel == g_slice) dealloc_err[g_slice] <= 1'b0;
                    end
                end

                always_ff @(posedge clk) begin
                    for (int i = 0; i < NUM_SLICES; i++) begin
                        if (__mon_if[g_slice].alloc_err)   alloc_err_ptr  [g_slice] <= __mon_if[g_slice].ptr;
                        if (__mon_if[g_slice].dealloc_err) dealloc_err_ptr[g_slice] <= __mon_if[g_slice].ptr;
                    end
                end
            end : g__slice

            // Send either alloc_err or dealloc_err on any given clock cycle
            initial alloc_dealloc_sel_n = 1'b0;
            always @(posedge clk) alloc_dealloc_sel_n <= !alloc_dealloc_sel_n;

            initial mon_slice_sel = 0;
            always @(posedge clk) if (alloc_dealloc_sel_n) mon_slice_sel <= mon_slice_sel + 1;

            always_comb begin
                if (alloc_dealloc_sel_n) err_ptr = alloc_err_ptr  [mon_slice_sel] << SLICE_SEL_WID | mon_slice_sel;
                else                     err_ptr = dealloc_err_ptr[mon_slice_sel] << SLICE_SEL_WID | mon_slice_sel;
            end

            always_ff @(posedge clk) begin
                mon_if.alloc        <= alloc;
                mon_if.alloc_fail   <= alloc_fail;
                mon_if.alloc_err    <= alloc_dealloc_sel_n && alloc_err[mon_slice_sel];
                mon_if.dealloc      <= dealloc[mon_slice_sel] > 0;
                mon_if.dealloc_fail <= dealloc_fail;
                mon_if.dealloc_err  <= !alloc_dealloc_sel_n && dealloc_err[mon_slice_sel];
                mon_if.ptr          <= err_ptr;
            end
        end : g__slice_arb
        else begin : g__single_slice
            assign __alloc_req[0] = alloc_req;
            assign alloc_rdy = __alloc_rdy[0];
            assign alloc_ptr = __alloc_ptr[0];

            assign __dealloc_req[0] = dealloc_req;
            assign __dealloc_ptr = dealloc_ptr;
            assign dealloc_rdy = __dealloc_rdy[0];

            alloc_mon_intf_connector i_alloc_mon_intf_connector (
                .from_tx ( __mon_if[0] ),
                .to_rx   ( mon_if )
            );
        end : g__single_slice
    endgenerate

endmodule : alloc_bv
