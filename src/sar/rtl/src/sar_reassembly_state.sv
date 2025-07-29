module sar_reassembly_state
    import sar_pkg::*;
#(
    parameter type BUF_ID_T       = logic, // (Type) Reassembly buffer (context) pointer
    parameter type OFFSET_T       = logic, // (Type) Offset in bytes describing location of segment within frame
    parameter type SEGMENT_LEN_T  = logic, // (Type) Length in bytes of current segment 
    parameter type FRAGMENT_PTR_T = logic, // (Type) Coalesce record pointer
    parameter type TIMER_T        = logic  // (Type) Idle timer
)(
    // Clock/reset
    input  logic             clk,
    input  logic             srst,

    input  logic             en,

    output logic             init_done,

    // Segment input
    input  logic             frag_valid,
    input  logic             frag_init,
    input  BUF_ID_T          frag_buf_id,
    input  logic             frag_last,
    input  FRAGMENT_PTR_T    frag_ptr,
    input  OFFSET_T          frag_offset_start,
    input  OFFSET_T          frag_offset_end,

    input  logic             frag_merged,
    input  FRAGMENT_PTR_T    frag_merged_ptr,

    // Timer interface
    input  logic             ms_tick,

    // Buffer completion interface
    input  logic             frame_ready,
    output logic             frame_valid,
    output BUF_ID_T          frame_buf_id,
    output OFFSET_T          frame_len,

    // Fragment pointer deallocation interface
    input  logic             frag_ptr_dealloc_rdy,
    output logic             frag_ptr_dealloc_req,
    output FRAGMENT_PTR_T    frag_ptr_dealloc_value,

    // Cache control interfaces
    db_ctrl_intf.controller  ctrl_if__append,
    db_ctrl_intf.controller  ctrl_if__prepend,

    // AXI-L control
    axi4l_intf.peripheral    axil_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import state_pkg::*;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    // State vector definition
    localparam state_pkg::vector_t FRAGMENT_STATE_VECTOR = '{
        NUM_ELEMENTS : 6,
        ELEMENTS : '{
            0: '{TYPE: ELEMENT_TYPE_WRITE,   STATE_WID: 1,                    UPDATE_WID: 1,               RETURN_MODE: RETURN_MODE_PREV_STATE, REAP_MODE: REAP_MODE_CLEAR}, // Valid
            1: '{TYPE: ELEMENT_TYPE_WRITE,   STATE_WID: $bits(BUF_ID_T),      UPDATE_WID: $bits(BUF_ID_T), RETURN_MODE: RETURN_MODE_PREV_STATE, REAP_MODE: REAP_MODE_CLEAR}, // Buffer ID
            2: '{TYPE: ELEMENT_TYPE_WRITE,   STATE_WID: $bits(OFFSET_T),      UPDATE_WID: $bits(OFFSET_T), RETURN_MODE: RETURN_MODE_PREV_STATE, REAP_MODE: REAP_MODE_CLEAR}, // Offset (start)
            3: '{TYPE: ELEMENT_TYPE_WRITE,   STATE_WID: $bits(OFFSET_T),      UPDATE_WID: $bits(OFFSET_T), RETURN_MODE: RETURN_MODE_PREV_STATE, REAP_MODE: REAP_MODE_CLEAR}, // Offset (end)
            4: '{TYPE: ELEMENT_TYPE_WRITE,   STATE_WID: $bits(TIMER_T),       UPDATE_WID: $bits(TIMER_T),  RETURN_MODE: RETURN_MODE_PREV_STATE, REAP_MODE: REAP_MODE_CLEAR}, // Timer
            5: '{TYPE: ELEMENT_TYPE_FLAGS,   STATE_WID: 1,                    UPDATE_WID: 1,               RETURN_MODE: RETURN_MODE_PREV_STATE, REAP_MODE: REAP_MODE_CLEAR}, // Last
            default: DEFAULT_STATE_ELEMENT
        }
    };

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        BUF_ID_T buf_id;
        OFFSET_T offset_start;
        OFFSET_T offset_end;
    } notify_ctxt_t;

    typedef struct packed {
        reassembly_notify_type_t _type;
        notify_ctxt_t            ctxt;
    } notify_msg_t;

    typedef struct packed {
        FRAGMENT_PTR_T id;
        notify_ctxt_t  ctxt;
    } notify_q_data_t;

    typedef struct packed {
        logic         valid;
        BUF_ID_T      buf_id;
        OFFSET_T      offset_start;
        OFFSET_T      offset_end;
        TIMER_T       timer;
        logic         last;
    } state_t;

    typedef struct packed {
        logic         valid;
        BUF_ID_T      buf_id;
        OFFSET_T      offset_start;
        OFFSET_T      offset_end;
        TIMER_T       timer;
        logic         last;
    } update_t;
 
    typedef enum logic [3:0] {
        RESET,
        IDLE,
        PROCESS_DONE,
        PROCESS_MERGED,
        PROCESS_EXPIRED,
        NOTIFY_DONE,
        APPEND_CACHE_DELETE_REQ,
        APPEND_CACHE_DELETE_PENDING,
        PREPEND_CACHE_DELETE_REQ,
        PREPEND_CACHE_DELETE_PENDING,
        DELETE_STATE_REQ,
        DELETE_STATE_PENDING,
        DEALLOC_PTR
    } fsm_state_t;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    state_intf #(.ID_T(FRAGMENT_PTR_T), .STATE_T(state_t), .UPDATE_T(update_t)) update_if (.clk(clk));
    state_intf #(.ID_T(FRAGMENT_PTR_T), .STATE_T(state_t), .UPDATE_T(update_t)) ctrl_if (.clk(clk));
    state_event_intf #(.ID_T(FRAGMENT_PTR_T), .MSG_T(notify_msg_t)) notify_if (.clk(clk));

    db_intf #(.KEY_T(FRAGMENT_PTR_T), .VALUE_T(state_t)) db_wr_if (.clk(clk));
    db_intf #(.KEY_T(FRAGMENT_PTR_T), .VALUE_T(state_t)) db_rd_if (.clk(clk));

    axi4l_intf axil_if__state_core ();
    axi4l_intf axil_if__state_check ();

    state_check_intf #(.STATE_T(state_t), .MSG_T(notify_msg_t)) state_check_if (.clk(clk));

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic          db_init;
    logic          db_init_done;

    TIMER_T        timer;

    logic           q_done__wr;
    notify_q_data_t q_done__wr_data;
    logic           q_done__rd;
    notify_q_data_t q_done__rd_data;
    logic           q_done__empty;

    logic           q_merged__wr;
    FRAGMENT_PTR_T  q_merged__wr_data;
    logic           q_merged__rd;
    FRAGMENT_PTR_T  q_merged__rd_data;
    logic           q_merged__empty;

    logic          q_expired__wr;
    FRAGMENT_PTR_T q_expired__wr_data;
    logic          q_expired__rd;
    FRAGMENT_PTR_T q_expired__rd_data;
    logic          q_expired__empty;

    fsm_state_t fsm_state;
    fsm_state_t nxt_fsm_state;

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Block-level decoder
    sar_reassembly_state_decoder i_sar_reassembly_decoder (
        .axil_if       ( axil_if ),
        .check_axil_if (axil_if__state_check ),
        .core_axil_if  (axil_if__state_core )
    );

    // -------------------------------------------------
    // State database implementation
    // -------------------------------------------------
    state_core #(
        .ID_T   ( FRAGMENT_PTR_T ),
        .SPEC   ( FRAGMENT_STATE_VECTOR ),
        .NOTIFY_MSG_T ( notify_msg_t )
    ) i_state_core (
        .clk          ( clk ),
        .srst         ( srst ),
        .en           ( en ),
        .init_done    ( init_done ),
        .axil_if      ( axil_if__state_core ),
        .update_if    ( update_if ),
        .ctrl_if      ( ctrl_if ),
        .check_if     ( state_check_if ),
        .notify_if    ( notify_if ),
        .db_init      ( db_init ),
        .db_init_done ( db_init_done ),
        .db_wr_if     ( db_wr_if ),
        .db_rd_if     ( db_rd_if )
    );

    // -----------------------------
    // State vector storage array
    // -----------------------------
    db_store_array  #(
        .KEY_T       ( FRAGMENT_PTR_T ),
        .VALUE_T     ( state_t ),
        .TRACK_VALID ( 0 )
    ) i_db_store_array (
        .clk         ( clk ),
        .srst        ( srst ),
        .init        ( db_init ),
        .init_done   ( db_init_done ),
        .db_wr_if    ( db_wr_if ),
        .db_rd_if    ( db_rd_if )
    );

    // -------------------------------------------------
    // Millisecond timer (for expiring idle fragments)
    // -------------------------------------------------
    initial timer = '0;
    always @(posedge clk) begin
        if (srst) timer <= '0;
        else if (ms_tick) timer <= timer + 1;
    end

    // -------------------------------------------------
    // State polling FSM
    // -------------------------------------------------
    sar_reassembly_state_check #(
        .TIMER_T    ( TIMER_T ),
        .STATE_T    ( state_t )
    ) i_sar_reassembly_state_check (
        .clk        ( clk ),
        .srst       ( srst ),
        .axil_if    ( axil_if__state_check ),
        .check_if   ( state_check_if ),
        .timer      ( timer )
    );

    // -------------------------------------------------
    // Drive update interface
    // -------------------------------------------------
    assign update_if.req = frag_valid;
    assign update_if.init = frag_init;
    assign update_if.id = frag_ptr;
    assign update_if.update.valid = 1'b1;
    assign update_if.update.buf_id = frag_buf_id;
    assign update_if.update.offset_start = frag_offset_start;
    assign update_if.update.offset_end = frag_offset_end;
    assign update_if.update.timer = timer;
    assign update_if.update.last = frag_last;
    assign update_if.ctxt = UPDATE_CTXT_DATAPATH;
  
    // -------------------------------------------------
    // State vector deletion logic
    // -------------------------------------------------
    // Deletion queue (from completed fragments)
    fifo_small  #(
        .DATA_T  ( notify_q_data_t ),
        .DEPTH   ( 8 )
    ) i_fifo_small__q_done (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr      ( q_done__wr ),
        .wr_data ( q_done__wr_data ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( q_done__rd ),
        .rd_data ( q_done__rd_data ),
        .empty   ( q_done__empty ),
        .uflow   ( ),
        .count   ( )
    );

    assign q_done__wr = notify_if.evt && (notify_if.msg._type == REASSEMBLY_NOTIFY_DONE);
    assign q_done__wr_data.id = notify_if.id;
    assign q_done__wr_data.ctxt = notify_if.msg.ctxt;

    // Deletion queue (from expired fragments)
    fifo_small  #(
        .DATA_T  ( FRAGMENT_PTR_T ),
        .DEPTH   ( 8 )
    ) i_fifo_small__q_expired (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr      ( q_expired__wr ),
        .wr_data ( q_expired__wr_data ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( q_expired__rd ),
        .rd_data ( q_expired__rd_data ),
        .empty   ( q_expired__empty ),
        .uflow   ( ),
        .count   ( )
    );

    assign q_expired__wr = notify_if.evt && (notify_if.msg._type == REASSEMBLY_NOTIFY_EXPIRED);
    assign q_expired__wr_data = notify_if.id;

    // Deletion queue (from merged fragments)
    fifo_small  #(
        .DATA_T  ( FRAGMENT_PTR_T ),
        .DEPTH   ( 8 )
    ) i_fifo_small__q_merged (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr      ( q_merged__wr ),
        .wr_data ( q_merged__wr_data ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( q_merged__rd ),
        .rd_data ( q_merged__rd_data ),
        .empty   ( q_merged__empty ),
        .uflow   ( ),
        .count   ( )
    );
   
    assign q_merged__wr = frag_merged;
    assign q_merged__wr_data = frag_merged_ptr;

    // Deletion state machine
    initial fsm_state = RESET;
    always @(posedge clk) begin
        if (srst) fsm_state <= RESET;
        else      fsm_state <= nxt_fsm_state;
    end

    always_comb begin
        nxt_fsm_state = fsm_state;
        q_done__rd = 1'b0;
        q_expired__rd = 1'b0;
        q_merged__rd = 1'b0;
        ctrl_if.req = 1'b0;
        ctrl_if.ctxt = UPDATE_CTXT_CONTROL;
        frag_ptr_dealloc_req = 1'b0;
        frame_valid = 1'b0;
        case (fsm_state)
            RESET : begin
                nxt_fsm_state = IDLE;
            end
            IDLE : begin
                if      (!q_merged__empty)              nxt_fsm_state = PROCESS_MERGED;
                else if (!q_done__empty && frame_ready) nxt_fsm_state = PROCESS_DONE;
                else if (!q_expired__empty)             nxt_fsm_state = PROCESS_EXPIRED;
            end
            PROCESS_MERGED : begin
                q_merged__rd = 1'b1;
                nxt_fsm_state = DELETE_STATE_REQ;
            end
            PROCESS_DONE : begin
                q_done__rd = 1'b1;
                nxt_fsm_state = NOTIFY_DONE;
            end
            PROCESS_EXPIRED : begin
                q_expired__rd = 1'b1;
                nxt_fsm_state = APPEND_CACHE_DELETE_REQ;
            end
            NOTIFY_DONE : begin
                frame_valid = 1'b1;
                if (frame_ready) nxt_fsm_state = DELETE_STATE_REQ;
            end
            APPEND_CACHE_DELETE_REQ : begin
                nxt_fsm_state = DELETE_STATE_REQ;
            end
            APPEND_CACHE_DELETE_PENDING : begin
                nxt_fsm_state = IDLE;
            end
            PREPEND_CACHE_DELETE_REQ : begin
                nxt_fsm_state = IDLE;
            end
            PREPEND_CACHE_DELETE_PENDING : begin
                nxt_fsm_state = IDLE;
            end
            DELETE_STATE_REQ : begin
                ctrl_if.req = 1'b1;
                ctrl_if.ctxt = UPDATE_CTXT_REAP;
                if (ctrl_if.rdy) nxt_fsm_state = DELETE_STATE_PENDING;
            end
            DELETE_STATE_PENDING : begin
                if (ctrl_if.ack) begin
                    nxt_fsm_state = DEALLOC_PTR;
                end
            end
            DEALLOC_PTR : begin
                frag_ptr_dealloc_req = 1'b1;
                if (frag_ptr_dealloc_rdy) nxt_fsm_state = IDLE;
            end
        endcase
    end

    // Drive control interface in reap mode; each state element is set to clear on a reap operation
    assign ctrl_if.ctxt = UPDATE_CTXT_REAP;
    assign ctrl_if.update = 'x; 

    // Latch fragment ptr for deletion
    always_ff @(posedge clk) begin
        if      (q_done__rd)    ctrl_if.id <= q_done__rd_data.id;
        else if (q_expired__rd) ctrl_if.id <= q_expired__rd_data;
        else if (q_merged__rd)  ctrl_if.id <= q_merged__rd_data;
    end

    // Latch key for deletion from append cache
    
    // Latch frame data
    always @(posedge clk) begin
        if (q_done__rd) begin
            frame_buf_id <= q_done__rd_data.ctxt.buf_id;
            frame_len <= q_done__rd_data.ctxt.offset_end;
        end
    end
        

endmodule : sar_reassembly_state
