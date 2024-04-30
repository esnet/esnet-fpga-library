module sar_reassembly
#(
    parameter type BUF_ID_T      = logic, // (Type) Reassembly buffer (context) pointer
    parameter type OFFSET_T      = logic, // (Type) Offset in bytes describing location of segment within frame
    parameter type SEGMENT_LEN_T = logic, // (Type) Length in bytes of current segment
    parameter type TIMER_T       = logic, // (Type) Frame expiry timer
    parameter int  MAX_FRAGMENTS = 8192,  // Number of disjoint (post-coalescing) fragments supported at any given time (across all buffers)
    parameter int  BURST_SIZE    = 8
)(
    // Clock/reset
    input  logic          clk,
    input  logic          srst,

    input  logic          en,

    output logic          init_done,

    // Segment (input) interface
    output logic          seg_ready,
    input  logic          seg_valid,
    input  BUF_ID_T       seg_buf_id,
    input  OFFSET_T       seg_offset,
    input  SEGMENT_LEN_T  seg_len,
    input  logic          seg_last,

    // Timer interface
    input  logic          ms_tick,

    // Frame (output) interface
    input  logic          frame_ready,
    output logic          frame_valid,
    output BUF_ID_T       frame_buf_id,
    output OFFSET_T       frame_len,

    // AXI-L control
    axi4l_intf.peripheral axil_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import sar_pkg::*;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS);
    localparam type FRAGMENT_PTR_T = logic[FRAGMENT_PTR_WID-1:0];

    
    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        BUF_ID_T buf_id;
        OFFSET_T offset;
    } KEY_T;

    typedef struct packed {
        FRAGMENT_PTR_T ptr;
        OFFSET_T       offset;
    } VALUE_T;

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic           __srst;
    logic           __en;
    logic           init_done__cache;
    logic           init_done__state;

    logic           frag_valid;
    logic           frag_init;
    BUF_ID_T        frag_buf_id;
    FRAGMENT_PTR_T  frag_ptr;
    logic           frag_last;
    OFFSET_T        frag_offset_start;
    OFFSET_T        frag_offset_end;

    logic           frag_merged;
    FRAGMENT_PTR_T  frag_merged_ptr;

    logic           frag_ptr_dealloc_rdy;
    logic           frag_ptr_dealloc_req;
    FRAGMENT_PTR_T  frag_ptr_dealloc_value;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if__append  (.clk(clk));
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if__prepend (.clk(clk));

    axi4l_intf axil_if__regs ();
    axi4l_intf axil_if__regs__clk ();
    axi4l_intf axil_if__cache ();
    axi4l_intf axil_if__state ();

    sar_reassembly_reg_intf reg_if ();

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Block-level decoder
    sar_reassembly_decoder i_sar_reassembly_decoder (
        .axil_if       ( axil_if ),
        .regs_axil_if  ( axil_if__regs ),
        .cache_axil_if ( axil_if__cache ),
        .state_axil_if ( axil_if__state )
    );

    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if__regs ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__regs__clk )
    );

    sar_reassembly_reg_blk i_sar_reassembly_reg_blk (
        .axil_if    ( axil_if__regs__clk ),
        .reg_blk_if ( reg_if )
    );

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
    assign init_done = init_done__cache && init_done__state;

    // -------------------------------------------------
    // Reassembly segment cache
    // -------------------------------------------------
    sar_reassembly_cache       #(
        .BUF_ID_T               ( BUF_ID_T ),
        .OFFSET_T               ( OFFSET_T ),
        .SEGMENT_LEN_T          ( SEGMENT_LEN_T ),
        .FRAGMENT_PTR_T         ( FRAGMENT_PTR_T ),
        .BURST_SIZE             ( BURST_SIZE )
    ) i_sar_reassembly_cache    (
        .clk                    ( clk ),
        .srst                   ( __srst ),
        .en                     ( __en ),
        .init_done              ( init_done__cache ),
        .seg_ready              ( seg_ready ),
        .seg_valid              ( seg_valid ),
        .seg_buf_id             ( seg_buf_id ),
        .seg_offset             ( seg_offset ),
        .seg_len                ( seg_len ),
        .seg_last               ( seg_last ),
        .frag_valid             ( frag_valid ),
        .frag_init              ( frag_init ),
        .frag_buf_id            ( frag_buf_id ),
        .frag_last              ( frag_last ),
        .frag_ptr               ( frag_ptr ),
        .frag_offset_start      ( frag_offset_start ),
        .frag_offset_end        ( frag_offset_end ),
        .frag_merged            ( frag_merged ),               
        .frag_merged_ptr        ( frag_merged_ptr ),               
        .frag_ptr_dealloc_rdy   ( frag_ptr_dealloc_rdy ),
        .frag_ptr_dealloc_req   ( frag_ptr_dealloc_req ),
        .frag_ptr_dealloc_value ( frag_ptr_dealloc_value ),
        .ctrl_if__append        ( ctrl_if__append ),
        .ctrl_if__prepend       ( ctrl_if__prepend ),
        .axil_if                ( axil_if__cache )
    );

    // -------------------------------------------------
    // Reassembly state table
    // -------------------------------------------------
    sar_reassembly_state       #(
        .BUF_ID_T               ( BUF_ID_T ),
        .OFFSET_T               ( OFFSET_T ),
        .SEGMENT_LEN_T          ( SEGMENT_LEN_T ),
        .FRAGMENT_PTR_T         ( FRAGMENT_PTR_T ),
        .TIMER_T                ( TIMER_T )
    ) i_sar_reassembly_state    (
        .clk                    ( clk ),
        .srst                   ( __srst ),
        .en                     ( __en ),
        .init_done              ( init_done__state ),
        .frag_valid             ( frag_valid ),
        .frag_init              ( frag_init ),
        .frag_buf_id            ( frag_buf_id ),
        .frag_last              ( frag_last ),
        .frag_ptr               ( frag_ptr ),
        .frag_offset_start      ( frag_offset_start ),
        .frag_offset_end        ( frag_offset_end ),
        .frag_merged            ( frag_merged ),
        .frag_merged_ptr        ( frag_merged_ptr ),
        .ms_tick                ( ms_tick ),
        .frame_ready            ( frame_ready ),
        .frame_valid            ( frame_valid ),
        .frame_buf_id           ( frame_buf_id ),
        .frame_len              ( frame_len ),
        .frag_ptr_dealloc_rdy   ( frag_ptr_dealloc_rdy ),
        .frag_ptr_dealloc_req   ( frag_ptr_dealloc_req ),
        .frag_ptr_dealloc_value ( frag_ptr_dealloc_value ),
        .ctrl_if__append        ( ctrl_if__append ),
        .ctrl_if__prepend       ( ctrl_if__prepend ),
        .axil_if                ( axil_if__state )
    );

endmodule : sar_reassembly
