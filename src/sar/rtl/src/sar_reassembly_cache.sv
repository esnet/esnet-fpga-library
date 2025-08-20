module sar_reassembly_cache
#(
    parameter type BUF_ID_T       = logic, // (Type) Reassembly buffer (context) pointer
    parameter type OFFSET_T       = logic, // (Type) Offset in bytes describing location of segment within frame
    parameter type SEGMENT_LEN_T  = logic, // (Type) Length in bytes of current segment
    parameter type FRAGMENT_PTR_T = logic, // (Type) Coalesced fragment pointer
    parameter int  BURST_SIZE     = 8,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              en,

    output logic              init_done,

    // Lookup interface
    output logic              seg_ready,
    input  logic              seg_valid,
    input  BUF_ID_T           seg_buf_id,
    input  OFFSET_T           seg_offset,
    input  SEGMENT_LEN_T      seg_len,
    input  logic              seg_last,

    // Result interface
    output logic              frag_valid,
    output logic              frag_init,
    output BUF_ID_T           frag_buf_id,
    output logic              frag_last,
    output FRAGMENT_PTR_T     frag_ptr,
    output OFFSET_T           frag_offset_start,
    output OFFSET_T           frag_offset_end,
    
    output logic              frag_merged,
    output FRAGMENT_PTR_T     frag_merged_ptr,

    // Pointer deallocation interface
    output logic              frag_ptr_dealloc_rdy,
    input  logic              frag_ptr_dealloc_req,
    input  FRAGMENT_PTR_T     frag_ptr_dealloc_value,

    // Control interfaces
    db_ctrl_intf.peripheral   ctrl_if__append,
    db_ctrl_intf.peripheral   ctrl_if__prepend,

    // AXI-L control
    axi4l_intf.peripheral     axil_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import sar_pkg::*;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int NUM_RD_TRANSACTIONS = 16;

    localparam int FRAGMENT_PTR_WID = $bits(FRAGMENT_PTR_T);
    localparam int MAX_FRAGMENTS = 2**FRAGMENT_PTR_WID;

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        BUF_ID_T buf_id;
        OFFSET_T offset;
    } segment_table_key_t;

    typedef struct packed {
        FRAGMENT_PTR_T ptr;
        OFFSET_T       offset;
    } segment_table_value_t;

    typedef struct packed {
        BUF_ID_T      buf_id; 
        OFFSET_T      offset_start;
        OFFSET_T      offset_end;
        SEGMENT_LEN_T len;
        logic         last;
    } segment_ctxt_t;

    typedef enum logic [1:0] {
        FRAGMENT_CREATE,
        FRAGMENT_APPEND,
        FRAGMENT_PREPEND,
        FRAGMENT_MERGE
    } fragment_action_t;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    db_intf #(.KEY_T(segment_table_key_t), .VALUE_T(segment_table_value_t)) lookup_if__append (.clk(clk));
    db_intf #(.KEY_T(segment_table_key_t), .VALUE_T(segment_table_value_t)) update_if__append (.clk(clk));

    db_intf #(.KEY_T(segment_table_key_t), .VALUE_T(segment_table_value_t)) lookup_if__prepend (.clk(clk));
    db_intf #(.KEY_T(segment_table_key_t), .VALUE_T(segment_table_value_t)) update_if__prepend (.clk(clk));

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

    segment_ctxt_t      lookup_ctxt_in;
    segment_ctxt_t      lookup_ctxt_out;

    logic               frag_ptr_alloc_req;
    logic               frag_ptr_alloc_rdy;
    FRAGMENT_PTR_T      frag_ptr_alloc_value;

    logic               __frag_valid;
    logic               __frag_init;
    fragment_action_t   __frag_action;
    FRAGMENT_PTR_T      __frag_ptr;
    OFFSET_T            __frag_offset_start;
    OFFSET_T            __frag_offset_end;

    logic               __frag_merged;
    FRAGMENT_PTR_T      __frag_merged_ptr;

    logic               delete_q__append__wr;
    segment_table_key_t delete_q__append__wr_data;
    logic               delete_q__append__rd;
    segment_table_key_t delete_q__append__rd_data;
    logic               delete_q__append__empty;
    
    logic               delete_q__prepend__wr;
    segment_table_key_t delete_q__prepend__wr_data;
    logic               delete_q__prepend__rd;
    segment_table_key_t delete_q__prepend__rd_data;
    logic               delete_q__prepend__empty;
    
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
        .KEY_T          ( segment_table_key_t ),
        .VALUE_T        ( segment_table_value_t ),
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
        .KEY_T          ( segment_table_key_t ),
        .VALUE_T        ( segment_table_value_t ),
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
    // Drive lookup interfaces
    // -------------------------------------------------
    // Perform two lookups per input key:
    //   - one lookup in 'Append' context, i.e. attempting to append new segment to existing fragment
    //   - one lookup in 'Prepend' context, i.e. attempting to prepend new segment to existing fragment
    assign lookup_if__append.req = seg_valid;
    assign lookup_if__append.key.buf_id = seg_buf_id;
    assign lookup_if__append.key.offset = seg_offset;
    assign lookup_if__append.next = 1'b0;

    assign lookup_if__prepend.req = seg_valid;
    assign lookup_if__prepend.key.buf_id = seg_buf_id;
    assign lookup_if__prepend.key.offset = seg_offset + seg_len;
    assign lookup_if__prepend.next = 1'b0;

    assign seg_ready = lookup_if__append.rdy && lookup_if__prepend.rdy;

    // Context buffer
    assign lookup_ctxt_in.buf_id       = seg_buf_id;
    assign lookup_ctxt_in.offset_start = seg_offset;
    assign lookup_ctxt_in.offset_end   = seg_offset + seg_len;
    assign lookup_ctxt_in.len          = seg_len;
    assign lookup_ctxt_in.last         = seg_last;

    assign lookup_done = lookup_if__append.ack && lookup_if__prepend.ack;

    // Check for misalignment of lookup results between append/prepend tables;
    // these tables are identical so this should never happen
    assign lookup_error = lookup_if__append.ack ^ lookup_if__prepend.ack;

    fifo_small_ctxt #(
        .DATA_WID ( $bits(segment_ctxt_t) ),
        .DEPTH    ( NUM_RD_TRANSACTIONS )
    ) i_fifo_small_ctxt__lookup_req (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr_rdy  ( ),
        .wr      ( seg_valid && seg_ready ),
        .wr_data ( lookup_ctxt_in ),
        .rd      ( lookup_done ),
        .rd_vld  ( ),
        .rd_data ( lookup_ctxt_out ),
        .oflow   ( ),
        .uflow   ( )
    );

    // Process result
    always_comb begin
        __frag_valid = 1'b0;
        __frag_init = 1'b0;
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
                    __frag_ptr = lookup_if__append.value.ptr;
                    __frag_offset_start = lookup_if__append.value.offset;
                    __frag_offset_end = lookup_ctxt_out.offset_end;
                end
                2'b10 : begin
                    __frag_action = FRAGMENT_PREPEND;
                    __frag_valid = 1'b1;
                    __frag_ptr = lookup_if__prepend.value.ptr;
                    __frag_offset_start = lookup_ctxt_out.offset_start;
                    __frag_offset_end = lookup_if__prepend.value.offset;
                end
                2'b11 : begin
                    __frag_action = FRAGMENT_MERGE;
                    __frag_valid = 1'b1;
                    __frag_ptr = lookup_if__prepend.value.ptr;
                    __frag_offset_start = lookup_if__append.value.offset;
                    __frag_offset_end = lookup_if__prepend.value.offset;
                    __frag_merged = 1'b1;
                    __frag_merged_ptr = lookup_if__append.value.ptr;
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
        frag_last          <= lookup_ctxt_out.last;
        frag_ptr           <= __frag_ptr;
        frag_offset_start  <= __frag_offset_start;
        frag_offset_end    <= __frag_offset_end;
        frag_merged        <= __frag_merged;
        frag_merged_ptr    <= __frag_merged_ptr;
    end
     
    assign update_if__append.next = 1'b0;  // Unused
    assign update_if__prepend.next = 1'b0; // Unused

    // Perform table updates according to fragment action
    always_comb begin
        update_if__append.req = 1'b0;
        update_if__append.valid = 1'b0;
        update_if__append.key.buf_id = lookup_ctxt_out.buf_id;
        update_if__append.key.offset = '0;
        update_if__append.value = '0;
        delete_q__append__wr = 1'b0;
        delete_q__append__rd = 1'b0;

        update_if__prepend.req = 1'b0;
        update_if__prepend.valid = 1'b0;
        update_if__prepend.key.buf_id = lookup_ctxt_out.buf_id;
        update_if__prepend.key.offset = '0;
        update_if__prepend.value = '0;
        delete_q__prepend__wr = 1'b0;
        delete_q__prepend__rd = 1'b0;

        if (__frag_valid) begin
            case (__frag_action)
                FRAGMENT_CREATE : begin
                    update_if__append.req = (!lookup_ctxt_out.last);
                    update_if__append.valid = 1'b1; // Insert
                    update_if__append.key.offset = lookup_ctxt_out.offset_end;
                    update_if__append.value.ptr = __frag_ptr;
                    update_if__append.value.offset = lookup_ctxt_out.offset_start;
                    
                    update_if__prepend.req = (lookup_ctxt_out.offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Insert
                    update_if__prepend.key.offset = lookup_ctxt_out.offset_start;
                    update_if__prepend.value.ptr = __frag_ptr;
                    update_if__prepend.value.offset = lookup_ctxt_out.last ? 0 : lookup_ctxt_out.offset_end;
                end
                FRAGMENT_APPEND : begin
                    update_if__append.req = (!lookup_ctxt_out.last);
                    update_if__append.valid = 1'b1; // Insert
                    update_if__append.key.offset = lookup_ctxt_out.offset_end;
                    update_if__append.value.ptr = __frag_ptr;
                    update_if__append.value.offset = __frag_offset_start;
                    delete_q__append__wr = 1'b1;

                    update_if__prepend.req = (__frag_offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Update
                    update_if__prepend.key.offset = __frag_offset_start;
                    update_if__prepend.value.ptr = __frag_ptr;
                    update_if__prepend.value.offset = lookup_ctxt_out.last ? 0 : lookup_ctxt_out.offset_end;
                end
                FRAGMENT_PREPEND : begin
                    update_if__append.req = (__frag_offset_end > 0);
                    update_if__append.valid = 1'b1; // Update
                    update_if__append.key.offset = __frag_offset_end;
                    update_if__append.value.ptr = __frag_ptr;
                    update_if__append.value.offset = lookup_ctxt_out.offset_start;

                    update_if__prepend.req = (lookup_ctxt_out.offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Insert
                    update_if__prepend.key.offset = lookup_ctxt_out.offset_start;
                    update_if__prepend.value.ptr = __frag_ptr;
                    update_if__prepend.value.offset = __frag_offset_end;
                    delete_q__prepend__wr = 1'b1;
                end
                FRAGMENT_MERGE : begin
                    update_if__append.req = (__frag_offset_end > 0);
                    update_if__append.valid = 1'b1; // Insert
                    update_if__append.key.offset = __frag_offset_end;
                    update_if__append.value.ptr = __frag_ptr;
                    update_if__append.value.offset = __frag_offset_start;
                    delete_q__append__wr = 1'b1;

                    update_if__prepend.req = (__frag_offset_start > 0);
                    update_if__prepend.valid = 1'b1; // Insert
                    update_if__prepend.key.offset = __frag_offset_start;
                    update_if__prepend.value.ptr = __frag_ptr;
                    update_if__prepend.value.offset = __frag_offset_end;
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
                update_if__append.key = delete_q__append__rd_data;
                delete_q__append__rd = 1'b1;
            end
            if (!delete_q__prepend__empty) begin
                update_if__prepend.req = 1'b1;
                update_if__prepend.valid = 1'b0;
                update_if__prepend.key = delete_q__prepend__rd_data;
                delete_q__prepend__rd = 1'b1;
            end
        end
    end

    // -------------------------------------------------
    // Deletion queues
    // -------------------------------------------------
    fifo_small   #(
        .DATA_WID ( $bits(segment_table_key_t) ),
        .DEPTH    ( 16 )
    ) i_fifo_small__delete_q__append (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr      ( delete_q__append__wr ),
        .wr_data ( delete_q__append__wr_data ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( delete_q__append__rd ),
        .rd_data ( delete_q__append__rd_data ),
        .empty   ( delete_q__append__empty ),
        .uflow   ( ),
        .count   ( )
    );

    assign delete_q__append__wr_data.buf_id = lookup_ctxt_out.buf_id;
    assign delete_q__append__wr_data.offset = lookup_ctxt_out.offset_start;

    fifo_small   #(
        .DATA_WID ( $bits(segment_table_key_t) ),
        .DEPTH    ( 16 )
    ) i_fifo_small__delete_q__prepend (
        .clk     ( clk ),
        .srst    ( __srst ),
        .wr      ( delete_q__prepend__wr ),
        .wr_data ( delete_q__prepend__wr_data ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( delete_q__prepend__rd ),
        .rd_data ( delete_q__prepend__rd_data ),
        .empty   ( delete_q__prepend__empty ),
        .uflow   ( ),
        .count   ( )
    );
   
    assign delete_q__prepend__wr_data.buf_id = lookup_ctxt_out.buf_id;
    assign delete_q__prepend__wr_data.offset = lookup_ctxt_out.offset_end;

endmodule : sar_reassembly_cache
