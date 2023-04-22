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
module state_allocator_bv #(
    parameter type ID_T = logic[7:0],
    parameter int  NUM_IDS = 2**$bits(ID_T),
    parameter bit  ALLOC_FC = 1'b1,   // Can flow control alloc interface,
                                      // i.e. requester waits on alloc_rdy
    parameter bit  DEALLOC_FC = 1'b1, // Can flow control dealloc interface,
                                      // i.e. requester waits on dealloc_rdy
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
) (
    // Clock/reset
    input logic   clk,
    input logic   srst,

    output logic  init_done,

    input  logic  en,

    // Allocate interface
    input  logic  alloc_req,
    output logic  alloc_rdy,
    output ID_T   alloc_id,

    // Deallocate interface
    input  logic  dealloc_req,
    output logic  dealloc_rdy,
    input  ID_T   dealloc_id,

    // Errors
    output logic  err_alloc,
    output logic  err_dealloc,
    output ID_T   err_id,

    // AXI-L control/monitoring
    axi4l_intf.peripheral axil_if
);

    // -----------------------------
    // Imports
    // -----------------------------
    import state_allocator_reg_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int NUM_COLS = NUM_IDS > 65536 ? NUM_IDS / 4096 :
                              NUM_IDS > 16    ? 16 : 1;
    localparam int NUM_ROWS = NUM_IDS / NUM_COLS;

    // Check that width of ID field is sufficient to describe specified number of IDs
    initial assert(2**$bits(ID_T) >= NUM_IDS) else $fatal(1, "ID field too narrow.");

    // Check for valid decomposition of pointers into rows/columns
    initial assert(NUM_IDS == NUM_COLS * NUM_ROWS) else $fatal(1, "Dimensioning error in pointer array.");

    localparam int COL_WID = $clog2(NUM_COLS);
    localparam int ROW_WID = $clog2(NUM_ROWS);

    localparam int ID_CNT_WID = $clog2(NUM_IDS + 1);

    localparam int MEM_RD_LATENCY = mem_pkg::get_default_rd_latency(NUM_ROWS, NUM_COLS);

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
    } id_addr_t;

    typedef struct packed {
        logic valid;
        logic scan;
    } rd_ctxt_t;

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_intf #(.ADDR_WID (ROW_WID), .DATA_WID(NUM_COLS)) mem_wr_if (.clk (clk));
    mem_intf #(.ADDR_WID (ROW_WID), .DATA_WID(NUM_COLS)) mem_rd_if (.clk (clk));

    axi4l_intf #() axil_if__clk ();

    state_allocator_reg_intf reg_if ();

    // -----------------------------
    // Signals
    // -----------------------------
    logic local_srst;
    logic __en;

    state_t state;
    state_t nxt_state;

    logic rd_rdy;
    logic rd;
    logic modify;
    logic wr;
    logic rd_ack;
    logic done;
    logic error;

    mem_data_t rd_data;
    mem_data_t wr_data;

    rd_ctxt_t     rd_ctxt_in;
    rd_ctxt_t     rd_ctxt_out;

    mem_data_t colmask;
    id_addr_t  id;
    logic      modify_err;

    // Alloc FIFO
    logic       alloc_q_wr;
    ID_T        alloc_q_wr_data;
    logic       alloc_q_full;
    logic       alloc_q_empty;
    logic       alloc_q_uflow;

    logic       alloc;
    logic       alloc_fail;

    logic       __alloc;
    id_addr_t   __alloc_id;

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


    // Deallocation FIFO
    logic      dealloc_q_full;
    logic      dealloc_q_rd;
    ID_T       dealloc_q_rd_data;
    logic      dealloc_q_empty;
    logic      dealloc_q_oflow;

    logic      dealloc;
    logic      dealloc_fail;

    logic      __dealloc;
    id_addr_t  __dealloc_id;


    reg_status_flags_t status_flags;

    // -----------------------------
    // Register block
    // -----------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    state_allocator_reg_blk i_state_allocator_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    // Export parameterization info to regmap
    assign reg_if.info_size_nxt_v = 1'b1;
    assign reg_if.info_size_nxt = NUM_IDS;

    // Block-level reset control
    initial local_srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) local_srst <= 1'b1;
        else                              local_srst <= 1'b0;
    end

    // Enable
    always_ff @(posedge clk) __en <= en && reg_if.control.enable;

    // Report status
    assign reg_if.status_nxt_v = 1'b1;
    always_ff @(posedge clk) begin
        reg_if.status_nxt.reset <= local_srst;
        reg_if.status_nxt.init_done <= init_done;
        reg_if.status_nxt.enabled <= __en;
    end

    // Flags
    initial status_flags = '0;
    always @(posedge clk) begin
        if (local_srst)                      status_flags <= '0;
        else if (reg_if.status_flags_rd_evt) status_flags <= '0;
        else begin
            if (err_alloc)    status_flags.alloc_err    <= 1'b1;
            if (err_dealloc)  status_flags.dealloc_err  <= 1'b1;
        end
    end
    assign reg_if.status_flags_nxt_v = 1'b1;
    assign reg_if.status_flags_nxt = status_flags;

    // -----------------------------
    // Memory
    // -----------------------------
    mem_ram_sdp_sync #(
        .ADDR_WID  ( ROW_WID ),
        .DATA_WID  ( NUM_COLS ),
        .RESET_FSM ( 1 ),
        .RESET_VAL ( {NUM_COLS{1'b1}} ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp_sync (
        .clk       ( clk ),
        .srst      ( local_srst ),
        .init_done ( init_done ),
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

    assign mem_wr_if.rst = 1'b0;
    assign mem_wr_if.en  = init_done;
    assign mem_wr_if.req = wr;
    assign mem_wr_if.addr = id.row;
    assign mem_wr_if.data = wr_data;

    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.en = init_done;
    assign mem_rd_if.req = rd || scan_rd;
    assign mem_rd_if.addr = rd ? id.row : scan_row;

    assign rd_rdy      = mem_rd_if.rdy;
    assign scan_rd_rdy = mem_rd_if.rdy && !rd;

    // Synthesize read acknowledgement based on read latency of memory implementation
    assign rd_ctxt_in.valid = mem_rd_if.req;
    assign rd_ctxt_in.scan = !rd;

    util_delay   #(
        .DATA_T   ( rd_ctxt_t ),
        .DELAY    ( MEM_RD_LATENCY )
    ) i_rd_ack_delay (
        .clk      ( clk ),
        .srst     ( 1'b0 ),
        .data_in  ( rd_ctxt_in ),
        .data_out ( rd_ctxt_out )
    );

    assign rd_ack      = rd_ctxt_out.valid && !rd_ctxt_out.scan;
    assign scan_rd_ack = rd_ctxt_out.valid &&  rd_ctxt_out.scan;

    // -----------------------------
    // Allocation queue
    // -----------------------------
    fifo_sync #(
        .DATA_T  ( ID_T ),
        .DEPTH   ( 32 ),
        .FWFT    ( 1 )
    ) i_alloc_q  (
        .clk     ( clk ),
        .srst    ( local_srst ),
        .wr      ( alloc_q_wr ),
        .wr_data ( alloc_q_wr_data ),
        .wr_count( ),
        .full    ( alloc_q_full ),
        .oflow   ( ),
        .rd      ( alloc ),
        .rd_ack  ( ),
        .rd_data ( alloc_id ),
        .rd_count( ),
        .empty   ( alloc_q_empty ),
        .uflow   ( alloc_q_uflow )
    );

    assign alloc_rdy = __en && !alloc_q_empty;
    assign alloc = alloc_req && alloc_rdy;
    assign alloc_fail = ALLOC_FC ? 1'b0 : alloc_req && !alloc_rdy;
    assign alloc_q_wr_data = {0, __alloc_id};

    // -----------------------------
    // Deallocation queue
    // -----------------------------
    fifo_sync #(
        .DATA_T   ( ID_T ),
        .DEPTH    ( 32 ),
        .FWFT     ( 1 )
    ) i_dealloc_q (
        .clk      ( clk ),
        .srst     ( local_srst ),
        .wr       ( dealloc_req && dealloc_rdy ),
        .wr_data  ( dealloc_id ),
        .wr_count ( ),
        .full     ( dealloc_q_full ),
        .oflow    ( dealloc_q_oflow ),
        .rd       ( dealloc_q_rd ),
        .rd_ack   ( ),
        .rd_data  ( dealloc_q_rd_data ),
        .rd_count ( ),
        .empty    ( dealloc_q_empty ),
        .uflow    ( )
    );

    assign dealloc_rdy = __en && !dealloc_q_full;
    assign dealloc = done && __dealloc;
    assign dealloc_fail = DEALLOC_FC ? 1'b0 : dealloc_req && !dealloc_rdy;
    assign __dealloc_id = dealloc_q_rd_data;

    // -----------------------------
    // Main FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (local_srst) state <= RESET;
        else            state <= nxt_state;
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
                if (init_done) nxt_state = IDLE;
            end
            IDLE : begin
                if (!dealloc_q_empty) nxt_state = DEALLOC;
                else if (reg_if.control.allocate_en && !alloc_q_full && scan_done) nxt_state = ALLOC;
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
            id        <= __dealloc_id;
        end else if (state == ALLOC) begin
            __alloc   <= 1'b1;
            __dealloc <= 1'b0;
            id        <= __alloc_id;
        end
    end

    always @(posedge clk) if (rd) colmask <= (1'b1 << id.col);

    // Latch read data
    always_ff @(posedge clk) if (rd_ack) rd_data <= mem_rd_if.data;

    // Set/clear bit in vector corresponding to pointer
    always_ff @(posedge clk) if (modify) wr_data <= (rd_data & ~colmask) | ({NUM_COLS{__dealloc}} & colmask);

    // Error is detected when new state is the same as the existing state
    // (i.e. pointer to allocate already allocated, pointer to deallocate already deallocated)
    always_comb begin
        modify_err = 1'b0;
        if (__dealloc == rd_data[id.col]) modify_err = 1'b1;
    end

    // -----------------------------
    // Scan FSM (finds unallocated pointers)
    // -----------------------------
    initial scan_state = SCAN_RESET;
    always @(posedge clk) begin
        if (local_srst) scan_state <= SCAN_RESET;
        else            scan_state <= nxt_scan_state;
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
                if (init_done) nxt_scan_state = SCAN_IDLE;
            end
            SCAN_IDLE : begin
                if (reg_if.control.scan_en) nxt_scan_state = SCAN_RD_REQ;
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

    // Poll state
    initial scan_row = 0;
    always @(posedge clk) begin
        if (reset_scan_row)    scan_row <= 0;
        else if (inc_scan_row) scan_row <= scan_row + 1;
    end

    // Flow-id vector
    always_ff @(posedge clk) begin
        // Latch on read
        if (scan_rd_ack)    scan_vec <= mem_rd_if.data;
        else if (scan_done) scan_vec[scan_col] <= 1'b0;
    end

    // Check scan read data for unallocated pointers
    always_comb begin
        scan_hit = 1'b0;
        __scan_col = 0;
        for (int i = 0; i < NUM_COLS; i++) begin
            // Allocate in ascending order
            automatic int col = NUM_COLS-1-i;
            if (scan_vec[col]) begin
                scan_hit = 1'b1;
                __scan_col = col;
            end
        end
    end

    // Latch column
    always_ff @(posedge clk) if (scan_check) scan_col <= __scan_col;

    // Assign next pointer to be allocated from scan result
    assign __alloc_id.row = scan_row;
    assign __alloc_id.col = scan_col;

    // ----------------------------------
    // Error reporting
    // ----------------------------------
    assign err_alloc   = error && __alloc;
    assign err_dealloc = error && __dealloc;
    assign err_id      = id;

    // ----------------------------------
    // Debug status
    // ----------------------------------
    // State
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state = state;
    // Scan state
    assign reg_if.dbg_status_scan_nxt_v = 1'b1;
    assign reg_if.dbg_status_scan_nxt.state = scan_state;

    // Latch value of pointer on error
    assign reg_if.dbg_err_id_nxt_v = err_alloc || err_dealloc;
    assign reg_if.dbg_err_id_nxt = err_id;

    // Counters
    // -- function-level reset
    logic dbg_cnt_reset;
    initial dbg_cnt_reset = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset || reg_if.dbg_control.clear_counts) dbg_cnt_reset <= 1'b1;
        else                                                                 dbg_cnt_reset <= 1'b0;
    end
    always_comb begin
        // Default is no update
        reg_if.dbg_cnt_active_nxt_v       = 1'b0;
        reg_if.dbg_cnt_alloc_nxt_v        = 1'b0;
        reg_if.dbg_cnt_alloc_fail_nxt_v   = 1'b0;
        reg_if.dbg_cnt_dealloc_nxt_v      = 1'b0;
        reg_if.dbg_cnt_dealloc_fail_nxt_v = 1'b0;
        reg_if.dbg_cnt_dealloc_err_nxt_v  = 1'b0;
        // Next counter values (default to previous counter values)
        reg_if.dbg_cnt_active_nxt       = reg_if.dbg_cnt_active;
        reg_if.dbg_cnt_alloc_nxt        = reg_if.dbg_cnt_alloc;
        reg_if.dbg_cnt_alloc_fail_nxt   = reg_if.dbg_cnt_alloc_fail;
        reg_if.dbg_cnt_dealloc_nxt      = reg_if.dbg_cnt_dealloc;
        reg_if.dbg_cnt_dealloc_fail_nxt = reg_if.dbg_cnt_dealloc_fail;
        reg_if.dbg_cnt_dealloc_err_nxt  = reg_if.dbg_cnt_dealloc_err;
        if (dbg_cnt_reset) begin
            // Update on reset/clear
            reg_if.dbg_cnt_active_nxt_v       = 1'b1;
            reg_if.dbg_cnt_alloc_nxt_v        = 1'b1;
            reg_if.dbg_cnt_alloc_fail_nxt_v   = 1'b1;
            reg_if.dbg_cnt_dealloc_nxt_v      = 1'b1;
            reg_if.dbg_cnt_dealloc_fail_nxt_v = 1'b1;
            reg_if.dbg_cnt_dealloc_err_nxt_v  = 1'b1;
            // Clear counts
            reg_if.dbg_cnt_active_nxt       = 0;
            reg_if.dbg_cnt_alloc_nxt        = 0;
            reg_if.dbg_cnt_alloc_fail_nxt   = 0;
            reg_if.dbg_cnt_dealloc_nxt      = 0;
            reg_if.dbg_cnt_dealloc_fail_nxt = 0;
            reg_if.dbg_cnt_dealloc_err_nxt  = 0;
        end else begin
            // Selectively update
            if (alloc ^ dealloc) reg_if.dbg_cnt_active_nxt_v       = 1'b1;
            if (alloc)           reg_if.dbg_cnt_alloc_nxt_v        = 1'b1;
            if (alloc_fail)      reg_if.dbg_cnt_alloc_fail_nxt_v   = 1'b1;
            if (dealloc)         reg_if.dbg_cnt_dealloc_nxt_v      = 1'b1;
            if (dealloc_fail)    reg_if.dbg_cnt_dealloc_fail_nxt_v = 1'b1;
            if (err_dealloc)     reg_if.dbg_cnt_dealloc_err_nxt_v  = 1'b1;
            // Increment-by-one counters
            reg_if.dbg_cnt_alloc_nxt        = reg_if.dbg_cnt_alloc        + 1;
            reg_if.dbg_cnt_alloc_fail_nxt   = reg_if.dbg_cnt_alloc_fail   + 1;
            reg_if.dbg_cnt_dealloc_nxt      = reg_if.dbg_cnt_dealloc      + 1;
            reg_if.dbg_cnt_dealloc_fail_nxt = reg_if.dbg_cnt_dealloc_fail + 1;
            reg_if.dbg_cnt_dealloc_err_nxt  = reg_if.dbg_cnt_dealloc_err  + 1;
            // Increment/decrement counters
            if (alloc)        reg_if.dbg_cnt_active_nxt = reg_if.dbg_cnt_active + 1;
            else if (dealloc) reg_if.dbg_cnt_active_nxt = reg_if.dbg_cnt_active - 1;
        end
    end

endmodule : state_allocator_bv
