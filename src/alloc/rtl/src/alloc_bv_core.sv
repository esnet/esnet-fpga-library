// Pointer allocator with the list of allocated/unallocated pointers maintained
// as a bit vector in RAM. For allocating from large pools his implementation is
// more resource-efficient than e.g. a FIFO implementation, at the cost of a
// reduced (sustained) rate of allocation/deallocation.
//
// Also, the allocation time is proportional to the number of pointers available
// to be allocated, i.e. as available pointers become sparse it may be necessary
// to scan the entire memory to find one that can be allocated.
//
// Deallocation time is constant.
//
// Allocation
// ----------
// A scan FSM searches the state memory one vector at a time, searching for
// unallocated pointers. When an available pointer is found, the corresponding bit
// in the bit vector is cleared (to indicate unavailable or allocated) and the
// pointer value is written into the allocation FIFO. The application pulls new
// pointers as needed from this FIFO.
//
// Deallocation
// ------------
// The application deallocates a pointer by pushing it into the deallocation FIFO.
// The allocator FSM pulls values from this FIFO and sets the corresponding bit in
// the bit vector (to indicate available or unallocated).

module alloc_bv_core #(
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
    parameter int  MEM_RD_LATENCY = 8    // Read latency (or max read latency) for memory
                                         // (used for sizing context FIFO)
) (
    // Clock/reset
    input logic                clk,
    input logic                srst,

    // Control
    input  logic               en,
    input  logic               scan_en,

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
    alloc_mon_intf.tx          mon_if,

    // Memory interface
    mem_wr_intf.controller     mem_wr_if,
    mem_rd_intf.controller     mem_rd_if,
    input logic                mem_init_done
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int MAX_PTRS = 2**PTR_WID;
    localparam int NUM_COLS = mem_wr_if.DATA_WID;
    localparam int NUM_ROWS = MAX_PTRS/NUM_COLS;

    localparam int COL_WID = $clog2(NUM_COLS);
    localparam int ROW_WID = $clog2(NUM_ROWS);
    localparam int CNT_WID  = PTR_WID + 1;

    // -----------------------------
    // Parameter checks
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_rd_if.DATA_WID, NUM_COLS, "mem_if.DATA_WID");
        std_pkg::param_check_gt(mem_wr_if.ADDR_WID, ROW_WID, "mem_if.ADDR_WID");
        std_pkg::param_check_gt(mem_wr_if.ADDR_WID, ROW_WID, "mem_if.ADDR_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [NUM_COLS-1:0] mem_data_t;

    typedef enum logic [3:0] {
        RESET,
        IDLE,
        ALLOC,
        DEALLOC,
        RD_REQ,
        RD_WAIT,
        MODIFY,
        WR,
        DONE,
        ERROR
    } state_t;

    typedef enum logic [2:0] {
        SCAN_RESET,
        SCAN_IDLE,
        SCAN_RD_REQ,
        SCAN_RD_WAIT,
        SCAN_CHECK,
        SCAN_NEXT,
        SCAN_DONE
    } scan_state_t;

    typedef struct packed {
        logic [ROW_WID-1:0] row;
        logic [COL_WID-1:0] col;
    } ptr_addr_t;

    typedef struct packed {
        logic scan;
    } rd_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic wr;
    logic wr_rdy;
    logic wr_ack;
    logic rd;
    logic rd_rdy;
    logic rd_ack;
    logic modify;
    logic done;
    logic error;

    mem_data_t rd_data;
    mem_data_t wr_data;

    rd_ctxt_t  rd_ctxt_in;
    rd_ctxt_t  rd_ctxt_out;

    mem_data_t colmask;
    ptr_addr_t ptr;
    logic      modify_err;

    ptr_addr_t last_ptr;

    // Alloc FIFO
    logic               alloc_q_wr;
    logic               alloc_q_wr_rdy;
    logic [PTR_WID-1:0] alloc_q_wr_data;

    logic               alloc;
    logic               alloc_fail;
    logic               alloc_err;
    logic [PTR_WID-1:0] alloc_err_ptr;

    logic       __alloc;
    ptr_addr_t  __alloc_ptr;

    // Dealloc FIFO
    logic               dealloc_q_rd;
    logic               dealloc_q_rd_rdy;
    logic [PTR_WID-1:0] dealloc_q_rd_data;

    logic               dealloc;
    logic               dealloc_fail;
    logic               dealloc_err;
    logic [PTR_WID-1:0] dealloc_err_ptr;

    logic      __dealloc;
    ptr_addr_t __dealloc_ptr;

    // Scan FSM
    scan_state_t scan_state;
    scan_state_t nxt_scan_state;

    logic      scan_rd_rdy;
    logic      scan_rd;
    logic      scan_rd_ack;
    logic      scan_check;
    mem_data_t scan_vec;
    logic      scan_hit;
    logic      scan_done;

    logic [ROW_WID-1:0] scan_row;
    logic               reset_scan_row;
    logic               inc_scan_row;
    logic [COL_WID-1:0] __scan_col;
    logic [COL_WID-1:0] scan_col;

    // -----------------------------
    // Allocation queue
    // -----------------------------
    fifo_sync    #(
        .DATA_WID ( PTR_WID ),
        .DEPTH    ( ALLOC_Q_DEPTH ),
        .FWFT     ( 1 )
    ) i_alloc_q   (
        .clk,
        .srst,
        .wr_rdy  ( alloc_q_wr_rdy ),
        .wr      ( alloc_q_wr ),
        .wr_data ( alloc_q_wr_data ),
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

    assign alloc = alloc_req && alloc_rdy;
    assign alloc_fail = ALLOC_FC ? 1'b0 : alloc_req && !alloc_rdy;
    assign alloc_q_wr_data = {'0, __alloc_ptr};

    // -----------------------------
    // Deallocation queue
    // -----------------------------
    fifo_sync    #(
        .DATA_WID ( PTR_WID ),
        .DEPTH    ( DEALLOC_Q_DEPTH ),
        .FWFT     ( 1 )
    ) i_dealloc_q (
        .clk,
        .srst,
        .wr_rdy   ( dealloc_rdy ),
        .wr       ( dealloc_req ),
        .wr_data  ( dealloc_ptr ),
        .wr_count ( ),
        .full     ( ),
        .oflow    ( ),
        .rd       ( dealloc_q_rd ),
        .rd_ack   ( dealloc_q_rd_rdy ),
        .rd_data  ( dealloc_q_rd_data ),
        .rd_count ( ),
        .empty    ( ),
        .uflow    ( )
    );

    assign dealloc = done && __dealloc;
    assign dealloc_fail = DEALLOC_FC ? 1'b0 : dealloc_req && !dealloc_rdy;
    assign __dealloc_ptr = dealloc_q_rd_data;

    // -----------------------------
    // Drive memory interface
    // -----------------------------
    assign mem_wr_if.rst = srst;
    assign mem_wr_if.en = 1'b1;
    assign mem_wr_if.req = wr;
    assign mem_wr_if.addr = ptr.row;
    assign mem_wr_if.data = wr_data;
    assign wr_ack = mem_wr_if.ack;
    assign wr_rdy = mem_wr_if.rdy;

    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.req = rd || scan_rd;
    assign mem_rd_if.addr = rd ? ptr.row : scan_row;
    assign rd_rdy = mem_rd_if.rdy;
    assign scan_rd_rdy = mem_rd_if.rdy && !rd;

    // Read context
    // (need to distinguish between read operations for alloc/dealloc
    //  and read operations occuring during scanning)
    assign rd_ctxt_in.scan = !rd;

    fifo_small_ctxt #(
        .DATA_WID ( $bits(rd_ctxt_t) ),
        .DEPTH    ( MEM_RD_LATENCY )
    ) i_fifo_small_ctxt__rd_ctxt (
        .clk,
        .srst,
        .wr_rdy  ( ),
        .wr      ( mem_rd_if.req && mem_rd_if.rdy ),
        .wr_data ( rd_ctxt_in ),
        .rd      ( mem_rd_if.ack ),
        .rd_vld  ( ),
        .rd_data ( rd_ctxt_out ),
        .oflow   (),
        .uflow   ()
    );
    assign rd_ack      = mem_rd_if.ack && !rd_ctxt_out.scan;
    assign scan_rd_ack = mem_rd_if.ack &&  rd_ctxt_out.scan;

    // -----------------------------
    // Main FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        dealloc_q_rd = 1'b0;
        alloc_q_wr = 1'b0;
        rd = 1'b0;
        modify = 1'b0;
        wr = 1'b0;
        error = 1'b0;
        done = 1'b0;
        case (state)
            RESET : begin
                if (mem_init_done) nxt_state = IDLE;
            end
            IDLE : begin
                if (dealloc_q_rd_rdy) nxt_state = DEALLOC;
                else if (en && alloc_q_wr_rdy && scan_done) nxt_state = ALLOC;
            end
            DEALLOC : begin
                dealloc_q_rd = 1'b1;
                nxt_state = RD_REQ;
            end
            ALLOC : begin
                alloc_q_wr = 1'b1;
                nxt_state = RD_REQ;
            end
            RD_REQ : begin
                rd = 1'b1;
                if (rd_rdy) nxt_state = RD_WAIT;
            end
            RD_WAIT : begin
                if (rd_ack) nxt_state = MODIFY;
            end
            MODIFY : begin
                modify = 1'b1;
                if (modify_err) nxt_state = ERROR;
                else            nxt_state = WR;
            end
            WR : begin
                wr = 1'b1;
                nxt_state = DONE;
            end
            DONE : begin
                done = 1'b1;
                nxt_state = IDLE;
            end
            ERROR : begin
                error = 1'b1;
                nxt_state = IDLE;
            end
            default : begin
                nxt_state = RESET;
            end
        endcase
    end

    // Latch set/clear
    always_ff @(posedge clk) begin
        if (state == DEALLOC) begin
            __alloc   <= 1'b0;
            __dealloc <= 1'b1;
            ptr       <= __dealloc_ptr;
        end else if (state == ALLOC) begin
            __alloc   <= 1'b1;
            __dealloc <= 1'b0;
            ptr       <= __alloc_ptr;
        end
    end

    always @(posedge clk) if (rd) colmask <= (1'b1 << ptr.col);

    // Latch read data
    always_ff @(posedge clk) if (rd_ack) rd_data <= mem_rd_if.data;

    // Set/clear bit in vector corresponding to pointer
    always_ff @(posedge clk) if (modify) wr_data <= (rd_data & ~colmask) | ({NUM_COLS{__alloc}} & colmask);

    // Error is detected when new state is the same as the existing state
    // (i.e. pointer to allocate already allocated, pointer to deallocate already deallocated)
    always_comb begin
        modify_err = 1'b0;
        if (__alloc == rd_data[ptr.col]) modify_err = 1'b1;
    end

    // -----------------------------
    // Scan FSM (finds unallocated pointers)
    // -----------------------------
    initial scan_state = SCAN_RESET;
    always @(posedge clk) begin
        if (srst) scan_state <= SCAN_RESET;
        else      scan_state <= nxt_scan_state;
    end

    always_comb begin
        nxt_scan_state = scan_state;
        reset_scan_row = 1'b0;
        inc_scan_row = 1'b0;
        scan_rd = 1'b0;
        scan_check = 1'b0;
        scan_done = 1'b0;
        case (scan_state)
            SCAN_RESET : begin
                reset_scan_row = 1'b1;
                if (mem_init_done) nxt_scan_state = SCAN_IDLE;
            end
            SCAN_IDLE : begin
                if (scan_en) nxt_scan_state = SCAN_RD_REQ;
            end
            SCAN_RD_REQ : begin
                scan_rd = 1'b1;
                if (scan_rd_rdy) nxt_scan_state = SCAN_RD_WAIT;
            end
            SCAN_RD_WAIT : begin
                if (scan_rd_ack) nxt_scan_state = SCAN_CHECK;
            end
            SCAN_CHECK : begin
                scan_check = 1'b1;
                if (scan_hit) nxt_scan_state = SCAN_DONE;
                else          nxt_scan_state = SCAN_NEXT;
            end
            SCAN_NEXT : begin
                inc_scan_row = 1'b1;
                nxt_scan_state = SCAN_IDLE;
            end
            SCAN_DONE : begin
                scan_done = 1'b1;
                if (state == ALLOC) nxt_scan_state = SCAN_CHECK;
            end
            default : begin
                nxt_scan_state = SCAN_RESET;
            end
        endcase
    end

    // Determine (bit) address of last pointer
    always_ff @(posedge clk) begin
        if (PTRS == '0) last_ptr <= MAX_PTRS-1;
        else            last_ptr <= PTRS-1;
    end

    // Poll state
    initial scan_row = 0;
    always @(posedge clk) begin
        if (reset_scan_row)    scan_row <= 0;
        else if (inc_scan_row) scan_row <= scan_row < last_ptr.row ? scan_row + 1 : 0;
    end

    // Pointer vector
    always_ff @(posedge clk) begin
        // Latch on read
        if (scan_rd_ack)    scan_vec <= mem_rd_if.data;
        else if (scan_done) scan_vec[scan_col] <= 1'b1;
    end

    // Check scan read data for unallocated pointers
    always_comb begin
        scan_hit = 1'b0;
        __scan_col = 0;
        for (int i = 0; i < NUM_COLS; i++) begin
            // Allocate in ascending order
            automatic int col = NUM_COLS-1-i;
            if (!scan_vec[col]) begin
                if (scan_row < last_ptr.row || col <= last_ptr.col) begin
                    scan_hit = 1'b1;
                    __scan_col = col;
                end
            end
        end
    end

    // Latch column
    always_ff @(posedge clk) if (scan_check) scan_col <= __scan_col;

    // Assign next pointer to be allocated from scan result
    assign __alloc_ptr.row = scan_row;
    assign __alloc_ptr.col = scan_col;

    // ----------------------------------
    // Monitoring
    // ----------------------------------
    assign alloc_err = error && __alloc;
    assign dealloc_err = error && __dealloc;

    assign mon_if.alloc           = alloc;
    assign mon_if.alloc_fail      = alloc_fail;
    assign mon_if.alloc_err       = alloc_err;
    assign mon_if.dealloc         = dealloc;
    assign mon_if.dealloc_fail    = dealloc_fail;
    assign mon_if.dealloc_err     = dealloc_err;
    assign mon_if.ptr             = {'0, ptr};

endmodule : alloc_bv_core
