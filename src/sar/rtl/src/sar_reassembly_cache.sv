module sar_reassembly_cache #(
    parameter int NUM_FRAME_BUFFERS = 1,
    parameter int MAX_FRAME_SIZE    = 1,
    parameter int MAX_SEGMENT_SIZE  = 1,
    parameter int MAX_FRAGMENTS     = 1, // Number of disjoint (post-coalescing) fragments supported at any given time (across all buffers)
    parameter int BURST_SIZE        = 8,
    // Derived parameters (don't override)
    parameter int BUF_ID_WID       = $clog2(NUM_FRAME_BUFFERS), // Width (in bits) of reassembly buffer (context) pointer
    parameter int OFFSET_WID       = $clog2(MAX_FRAME_SIZE),    // Width (in bits) of byte offset describing location of segment within frame
    parameter int SEGMENT_LEN_WID  = $clog2(MAX_SEGMENT_SIZE+1),// Width (in bits) of byte length of current segment
    parameter int FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS),     // Width (in bits) of coalesced fragment pointer
    // Simulation-only
    parameter bit  SIM__FAST_INIT  = 1 // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic                        clk,
    input  logic                        srst,

    input  logic                        en,

    output logic                        init_done,

    // Lookup interface
    output logic                        seg_ready,
    input  logic                        seg_valid,
    input  logic [BUF_ID_WID-1:0]       seg_buf_id,
    input  logic [OFFSET_WID-1:0]       seg_offset,
    input  logic [SEGMENT_LEN_WID-1:0]  seg_len,
    input  logic                        seg_last,

    // Result interface
    output logic                        frag_valid,
    output logic                        frag_init,
    output logic [BUF_ID_WID-1:0]       frag_buf_id,
    output logic                        frag_last,
    output logic [FRAGMENT_PTR_WID-1:0] frag_ptr,
    output logic [OFFSET_WID-1:0]       frag_offset_start,
    output logic [OFFSET_WID-1:0]       frag_offset_end,
    
    output logic                        frag_merged,
    output logic [FRAGMENT_PTR_WID-1:0] frag_merged_ptr,

    // Pointer deallocation interface
    output logic                        frag_ptr_dealloc_rdy,
    input  logic                        frag_ptr_dealloc_req,
    input  logic [FRAGMENT_PTR_WID-1:0] frag_ptr_dealloc_value,

    // Control interfaces
    db_ctrl_intf.peripheral             ctrl_if__append,
    db_ctrl_intf.peripheral             ctrl_if__prepend,

    // AXI-L control
    axi4l_intf.peripheral               axil_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import sar_pkg::*;
    import arb_pkg::*;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int NUM_RD_TRANSACTIONS = 16;
    localparam int DELETE_Q_DEPTH = 32;
    localparam int DELETE_Q_THRESHOLD = DELETE_Q_DEPTH - NUM_RD_TRANSACTIONS;
    localparam int NUM_INGRESS_QUEUES = 4;
    localparam int INGRESS_Q_DEPTH = 8;

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        logic [BUF_ID_WID-1:0]      buf_id;
        logic [OFFSET_WID-1:0]      offset;
        logic [SEGMENT_LEN_WID-1:0] len;
        logic                       last;
    } ingress_seg_t;

    typedef struct packed {
        logic [BUF_ID_WID-1:0] buf_id;
        logic [OFFSET_WID-1:0] offset;
    } segment_table_key_t;

    typedef struct packed {
        logic [FRAGMENT_PTR_WID-1:0] ptr;
        logic [OFFSET_WID-1:0]       offset;
    } segment_table_value_t;

    typedef struct packed {
        logic [BUF_ID_WID-1:0]      buf_id; 
        logic [OFFSET_WID-1:0]      offset_start;
        logic [OFFSET_WID-1:0]      offset_end;
        logic [SEGMENT_LEN_WID-1:0] len;
        logic                       last;
    } segment_ctxt_t;

    typedef enum logic [1:0] {
        FRAGMENT_CREATE,
        FRAGMENT_APPEND,
        FRAGMENT_PREPEND,
        FRAGMENT_MERGE
    } fragment_action_t;

    // -------------------------------------------------
    // (Derived) Parameters
    // -------------------------------------------------
    localparam int INGRESS_SEG_WID = $bits(ingress_seg_t);
    localparam int SEGMENT_TABLE_KEY_WID = $bits(segment_table_key_t);
    localparam int SEGMENT_TABLE_VALUE_WID = $bits(segment_table_value_t);
    localparam int SEGMENT_CTXT_WID = $bits(segment_ctxt_t);

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    db_intf #(.KEY_WID(SEGMENT_TABLE_KEY_WID), .VALUE_WID(SEGMENT_TABLE_VALUE_WID)) lookup_if__append (.clk);
    db_intf #(.KEY_WID(SEGMENT_TABLE_KEY_WID), .VALUE_WID(SEGMENT_TABLE_VALUE_WID)) update_if__append (.clk);

    db_intf #(.KEY_WID(SEGMENT_TABLE_KEY_WID), .VALUE_WID(SEGMENT_TABLE_VALUE_WID)) lookup_if__prepend (.clk);
    db_intf #(.KEY_WID(SEGMENT_TABLE_KEY_WID), .VALUE_WID(SEGMENT_TABLE_VALUE_WID)) update_if__prepend (.clk);

    axi4l_intf #() axil_if__cache ();
    axi4l_intf #() axil_if__cache__clk ();
    axi4l_intf #() axil_if__allocator ();
    axi4l_intf #() axil_if__append ();
    axi4l_intf #() axil_if__prepend ();

    sar_reassembly_cache_reg_intf reg_if ();

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic               __srst;
    logic               __en;

    logic               init_done__append;
    logic               init_done__prepend;
    logic               init_done__allocator;

    logic               lookup_done;
    logic               lookup_error;

    segment_table_key_t   lookup_if__append_key;
    segment_table_value_t lookup_if__append_value;
    segment_table_key_t   lookup_if__prepend_key;
    segment_table_value_t lookup_if__prepend_value;

    segment_table_key_t   update_if__append_key;
    segment_table_value_t update_if__append_value;
    segment_table_key_t   update_if__prepend_key;
    segment_table_value_t update_if__prepend_value;

    segment_ctxt_t      lookup_ctxt_in;
    segment_ctxt_t      lookup_ctxt_out;

    logic                        frag_ptr_alloc_req;
    logic                        frag_ptr_alloc_rdy;
    logic [FRAGMENT_PTR_WID-1:0] frag_ptr_alloc_value;

    logic                        __frag_valid;
    logic                        __frag_init;
    logic                        __frag_last;
    fragment_action_t            __frag_action;
    logic [FRAGMENT_PTR_WID-1:0] __frag_ptr;
    logic [OFFSET_WID-1:0]       __frag_offset_start;
    logic [OFFSET_WID-1:0]       __frag_offset_end;

    logic                        __frag_merged;
    logic [FRAGMENT_PTR_WID-1:0] __frag_merged_ptr;

    logic               delete_q__append__wr;
    segment_table_key_t delete_q__append__wr_data;
    logic               delete_q__append__rd;
    segment_table_key_t delete_q__append__rd_data;
    logic               delete_q__append__empty;
    logic [$clog2(DELETE_Q_DEPTH+1)-1:0] delete_q__append__count;

    logic               delete_q__prepend__wr;
    segment_table_key_t delete_q__prepend__wr_data;
    logic               delete_q__prepend__rd;
    segment_table_key_t delete_q__prepend__rd_data;
    logic               delete_q__prepend__empty;
    logic [$clog2(DELETE_Q_DEPTH+1)-1:0] delete_q__prepend__count;

    logic               delete_q_stop;

    // Ingress queues and arbitration signals
    logic [NUM_INGRESS_QUEUES-1:0] in_q_wr;
    ingress_seg_t                  in_q_wr_data [NUM_INGRESS_QUEUES];
    logic [NUM_INGRESS_QUEUES-1:0] in_q_full;
    logic [NUM_INGRESS_QUEUES-1:0] in_q_rd;
    ingress_seg_t                  in_q_rd_data [NUM_INGRESS_QUEUES];
    logic [NUM_INGRESS_QUEUES-1:0] in_q_empty;

    logic [NUM_INGRESS_QUEUES-1:0] arb_req;
    logic [NUM_INGRESS_QUEUES-1:0] arb_grant;
    logic [NUM_INGRESS_QUEUES-1:0] queue_hazard;
    logic [$clog2(NUM_INGRESS_QUEUES)-1:0] arb_sel;
    logic [$clog2(NUM_INGRESS_QUEUES)-1:0] wr_queue_idx;

    logic                       cache_seg_ready;
    logic                       cache_seg_valid;
    logic [BUF_ID_WID-1:0]      cache_seg_buf_id;
    logic [OFFSET_WID-1:0]      cache_seg_offset;
    logic [SEGMENT_LEN_WID-1:0] cache_seg_len;
    logic                       cache_seg_last;

    // In-flight hazard tracking
    localparam int IN_FLIGHT_DEPTH = NUM_RD_TRANSACTIONS;
    logic [BUF_ID_WID-1:0] in_flight_buf_id [IN_FLIGHT_DEPTH];
    logic                  in_flight_vld    [IN_FLIGHT_DEPTH];
    logic [$clog2(IN_FLIGHT_DEPTH)-1:0] in_flight_wr_ptr;
    logic [$clog2(IN_FLIGHT_DEPTH)-1:0] in_flight_rd_ptr;

    // Debug counter/flag signals
    logic        dbg_cnt_clear;
    logic [31:0] dbg_cnt_seg_rx;
    logic [31:0] dbg_cnt_frag_create;
    logic [31:0] dbg_cnt_frag_append;
    logic [31:0] dbg_cnt_frag_prepend;
    logic [31:0] dbg_cnt_frag_merge;
    logic [31:0] dbg_cnt_alloc_drop;
    logic [31:0] dbg_cnt_lookup_error;

    logic ctxt_fifo_oflow;
    logic ctxt_fifo_uflow;
    logic delete_q_append_oflow;
    logic delete_q_prepend_oflow;

    logic dbg_flag_ctxt_fifo_oflow;
    logic dbg_flag_ctxt_fifo_uflow;
    logic dbg_flag_delete_q_append_oflow;
    logic dbg_flag_delete_q_prepend_oflow;
    
    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Decoder
    sar_reassembly_cache_decoder i_sar_reassembly_cache_decoder (
        .axil_if            ( axil_if ),
        .cache_axil_if      ( axil_if__cache ),
        .allocator_axil_if  ( axil_if__allocator ),
        .append_axil_if     ( axil_if__append ),
        .prepend_axil_if    ( axil_if__prepend )
    );

    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if__cache ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__cache__clk )
    );

    sar_reassembly_cache_reg_blk i_sar_reassembly_cache_reg_blk (
        .axil_if    ( axil_if__cache__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_size_nxt = MAX_FRAGMENTS;
    assign reg_if.info_size_nxt_v = 1'b1;

    // Status
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset_mon = __srst;
    assign reg_if.status_nxt.enable_mon = __en;
    assign reg_if.status_nxt.ready_mon = init_done;

    // Debug counter clear
    initial dbg_cnt_clear = 1'b1;
    always @(posedge clk) begin
        if (__srst || reg_if.dbg_control.clear_counts) dbg_cnt_clear <= 1'b1;
        else                                           dbg_cnt_clear <= 1'b0;
    end

    // Debug counters
    always @(posedge clk) begin
        if (dbg_cnt_clear)                  dbg_cnt_seg_rx <= '0;
        else if (seg_valid && seg_ready)    dbg_cnt_seg_rx <= dbg_cnt_seg_rx + 1;
    end

    always @(posedge clk) begin
        if (dbg_cnt_clear) begin
            dbg_cnt_frag_create  <= '0;
            dbg_cnt_frag_append  <= '0;
            dbg_cnt_frag_prepend <= '0;
            dbg_cnt_frag_merge   <= '0;
            dbg_cnt_alloc_drop   <= '0;
            dbg_cnt_lookup_error <= '0;
        end else begin
            if (__frag_valid && __frag_action == FRAGMENT_CREATE)  dbg_cnt_frag_create  <= dbg_cnt_frag_create  + 1;
            if (__frag_valid && __frag_action == FRAGMENT_APPEND)  dbg_cnt_frag_append  <= dbg_cnt_frag_append  + 1;
            if (__frag_valid && __frag_action == FRAGMENT_PREPEND) dbg_cnt_frag_prepend <= dbg_cnt_frag_prepend + 1;
            if (__frag_valid && __frag_action == FRAGMENT_MERGE)   dbg_cnt_frag_merge   <= dbg_cnt_frag_merge   + 1;
            if (lookup_done && !lookup_if__append.valid && !lookup_if__prepend.valid && !frag_ptr_alloc_rdy)
                dbg_cnt_alloc_drop <= dbg_cnt_alloc_drop + 1;
            if (lookup_error)                                      dbg_cnt_lookup_error <= dbg_cnt_lookup_error + 1;
        end
    end

    assign reg_if.dbg_cnt_seg_rx_nxt_v      = 1'b1;
    assign reg_if.dbg_cnt_seg_rx_nxt        = dbg_cnt_seg_rx;
    assign reg_if.dbg_cnt_frag_create_nxt_v = 1'b1;
    assign reg_if.dbg_cnt_frag_create_nxt   = dbg_cnt_frag_create;
    assign reg_if.dbg_cnt_frag_append_nxt_v = 1'b1;
    assign reg_if.dbg_cnt_frag_append_nxt   = dbg_cnt_frag_append;
    assign reg_if.dbg_cnt_frag_prepend_nxt_v = 1'b1;
    assign reg_if.dbg_cnt_frag_prepend_nxt  = dbg_cnt_frag_prepend;
    assign reg_if.dbg_cnt_frag_merge_nxt_v  = 1'b1;
    assign reg_if.dbg_cnt_frag_merge_nxt    = dbg_cnt_frag_merge;
    assign reg_if.dbg_cnt_alloc_drop_nxt_v  = 1'b1;
    assign reg_if.dbg_cnt_alloc_drop_nxt    = dbg_cnt_alloc_drop;
    assign reg_if.dbg_cnt_lookup_error_nxt_v = 1'b1;
    assign reg_if.dbg_cnt_lookup_error_nxt  = dbg_cnt_lookup_error;

    // Sticky debug flags (clear-on-read via rd_evt)
    always @(posedge clk) begin
        if (__srst || reg_if.dbg_flags_rd_evt) begin
            dbg_flag_ctxt_fifo_oflow        <= 1'b0;
            dbg_flag_ctxt_fifo_uflow        <= 1'b0;
            dbg_flag_delete_q_append_oflow  <= 1'b0;
            dbg_flag_delete_q_prepend_oflow <= 1'b0;
        end else begin
            dbg_flag_ctxt_fifo_oflow        <= dbg_flag_ctxt_fifo_oflow        || ctxt_fifo_oflow;
            dbg_flag_ctxt_fifo_uflow        <= dbg_flag_ctxt_fifo_uflow        || ctxt_fifo_uflow;
            dbg_flag_delete_q_append_oflow  <= dbg_flag_delete_q_append_oflow  || delete_q_append_oflow;
            dbg_flag_delete_q_prepend_oflow <= dbg_flag_delete_q_prepend_oflow || delete_q_prepend_oflow;
        end
    end

    assign reg_if.dbg_flags_nxt_v = 1'b1;
    assign reg_if.dbg_flags_nxt.ctxt_fifo_oflow        = dbg_flag_ctxt_fifo_oflow;
    assign reg_if.dbg_flags_nxt.ctxt_fifo_uflow        = dbg_flag_ctxt_fifo_uflow;
    assign reg_if.dbg_flags_nxt.delete_q_append_oflow  = dbg_flag_delete_q_append_oflow;
    assign reg_if.dbg_flags_nxt.delete_q_prepend_oflow = dbg_flag_delete_q_prepend_oflow;

    // Block reset
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    // Block enable
    initial __en = 1'b0;
    always @(posedge clk) begin
        if (en && reg_if.control.enable) __en <= 1'b1;
        else                             __en <= 1'b0;
    end

    // -------------------------------------------------
    // Control
    // -------------------------------------------------
    assign init_done = init_done__append && init_done__prepend && init_done__allocator;

    // -------------------------------------------------
    // Segment hash table (append lookup)
    // -------------------------------------------------
    sar_reassembly_htable #(
        .KEY_WID        ( SEGMENT_TABLE_KEY_WID ),
        .VALUE_WID      ( SEGMENT_TABLE_VALUE_WID ),
        .NUM_ITEMS      ( MAX_FRAGMENTS ),
        .BURST_SIZE     ( BURST_SIZE ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_sar_reassembly_segment_htable__append (
        .clk            ( clk ),
        .srst           ( __srst ),
        .en             ( __en ),
        .init_done      ( init_done__append ),
        .lookup_if      ( lookup_if__append ),
        .update_if      ( update_if__append ),
        .ctrl_if        ( ctrl_if__append ),
        .axil_if        ( axil_if__append )
    );

    // -------------------------------------------------
    // Segment hash table (prepend lookup)
    // -------------------------------------------------
    sar_reassembly_htable #(
        .KEY_WID        ( SEGMENT_TABLE_KEY_WID ),
        .VALUE_WID      ( SEGMENT_TABLE_VALUE_WID ),
        .NUM_ITEMS      ( MAX_FRAGMENTS ),
        .BURST_SIZE     ( BURST_SIZE ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_sar_reassembly_segment_htable__prepend (
        .clk            ( clk ),
        .srst           ( __srst ),
        .en             ( __en ),
        .init_done      ( init_done__prepend ),
        .lookup_if      ( lookup_if__prepend ),
        .update_if      ( update_if__prepend ),
        .ctrl_if        ( ctrl_if__prepend ),
        .axil_if        ( axil_if__prepend )
    );

    // ----------------------------------
    // Fragment pointer management
    // ----------------------------------
    alloc_axil_bv      #(
        .PTR_WID        ( FRAGMENT_PTR_WID ),
        .ALLOC_FC       ( 0 ),
        .DEALLOC_FC     ( 1 ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_alloc_axil_bv   (
        .clk            ( clk ),
        .srst           ( __srst ),
        .en             ( __en ),
        .init_done      ( init_done__allocator ),
        .alloc_req      ( frag_ptr_alloc_req ),
        .alloc_rdy      ( frag_ptr_alloc_rdy ),
        .alloc_ptr      ( frag_ptr_alloc_value ),
        .dealloc_req    ( frag_ptr_dealloc_req ),
        .dealloc_rdy    ( frag_ptr_dealloc_rdy ),
        .dealloc_ptr    ( frag_ptr_dealloc_value ),
        .axil_if        ( axil_if__allocator )
    );

    // -------------------------------------------------
    // Ingress queues & hazard tracking
    // -------------------------------------------------
    generate
        if (BUF_ID_WID >= $clog2(NUM_INGRESS_QUEUES)) begin : g__wr_queue_idx_wide
            assign wr_queue_idx = seg_buf_id[$clog2(NUM_INGRESS_QUEUES)-1:0];
        end else if (BUF_ID_WID > 0) begin : g__wr_queue_idx_narrow
            assign wr_queue_idx = { {($clog2(NUM_INGRESS_QUEUES)-BUF_ID_WID){1'b0}}, seg_buf_id };
        end else begin : g__wr_queue_idx_zero
            assign wr_queue_idx = '0;
        end
    endgenerate

    assign seg_ready = init_done && __en && !in_q_full[wr_queue_idx];

    always_comb begin
        for (int q = 0; q < NUM_INGRESS_QUEUES; q++) begin
            in_q_wr[q] = (seg_valid && seg_ready && (wr_queue_idx == q));
            in_q_wr_data[q].buf_id = seg_buf_id;
            in_q_wr_data[q].offset = seg_offset;
            in_q_wr_data[q].len    = seg_len;
            in_q_wr_data[q].last   = seg_last;
        end
    end

    generate
        for (genvar g_q = 0; g_q < NUM_INGRESS_QUEUES; g_q++) begin : g__in_q
            fifo_small #(
                .DATA_WID ( INGRESS_SEG_WID ),
                .DEPTH    ( INGRESS_Q_DEPTH )
            ) i_fifo_small__in_q (
                .clk     ( clk ),
                .srst    ( __srst ),
                .wr      ( in_q_wr[g_q] ),
                .wr_data ( in_q_wr_data[g_q] ),
                .full    ( in_q_full[g_q] ),
                .oflow   ( ),
                .rd      ( in_q_rd[g_q] ),
                .rd_data ( in_q_rd_data[g_q] ),
                .empty   ( in_q_empty[g_q] ),
                .uflow   ( ),
                .count   ( )
            );
        end
    endgenerate

    // Track buffer IDs of in-flight lookups to prevent same-buffer race conditions
    initial begin
        in_flight_wr_ptr = '0;
        in_flight_rd_ptr = '0;
        for (int i = 0; i < IN_FLIGHT_DEPTH; i++) begin
            in_flight_vld[i] = 1'b0;
            in_flight_buf_id[i] = '0;
        end
    end

    always @(posedge clk) begin
        if (__srst) begin
            in_flight_wr_ptr <= '0;
            in_flight_rd_ptr <= '0;
            for (int i = 0; i < IN_FLIGHT_DEPTH; i++) begin
                in_flight_vld[i] <= 1'b0;
                in_flight_buf_id[i] <= '0;
            end
        end else begin
            if (cache_seg_valid && cache_seg_ready) begin
                in_flight_vld[in_flight_wr_ptr] <= 1'b1;
                in_flight_buf_id[in_flight_wr_ptr] <= cache_seg_buf_id;
                in_flight_wr_ptr <= (in_flight_wr_ptr == IN_FLIGHT_DEPTH-1) ? '0 : in_flight_wr_ptr + 1;
            end
            if (lookup_done) begin
                in_flight_vld[in_flight_rd_ptr] <= 1'b0;
                in_flight_rd_ptr <= (in_flight_rd_ptr == IN_FLIGHT_DEPTH-1) ? '0 : in_flight_rd_ptr + 1;
            end
        end
    end

    // Detect if head segment of each queue has a buffer hazard
    always_comb begin
        for (int q = 0; q < NUM_INGRESS_QUEUES; q++) begin
            queue_hazard[q] = 1'b0;
            if (!in_q_empty[q]) begin
                for (int i = 0; i < IN_FLIGHT_DEPTH; i++) begin
                    if (in_flight_vld[i] && (in_flight_buf_id[i] == in_q_rd_data[q].buf_id)) begin
                        queue_hazard[q] = 1'b1;
                    end
                end
            end
        end
    end

    // Arbitration across ingress queues (WCRR)
    always_comb begin
        for (int q = 0; q < NUM_INGRESS_QUEUES; q++) begin
            arb_req[q] = !in_q_empty[q] && !queue_hazard[q];
        end
    end

    arb_rr #(
        .MODE ( arb_pkg::WCRR ),
        .N    ( NUM_INGRESS_QUEUES )
    ) i_arb_rr (
        .clk   ( clk ),
        .srst  ( __srst ),
        .en    ( cache_seg_ready ),
        .req   ( arb_req ),
        .grant ( arb_grant ),
        .ack   ( arb_grant ),
        .sel   ( arb_sel )
    );

    assign cache_seg_valid  = (arb_grant != '0);
    assign cache_seg_buf_id = in_q_rd_data[arb_sel].buf_id;
    assign cache_seg_offset = in_q_rd_data[arb_sel].offset;
    assign cache_seg_len    = in_q_rd_data[arb_sel].len;
    assign cache_seg_last   = in_q_rd_data[arb_sel].last;

    assign in_q_rd = arb_grant & {NUM_INGRESS_QUEUES{cache_seg_ready}};

    // -------------------------------------------------
    // Drive lookup interfaces
    // -------------------------------------------------
    // Perform two lookups per input key:
    //   - one lookup in 'Append' context, i.e. attempting to append new segment to existing fragment
    //   - one lookup in 'Prepend' context, i.e. attempting to prepend new segment to existing fragment
    assign lookup_if__append.req = cache_seg_valid;
    assign lookup_if__append_key.buf_id = cache_seg_buf_id;
    assign lookup_if__append_key.offset = cache_seg_offset;
    assign lookup_if__append.key = lookup_if__append_key;
    assign lookup_if__append.next = 1'b0;
    assign lookup_if__append_value = lookup_if__append.value;

    assign lookup_if__prepend.req = cache_seg_valid;
    assign lookup_if__prepend_key.buf_id = cache_seg_buf_id;
    assign lookup_if__prepend_key.offset = cache_seg_offset + cache_seg_len;
    assign lookup_if__prepend.key = lookup_if__prepend_key;
    assign lookup_if__prepend.next = 1'b0;
    assign lookup_if__prepend_value = lookup_if__prepend.value;

    // Registered backpressure to prevent deletion queue overflow
    initial delete_q_stop = 1'b0;
    always @(posedge clk) begin
        if (__srst) begin
            delete_q_stop <= 1'b0;
        end else begin
            delete_q_stop <= (delete_q__append__count  >= DELETE_Q_THRESHOLD) ||
                             (delete_q__prepend__count >= DELETE_Q_THRESHOLD);
        end
    end

    assign cache_seg_ready = init_done && __en && !delete_q_stop && lookup_if__append.rdy && lookup_if__prepend.rdy;

    // Context buffer
    assign lookup_ctxt_in.buf_id       = cache_seg_buf_id;
    assign lookup_ctxt_in.offset_start = cache_seg_offset;
    assign lookup_ctxt_in.offset_end   = cache_seg_offset + cache_seg_len;
    assign lookup_ctxt_in.len          = cache_seg_len;
    assign lookup_ctxt_in.last         = cache_seg_last;

    assign lookup_done = lookup_if__append.ack && lookup_if__prepend.ack;

    // Check for misalignment of lookup results between append/prepend tables;
    // these tables are identical so this should never happen
    assign lookup_error = lookup_if__append.ack ^ lookup_if__prepend.ack;

    fifo_small_ctxt #(
        .DATA_WID ( SEGMENT_CTXT_WID ),
        .DEPTH    ( NUM_RD_TRANSACTIONS )
    ) i_fifo_small_ctxt__lookup_req (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr_rdy  ( ),
        .wr      ( cache_seg_valid && cache_seg_ready ),
        .wr_data ( lookup_ctxt_in ),
        .rd      ( lookup_done ),
        .rd_vld  ( ),
        .rd_data ( lookup_ctxt_out ),
        .oflow   ( ctxt_fifo_oflow ),
        .uflow   ( ctxt_fifo_uflow )
    );

    // Process result
    always_comb begin
        __frag_valid = 1'b0;
        __frag_init = 1'b0;
        __frag_last = lookup_ctxt_out.last;
        __frag_action = FRAGMENT_CREATE;
        __frag_ptr = '0;
        __frag_offset_start = '0;
        __frag_offset_end = '0;
        __frag_merged = 1'b0;
        __frag_merged_ptr = '0;
        frag_ptr_alloc_req = 1'b0;
        if (lookup_done) begin
            case ({lookup_if__prepend.valid, lookup_if__append.valid})
                2'b00 : begin
                    __frag_action = FRAGMENT_CREATE;
                    __frag_valid = frag_ptr_alloc_rdy;
                    __frag_init = 1'b1;
                    __frag_ptr = frag_ptr_alloc_value;
                    __frag_offset_start = lookup_ctxt_out.offset_start;
                    __frag_offset_end = lookup_ctxt_out.offset_end;
                    frag_ptr_alloc_req = 1'b1;
                end
                2'b01 : begin
                    __frag_action = FRAGMENT_APPEND;
                    __frag_valid = 1'b1;
                    __frag_ptr = lookup_if__append_value.ptr;
                    __frag_offset_start = lookup_if__append_value.offset;
                    __frag_offset_end = lookup_ctxt_out.offset_end;
                end
                2'b10 : begin
                    __frag_action = FRAGMENT_PREPEND;
                    __frag_valid = 1'b1;
                    __frag_ptr = lookup_if__prepend_value.ptr;
                    __frag_offset_start = lookup_ctxt_out.offset_start;
                    __frag_offset_end = lookup_if__prepend_value.offset;
                    // offset==0 in the prepend table is the sentinel for last=1
                    __frag_last = lookup_ctxt_out.last | (lookup_if__prepend_value.offset == 0);
                end
                2'b11 : begin
                    __frag_action = FRAGMENT_MERGE;
                    __frag_valid = 1'b1;
                    __frag_ptr = lookup_if__prepend_value.ptr;
                    __frag_offset_start = lookup_if__append_value.offset;
                    __frag_offset_end = lookup_if__prepend_value.offset;
                    __frag_merged = 1'b1;
                    __frag_merged_ptr = lookup_if__append_value.ptr;
                    // offset==0 in the prepend table is the sentinel for last=1
                    __frag_last = lookup_ctxt_out.last | (lookup_if__prepend_value.offset == 0);
                end
            endcase
        end
    end

    // Synthesize fragment record update
    initial frag_valid = 1'b0;
    always @(posedge clk) begin
        if (__srst) frag_valid <= 1'b0;
        else begin
            if (lookup_done) frag_valid <= __frag_valid;
            else             frag_valid <= 1'b0;
        end
    end

    // Buffer response data
    always_ff @(posedge clk) begin
        frag_buf_id        <= lookup_ctxt_out.buf_id;
        frag_init          <= __frag_init;
        frag_last          <= __frag_last;
        frag_ptr           <= __frag_ptr;
        frag_offset_start  <= __frag_offset_start;
        frag_offset_end    <= __frag_offset_end;
        frag_merged        <= __frag_merged;
        frag_merged_ptr    <= __frag_merged_ptr;
    end
     
    assign update_if__append.key = update_if__append_key;
    assign update_if__append.value = update_if__append_value;
    assign update_if__append.next = 1'b0;  // Unused

    assign update_if__prepend.key = update_if__prepend_key;
    assign update_if__prepend.value = update_if__prepend_value;
    assign update_if__prepend.next = 1'b0; // Unused

    // Perform table updates according to fragment action
    always_comb begin
        update_if__append.req = 1'b0;
        update_if__append.valid = 1'b0;
        update_if__append_key.buf_id = lookup_ctxt_out.buf_id;
        update_if__append_key.offset = '0;
        update_if__append_value = '0;
        delete_q__append__wr = 1'b0;
        delete_q__append__rd = 1'b0;

        update_if__prepend.req = 1'b0;
        update_if__prepend.valid = 1'b0;
        update_if__prepend_key.buf_id = lookup_ctxt_out.buf_id;
        update_if__prepend_key.offset = '0;
        update_if__prepend_value = '0;
        delete_q__prepend__wr = 1'b0;
        delete_q__prepend__rd = 1'b0;

        if (__frag_valid) begin
            case (__frag_action)
                FRAGMENT_CREATE : begin
                    update_if__append.req = (!lookup_ctxt_out.last);
                    update_if__append.valid = 1'b1; // Insert
                    update_if__append_key.offset = lookup_ctxt_out.offset_end;
                    update_if__append_value.ptr = __frag_ptr;
                    update_if__append_value.offset = lookup_ctxt_out.offset_start;

                    update_if__prepend.req = (lookup_ctxt_out.offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Insert
                    update_if__prepend_key.offset = lookup_ctxt_out.offset_start;
                    update_if__prepend_value.ptr = __frag_ptr;
                    update_if__prepend_value.offset = lookup_ctxt_out.last ? 0 : lookup_ctxt_out.offset_end;
                end
                FRAGMENT_APPEND : begin
                    update_if__append.req = (!lookup_ctxt_out.last);
                    update_if__append.valid = 1'b1; // Insert
                    update_if__append_key.offset = lookup_ctxt_out.offset_end;
                    update_if__append_value.ptr = __frag_ptr;
                    update_if__append_value.offset = __frag_offset_start;
                    delete_q__append__wr = 1'b1;

                    update_if__prepend.req = (__frag_offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Update
                    update_if__prepend_key.offset = __frag_offset_start;
                    update_if__prepend_value.ptr = __frag_ptr;
                    update_if__prepend_value.offset = lookup_ctxt_out.last ? 0 : lookup_ctxt_out.offset_end;
                end
                FRAGMENT_PREPEND : begin
                    update_if__append.req = (__frag_offset_end > 0);
                    update_if__append.valid = 1'b1; // Update
                    update_if__append_key.offset = __frag_offset_end;
                    update_if__append_value.ptr = __frag_ptr;
                    update_if__append_value.offset = lookup_ctxt_out.offset_start;

                    update_if__prepend.req = (lookup_ctxt_out.offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Insert
                    update_if__prepend_key.offset = lookup_ctxt_out.offset_start;
                    update_if__prepend_value.ptr = __frag_ptr;
                    update_if__prepend_value.offset = __frag_last ? 0 : __frag_offset_end;
                    delete_q__prepend__wr = 1'b1;
                end
                FRAGMENT_MERGE : begin
                    update_if__append.req = (__frag_offset_end > 0) && !__frag_last;
                    update_if__append.valid = 1'b1; // Insert
                    update_if__append_key.offset = __frag_offset_end;
                    update_if__append_value.ptr = __frag_ptr;
                    update_if__append_value.offset = __frag_offset_start;
                    delete_q__append__wr = 1'b1;

                    update_if__prepend.req = (__frag_offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Insert
                    update_if__prepend_key.offset = __frag_offset_start;
                    update_if__prepend_value.ptr = __frag_ptr;
                    update_if__prepend_value.offset = __frag_last ? 0 : __frag_offset_end;
                    delete_q__prepend__wr = 1'b1;
                end
                default : begin
                    // No entries to insert
                end
            endcase
        end else begin
            if (!delete_q__append__empty) begin
                update_if__append.req = 1'b1;
                update_if__append.valid = 1'b0;
                update_if__append_key = delete_q__append__rd_data;
                delete_q__append__rd = 1'b1;
            end
            if (!delete_q__prepend__empty) begin
                update_if__prepend.req = 1'b1;
                update_if__prepend.valid = 1'b0;
                update_if__prepend_key = delete_q__prepend__rd_data;
                delete_q__prepend__rd = 1'b1;
            end
        end
    end

    // -------------------------------------------------
    // Deletion queues
    // -------------------------------------------------
    fifo_small   #(
        .DATA_WID ( SEGMENT_TABLE_KEY_WID ),
        .DEPTH    ( DELETE_Q_DEPTH )
    ) i_fifo_small__delete_q__append (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr      ( delete_q__append__wr ),
        .wr_data ( delete_q__append__wr_data ),
        .full    ( ),
        .oflow   ( delete_q_append_oflow ),
        .rd      ( delete_q__append__rd ),
        .rd_data ( delete_q__append__rd_data ),
        .empty   ( delete_q__append__empty ),
        .uflow   ( ),
        .count   ( delete_q__append__count )
    );

    assign delete_q__append__wr_data.buf_id = lookup_ctxt_out.buf_id;
    assign delete_q__append__wr_data.offset = lookup_ctxt_out.offset_start;

    fifo_small   #(
        .DATA_WID ( SEGMENT_TABLE_KEY_WID ),
        .DEPTH    ( DELETE_Q_DEPTH )
    ) i_fifo_small__delete_q__prepend (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr      ( delete_q__prepend__wr ),
        .wr_data ( delete_q__prepend__wr_data ),
        .full    ( ),
        .oflow   ( delete_q_prepend_oflow ),
        .rd      ( delete_q__prepend__rd ),
        .rd_data ( delete_q__prepend__rd_data ),
        .empty   ( delete_q__prepend__empty ),
        .uflow   ( ),
        .count   ( delete_q__prepend__count )
    );
   
    assign delete_q__prepend__wr_data.buf_id = lookup_ctxt_out.buf_id;
    assign delete_q__prepend__wr_data.offset = lookup_ctxt_out.offset_end;

endmodule : sar_reassembly_cache
