// Linked-list allocator
module alloc_ll_core #(
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

    // Allocator monitor
    alloc_mon_intf.tx               mon_if
);

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef struct packed {
        logic [LIST_SEL_WID-1:0] ctxt;
        logic [PTR_WID-1:0]  nxt;
        logic [META_WID-1:0] meta;
    } list_item_t;
    localparam int LIST_ITEM_WID = $bits(list_item_t);

    typedef struct packed {
        logic [PTR_WID-1:0] head;
        logic [PTR_WID-1:0] tail;
        logic               rip; // Read in progress
    } list_ctxt_t;
    localparam int LIST_CTXT_WID = $bits(list_ctxt_t);

    typedef struct packed {
        logic                    nack;
        logic [LIST_SEL_WID-1:0] ctxt;
    } rd_ctxt_t;
    localparam int RD_CTXT_WID = $bits(rd_ctxt_t);

    typedef struct packed {
        logic [LIST_SEL_WID-1:0] ctxt;
        logic [PTR_WID-1:0]      head;
    } list_ctxt_update_t;
    localparam int LIST_CTXT_UPDATE_WID = $bits(list_ctxt_update_t);

    typedef enum logic[2:0] {
        INIT_RESET,
        INIT_PTR_REQ,
        INIT_WR_CTXT,
        INIT_NXT,
        INIT_DONE
    } init_state_t;

    typedef enum logic[2:0] {
        STORE_RESET,
        STORE_IDLE,
        STORE_RD_CTXT_REQ,
        STORE_CTXT_UPDATE,
        STORE_MEM_WR,
        STORE_DONE,
        STORE_NACK
    } store_state_t;

    typedef enum logic[2:0] {
        LOAD_RESET,
        LOAD_IDLE,
        LOAD_RD_CTXT_REQ,
        LOAD_CTXT_UPDATE_RIP,
        LOAD_MEM_RD,
        LOAD_DEALLOC,
        LOAD_DONE,
        LOAD_NACK
    } load_state_t;

    typedef enum logic[2:0] {
        LOAD_UPDATE_RESET,
        LOAD_UPDATE_IDLE,
        LOAD_UPDATE_RD_REQ,
        LOAD_UPDATE_WR_REQ,
        LOAD_UPDATE_DONE
    } load_update_state_t;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam mem_pkg::spec_t LIST_CTXT_MEM_SPEC = '{
        ADDR_WID  : LIST_SEL_WID,
        DATA_WID  : LIST_CTXT_WID,
        ASYNC     : 0,
        RESET_FSM : 0,
        OPT_MODE  : mem_pkg::OPT_MODE_LATENCY
    };

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check_gt(mem_wr_if.DATA_WID, LIST_ITEM_WID, "mem_wr_if.DATA_WID");
        std_pkg::param_check_gt(mem_rd_if.DATA_WID, LIST_ITEM_WID, "mem_rd_if.DATA_WID");
    end

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_wr_intf #(.ADDR_WID(LIST_SEL_WID), .DATA_WID(LIST_CTXT_WID)) ctxt_mem_wr_if (.clk);
    mem_rd_intf #(.ADDR_WID(LIST_SEL_WID), .DATA_WID(LIST_CTXT_WID)) ctxt_mem_rd_if (.clk);

    // -----------------------------
    // Signals
    // -----------------------------
    logic               alloc__init_done;

    logic               alloc_req;
    logic               alloc_rdy;
    logic [PTR_WID-1:0] alloc_ptr;

    logic               dealloc_req;
    logic               dealloc_rdy;
    logic [PTR_WID-1:0] dealloc_ptr;

    logic               ptr_vld;
    logic [PTR_WID-1:0] ptr;
    logic               ptr_ack;

    logic [1:0]         sel;

    init_state_t        init_state;
    init_state_t        nxt_init_state;

    logic [LIST_SEL_WID-1:0] init_idx;
    logic                    reset_init_idx;
    logic                    inc_init_idx;
    logic                    init_wr_req;
    list_ctxt_t              init_ctxt_wr_data;
    logic                    init_ptr_ack;

    store_state_t       store_state;
    store_state_t       nxt_store_state;

    logic               store_ctxt_wr_req;
    logic               store_ctxt_wr_rdy;
    logic               store_ctxt_wr;
    logic               store_ctxt_wr_thru;
    list_ctxt_t         store_ctxt_wr_data;
    list_ctxt_t         store_wr_ctxt;
    logic               store_ctxt_rd_req;
    logic               store_ctxt_rd_rdy;
    list_ctxt_t         store_ctxt_rd_data;
    list_ctxt_t         store_rd_ctxt;
    logic [LIST_SEL_WID-1:0] __store_list_sel;
    logic [META_WID-1:0]     __store_meta;

    load_state_t        load_state;
    load_state_t        nxt_load_state;

    logic               load_ctxt_wr_req;
    logic               load_ctxt_wr_rdy;
    logic               load_ctxt_wr;
    logic               load_ctxt_wr_thru;
    list_ctxt_t         load_ctxt_wr_data;
    list_ctxt_t         load_wr_ctxt;
    logic               load_ctxt_rd_req;
    logic               load_ctxt_rd_rdy;
    list_ctxt_t         load_ctxt_rd_data;
    list_ctxt_t         load_rd_ctxt;
    logic [LIST_SEL_WID-1:0] __load_list_sel;
    logic                    __load_nack;
    logic               load_done;

    list_item_t         mem_wr_data;
    list_item_t         mem_rd_data;

    logic               rd_ctxt_fifo__wr;
    rd_ctxt_t           rd_ctxt_fifo__wr_data;
    logic               rd_ctxt_fifo__wr_rdy;
    rd_ctxt_t           rd_ctxt_fifo__rd_data;
    logic               rd_ctxt_fifo__rd_vld;

    logic               rd_data_fifo__rd_vld;
    list_item_t         rd_data_fifo__rd_data;

    load_update_state_t load_update_state;
    load_update_state_t nxt_load_update_state;

    logic               load_update_ctxt_wr_req;
    logic               load_update_ctxt_wr_rdy;
    logic               load_update_ctxt_wr;
    logic               load_update_ctxt_wr_thru;
    list_ctxt_t         load_update_ctxt_wr_data;
    list_ctxt_t         load_update_wr_ctxt;
    logic               load_update_ctxt_rd_req;
    logic               load_update_ctxt_rd_rdy;
    list_ctxt_t         load_update_ctxt_rd_data;
    list_ctxt_t         load_update_rd_ctxt;
    logic [LIST_SEL_WID-1:0] __load_update_list_sel;

    logic               load_ctxt_fifo__wr_rdy;
    list_ctxt_update_t  load_ctxt_fifo__wr_data;
    logic               load_ctxt_fifo__rd;
    logic               load_ctxt_fifo__rd_vld;
    list_ctxt_update_t  load_ctxt_fifo__rd_data;

    // -----------------------------
    // Selector (three-state, alternating)
    // - used for simple arbitration
    // -----------------------------
    initial sel = 0;
    always @(posedge clk) sel <= sel < 2 ? sel + 1 : 0;

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
        .SIM__FAST_INIT  ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL  ( SIM__RAM_MODEL )
    ) i_alloc_bv__ptr (
        .clk,
        .srst,
        .en,
        .scan_en     ( 1'b1 ),
        .init_done   ( alloc__init_done ),
        .PTRS        ( BUFFERS ),
        .alloc_req,
        .alloc_rdy,
        .alloc_ptr,
        .dealloc_req,
        .dealloc_rdy,
        .dealloc_ptr,
        .mon_if
    );

    // Prefetch pairs of pointers for allocation on store
    fifo_ctxt #(
        .DATA_WID ( PTR_WID ),
        .DEPTH ( 16 ),
        .REPORT_OFLOW ( 0 )
    ) i_fifo_ctxt__alloc_ptr (
        .clk,
        .srst,
        .wr_rdy  ( alloc_req ),
        .wr      ( alloc_rdy ),
        .wr_data ( alloc_ptr ),
        .rd      ( ptr_ack ),
        .rd_vld  ( ptr_vld ),
        .rd_data ( ptr ),
        .oflow   ( ),
        .uflow   ( )
    );

    assign ptr_ack = init_ptr_ack || store_ack;

    // List context memory
    mem_ram_sdp #(
        .SPEC ( LIST_CTXT_MEM_SPEC )
    ) i_mem_ram_sdp__list_ctxt__store (
        .mem_wr_if ( ctxt_mem_wr_if ),
        .mem_rd_if ( ctxt_mem_rd_if )
    );

    // Alternate write access from store, load and load-update contexts
    always_comb begin
        if (init_done) begin
            case (sel)
                2'd0 : begin
                    ctxt_mem_wr_if.req  = load_update_ctxt_wr_req;
                    ctxt_mem_wr_if.addr = __load_update_list_sel;
                    ctxt_mem_wr_if.data = load_update_ctxt_wr_data;
                end
                2'd1 : begin
                    ctxt_mem_wr_if.req = store_ctxt_wr_req;
                    ctxt_mem_wr_if.addr = __store_list_sel;
                    ctxt_mem_wr_if.data = store_ctxt_wr_data;
                end
                2'd2 : begin
                    ctxt_mem_wr_if.req  = load_ctxt_wr_req;
                    ctxt_mem_wr_if.addr = __load_list_sel;
                    ctxt_mem_wr_if.data = load_ctxt_wr_data;
                end
                default : begin
                    ctxt_mem_wr_if.req = 1'b0;
                    ctxt_mem_wr_if.addr = __store_list_sel;
                    ctxt_mem_wr_if.data = store_ctxt_wr_data;
                end
            endcase
        end else begin
            ctxt_mem_wr_if.req  = init_wr_req;
            ctxt_mem_wr_if.addr = init_idx;
            ctxt_mem_wr_if.data = init_ctxt_wr_data;
        end
    end

    assign store_ctxt_wr_rdy       = (sel == 2'd1) ? ctxt_mem_wr_if.rdy : 1'b0;
    assign load_ctxt_wr_rdy        = (sel == 2'd2) ? ctxt_mem_wr_if.rdy : 1'b0;
    assign load_update_ctxt_wr_rdy = (sel == 2'd0) ? ctxt_mem_wr_if.rdy : 1'b0;

    assign ctxt_mem_wr_if.rst = 1'b0;
    assign ctxt_mem_wr_if.en  = 1'b1;

    // Alternate read access from store, load and load-update contexts
    always_comb begin
        case (sel)
            2'd0 : begin
                ctxt_mem_rd_if.req = store_ctxt_rd_req;
                ctxt_mem_rd_if.addr = __store_list_sel;
            end
            2'd1 : begin
                ctxt_mem_rd_if.req = load_ctxt_rd_req;
                ctxt_mem_rd_if.addr = __load_list_sel;
            end
            2'd2 : begin
                ctxt_mem_rd_if.req  = load_update_ctxt_rd_req;
                ctxt_mem_rd_if.addr = __load_update_list_sel;
            end
            default : begin
                ctxt_mem_rd_if.req  = 1'b0;
                ctxt_mem_rd_if.addr = __store_list_sel;
            end
        endcase
    end

    assign ctxt_mem_rd_if.rst = 1'b0;

    assign store_ctxt_rd_rdy       = (sel == 2'd0) ? ctxt_mem_rd_if.rdy : 1'b0;
    assign load_ctxt_rd_rdy        = (sel == 2'd1) ? ctxt_mem_rd_if.rdy : 1'b0;
    assign load_update_ctxt_rd_rdy = (sel == 2'd2) ? ctxt_mem_rd_if.rdy : 1'b0;

    assign store_ctxt_wr       = store_ctxt_wr_req       && store_ctxt_wr_rdy;
    assign load_ctxt_wr        = load_ctxt_wr_req        && load_ctxt_wr_rdy;
    assign load_update_ctxt_wr = load_update_ctxt_wr_req && load_update_ctxt_wr_rdy;

    // Write-through (same queue simultaneous store/load)
    always_ff @(posedge clk) begin
        store_ctxt_wr_thru       <= store_ctxt_wr       ? (__store_list_sel       == __load_list_sel)        : 1'b0;
        load_ctxt_wr_thru        <= load_ctxt_wr        ? (__load_list_sel        == __load_update_list_sel) : 1'b0;
        load_update_ctxt_wr_thru <= load_update_ctxt_wr ? (__load_update_list_sel == __store_list_sel)       : 1'b0;
    end
    assign store_ctxt_rd_data       = load_update_ctxt_wr_thru ? load_update_wr_ctxt : ctxt_mem_rd_if.data;
    assign load_ctxt_rd_data        = store_ctxt_wr_thru       ? store_wr_ctxt       : ctxt_mem_rd_if.data;
    assign load_update_ctxt_rd_data = load_ctxt_wr_thru        ? load_wr_ctxt        : ctxt_mem_rd_if.data;

    // Init FSM
    initial init_state = INIT_RESET;
    always @(posedge clk) begin
        if (srst) init_state <= INIT_RESET;
        else      init_state <= nxt_init_state;
    end

    always_comb begin
        nxt_init_state = init_state;
        reset_init_idx = 1'b0;
        inc_init_idx = 1'b0;
        init_ptr_ack = 1'b0;
        init_wr_req = 1'b0;
        init_done = 1'b0;
        case (init_state)
            INIT_RESET : begin
                reset_init_idx = 1'b1;
                if (mem_init_done && alloc__init_done) nxt_init_state = INIT_PTR_REQ;
            end
            INIT_PTR_REQ : begin
                if (ptr_vld) nxt_init_state = INIT_WR_CTXT;
            end
            INIT_WR_CTXT : begin
                init_wr_req = 1'b1;
                if (ctxt_mem_wr_if.rdy) nxt_init_state = INIT_NXT;
            end
            INIT_NXT : begin
                inc_init_idx = 1'b1;
                init_ptr_ack = 1'b1;
                if (init_idx < LIST_CONTEXTS-1) nxt_init_state = INIT_PTR_REQ;
                else                            nxt_init_state = INIT_DONE;
            end
            INIT_DONE : begin
                init_done = 1'b1;
            end
        endcase
    end

    assign init_ctxt_wr_data.head = ptr;
    assign init_ctxt_wr_data.tail = ptr;
    assign init_ctxt_wr_data.rip = 1'b0;

    initial init_idx = 0;
    always @(posedge clk) begin
        if (reset_init_idx) init_idx <= 0;
        else if (inc_init_idx) init_idx <= init_idx + 1;
    end

    // Store FSM
    initial store_state = STORE_RESET;
    always @(posedge clk) begin
        if (srst) store_state <= STORE_RESET;
        else      store_state <= nxt_store_state;
    end

    always_comb begin
        nxt_store_state = store_state;
        store_rdy = 1'b0;
        store_ack = 1'b0;
        store_nack = 1'b0;
        store_ctxt_wr_req = 1'b0;
        store_ctxt_rd_req = 1'b0;
        mem_wr_if.req = 1'b0;
        case (store_state)
            STORE_RESET : begin
                if (init_done) nxt_store_state = STORE_IDLE;
            end
            STORE_IDLE : begin
                store_rdy = 1'b1;
                if (store_req) begin
                    if (ptr_vld) nxt_store_state = STORE_RD_CTXT_REQ;
                    else nxt_store_state = STORE_NACK;
                end
            end
            STORE_RD_CTXT_REQ : begin
                store_ctxt_rd_req = 1'b1;
                if (store_ctxt_rd_rdy) nxt_store_state = STORE_CTXT_UPDATE;
            end
            STORE_CTXT_UPDATE : begin
                store_ctxt_wr_req = 1'b1;
                if (store_ctxt_wr_rdy) nxt_store_state = STORE_MEM_WR;
            end
            STORE_MEM_WR : begin
                mem_wr_if.req = 1'b1;
                if (mem_wr_if.rdy) nxt_store_state = STORE_DONE;
            end
            STORE_DONE : begin
                store_ack = 1'b1;
                nxt_store_state = STORE_IDLE;
            end
            STORE_NACK : begin
                store_nack = 1'b1;
                nxt_store_state = STORE_IDLE;
            end
            default : begin
                nxt_store_state = STORE_RESET;
            end
        endcase
    end

    always_comb begin
        store_ctxt_wr_data = store_ctxt_rd_data;
        store_ctxt_wr_data.tail = ptr;
    end

    always_ff @(posedge clk) begin
        store_rd_ctxt <= store_ctxt_rd_data;
        store_wr_ctxt <= store_ctxt_wr_data;
        mem_wr_if.addr <= store_ctxt_rd_data.tail;
    end

    // Latch store context
    always_ff @(posedge clk) begin
        if (store_req && store_rdy) begin
            __store_list_sel <= store_list_sel;
            __store_meta     <= store_meta;
        end
    end

    assign mem_wr_if.rst  = 1'b0;
    assign mem_wr_if.en   = 1'b1;
    assign mem_wr_if.addr = store_wr_ctxt.tail;

    // Construct list item for store
    assign mem_wr_data.ctxt = __store_list_sel;
    assign mem_wr_data.nxt  = ptr;
    assign mem_wr_data.meta = __store_meta;
    assign mem_wr_if.data = mem_wr_data;

    // Load FSM
    initial load_state = LOAD_RESET;
    always @(posedge clk) begin
        if (srst) load_state <= LOAD_RESET;
        else      load_state <= nxt_load_state;
    end

    always_comb begin
        nxt_load_state = load_state;
        load_rdy = 1'b0;
        load_ctxt_wr_req = 1'b0;
        load_ctxt_rd_req = 1'b0;
        mem_rd_if.req = 1'b0;
        rd_ctxt_fifo__wr = 1'b0;
        dealloc_req = 1'b0;
        __load_nack = 1'b0;
        case (load_state)
            LOAD_RESET : begin
                if (init_done) nxt_load_state = LOAD_IDLE;
            end
            LOAD_IDLE : begin
                load_rdy = 1'b1;
                if (load_req) nxt_load_state = LOAD_RD_CTXT_REQ;
            end
            LOAD_RD_CTXT_REQ : begin
                load_ctxt_rd_req = 1'b1;
                if (load_ctxt_rd_rdy) nxt_load_state = LOAD_CTXT_UPDATE_RIP;
            end
            LOAD_CTXT_UPDATE_RIP : begin
                load_ctxt_wr_req = 1'b1;
                if (load_ctxt_rd_data.rip || (load_ctxt_rd_data.head == load_ctxt_rd_data.tail)) nxt_load_state = LOAD_NACK;
                else if (load_ctxt_wr_rdy) nxt_load_state = LOAD_MEM_RD;
            end
            LOAD_MEM_RD : begin
                mem_rd_if.req = 1'b1;
                if (mem_rd_if.rdy) nxt_load_state = LOAD_DONE;
            end
            LOAD_DONE : begin
                rd_ctxt_fifo__wr = 1'b1;
                if (rd_ctxt_fifo__wr_rdy) nxt_load_state = LOAD_DEALLOC;
            end
            LOAD_DEALLOC : begin
                dealloc_req = 1'b1;
                if (dealloc_rdy) nxt_load_state = LOAD_IDLE;
            end
            LOAD_NACK : begin
                __load_nack = 1'b1;
                rd_ctxt_fifo__wr = 1'b1;
                if (rd_ctxt_fifo__wr_rdy) nxt_load_state = LOAD_IDLE;
            end
            default : begin
                nxt_load_state = LOAD_RESET;
            end
        endcase
    end

    always_comb begin
        load_ctxt_wr_data = load_ctxt_rd_data;
        if ((load_ctxt_rd_data.rip == 1'b0) && (load_ctxt_rd_data.head != store_ctxt_rd_data.tail)) load_ctxt_wr_data.rip = 1;
    end

    always_ff @(posedge clk) begin
        load_rd_ctxt <= load_ctxt_rd_data;
        load_wr_ctxt <= load_ctxt_wr_data;
    end

    // Latch load context
    always_ff @(posedge clk) begin
        if (load_req && load_rdy) begin
            __load_list_sel <= load_list_sel;
        end
    end

    assign mem_rd_data    = mem_rd_if.data;
    assign mem_rd_if.addr = load_rd_ctxt.head;
    assign dealloc_ptr    = load_rd_ctxt.head;

    assign rd_ctxt_fifo__wr_data.nack = __load_nack;
    assign rd_ctxt_fifo__wr_data.ctxt = __load_list_sel;

    fifo_ctxt #(
        .DATA_WID ( RD_CTXT_WID ),
        .DEPTH ( NUM_RD_TRANSACTIONS ),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__rd_ctxt (
        .clk,
        .srst,
        .wr      ( rd_ctxt_fifo__wr ),
        .wr_rdy  ( rd_ctxt_fifo__wr_rdy ),
        .wr_data ( rd_ctxt_fifo__wr_data ),
        .rd      ( load_done || (rd_ctxt_fifo__rd_vld && rd_ctxt_fifo__rd_data.nack) ),
        .rd_vld  ( rd_ctxt_fifo__rd_vld ),
        .rd_data ( rd_ctxt_fifo__rd_data ),
        .oflow   ( ),
        .uflow   ( )
    );

    fifo_ctxt #(
        .DATA_WID ( LIST_ITEM_WID ),
        .DEPTH ( NUM_RD_TRANSACTIONS ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__rd_data (
        .clk,
        .srst,
        .wr      ( mem_rd_if.ack ),
        .wr_rdy  ( ),
        .wr_data ( mem_rd_data ),
        .rd      ( load_done ),
        .rd_vld  ( rd_data_fifo__rd_vld ),
        .rd_data ( rd_data_fifo__rd_data ),
        .oflow   ( ),
        .uflow   ( )
    );

    assign load_done = rd_ctxt_fifo__rd_vld && !rd_ctxt_fifo__rd_data.nack && rd_data_fifo__rd_vld && load_ctxt_fifo__wr_rdy;
    assign load_ack  = load_done && (rd_data_fifo__rd_data.ctxt == rd_ctxt_fifo__rd_data.ctxt);
    assign load_nack = (rd_ctxt_fifo__rd_vld && rd_ctxt_fifo__rd_data.nack) || load_done && (rd_data_fifo__rd_data.ctxt != rd_ctxt_fifo__rd_data.ctxt);

    assign load_meta = rd_data_fifo__rd_data.meta;

    // Now that head pointer is dereferenced, update list context to point to new head pointer
    assign load_ctxt_fifo__wr_data.ctxt = mem_rd_data.ctxt;
    assign load_ctxt_fifo__wr_data.head = mem_rd_data.nxt;

    fifo_ctxt    #(
        .DATA_WID ( LIST_CTXT_UPDATE_WID ),
        .DEPTH    ( 8 ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__ctxt_update (
        .clk,
        .srst,
        .wr      ( mem_rd_if.ack ),
        .wr_rdy  ( load_ctxt_fifo__wr_rdy ),
        .wr_data ( load_ctxt_fifo__wr_data ),
        .rd      ( load_ctxt_fifo__rd ),
        .rd_vld  ( load_ctxt_fifo__rd_vld ),
        .rd_data ( load_ctxt_fifo__rd_data ),
        .oflow   ( ),
        .uflow   ( )
    );

    // Context update FSM
    initial load_update_state = LOAD_UPDATE_RESET;
    always @(posedge clk) begin
        if (srst) load_update_state <= LOAD_UPDATE_RESET;
        else      load_update_state <= nxt_load_update_state;
    end

    always_comb begin
        nxt_load_update_state = load_update_state;
        load_update_ctxt_rd_req = 1'b0;
        load_update_ctxt_wr_req = 1'b0;
        load_ctxt_fifo__rd = 1'b0;
        case (load_update_state)
            LOAD_UPDATE_RESET : begin
                nxt_load_update_state = LOAD_UPDATE_IDLE;
            end
            LOAD_UPDATE_IDLE : begin
                if (load_ctxt_fifo__rd_vld) nxt_load_update_state = LOAD_UPDATE_RD_REQ;
            end
            LOAD_UPDATE_RD_REQ : begin
                load_update_ctxt_rd_req = 1'b1;
                if (load_update_ctxt_rd_rdy) nxt_load_update_state = LOAD_UPDATE_WR_REQ;
            end
            LOAD_UPDATE_WR_REQ : begin
                load_update_ctxt_wr_req = 1'b1;
                if (load_update_ctxt_wr_rdy) nxt_load_update_state = LOAD_UPDATE_DONE;
            end
            LOAD_UPDATE_DONE : begin
                load_ctxt_fifo__rd = 1'b1;
                nxt_load_update_state = LOAD_UPDATE_IDLE;
            end
            default : begin
                nxt_load_update_state = LOAD_UPDATE_RESET;
            end
        endcase
    end

    assign __load_update_list_sel = load_ctxt_fifo__rd_data.ctxt;

    always_comb begin
        load_update_ctxt_wr_data = load_update_ctxt_rd_data;
        if (load_update_ctxt_rd_data.rip == 1'b1) begin
            load_update_ctxt_wr_data.rip = 0;
            load_update_ctxt_wr_data.head = load_ctxt_fifo__rd_data.head;
        end
    end

    always_ff @(posedge clk) begin
        load_update_rd_ctxt <= load_update_ctxt_rd_data;
        load_update_wr_ctxt <= load_update_ctxt_wr_data;
    end

endmodule : alloc_ll_core
