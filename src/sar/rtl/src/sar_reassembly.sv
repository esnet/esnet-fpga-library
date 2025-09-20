module sar_reassembly
#(
    parameter int BUF_ID_WID       = 1, // Width (in bits) of reassembly buffer (context) pointer
    parameter int OFFSET_WID       = 1, // Width (in bits) of byte offset describing location of segment within frame
    parameter int SEGMENT_LEN_WID  = 1, // Width (in bits) of byte length of current segment 
    parameter int TIMER_WID        = 1, // Width (in bits) of frame expiry timer
    parameter int MAX_FRAGMENTS    = 8192,  // Number of disjoint (post-coalescing) fragments supported at any given time (across all buffers)
    parameter int BURST_SIZE       = 8
)(
    // Clock/reset
    input  logic                       clk,
    input  logic                       srst,

    input  logic                       en,

    output logic                       init_done,

    // Segment (input) interface
    output logic                       seg_ready,
    input  logic                       seg_valid,
    input  logic [BUF_ID_WID-1:0]      seg_buf_id,
    input  logic [OFFSET_WID-1:0]      seg_offset,
    input  logic [SEGMENT_LEN_WID-1:0] seg_len,
    input  logic                       seg_last,

    // Timer interface
    input  logic                       ms_tick,

    // Frame (output) interface
    input  logic                       frame_ready,
    output logic                       frame_valid,
    output logic [BUF_ID_WID-1:0]      frame_buf_id,
    output logic [OFFSET_WID-1:0]      frame_len,

    // AXI-L control
    axi4l_intf.peripheral              axil_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import sar_pkg::*;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int FRAGMENT_PTR_WID = $clog2(MAX_FRAGMENTS);

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef struct packed {
        logic [BUF_ID_WID-1:0] buf_id;
        logic [OFFSET_WID-1:0] offset;
    } key_t;
    localparam int KEY_WID = $bits(key_t);

    typedef struct packed {
        logic [FRAGMENT_PTR_WID-1:0] ptr;
        logic [OFFSET_WID-1:0]       offset;
    } value_t;
    localparam int VALUE_WID = $bits(value_t);

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic __srst;
    logic __en;
    logic init_done__cache;
    logic init_done__state;

    logic                         frag_valid;
    logic                         frag_init;
    logic [BUF_ID_WID-1:0]        frag_buf_id;
    logic [FRAGMENT_PTR_WID-1:0]  frag_ptr;
    logic                         frag_last;
    logic [OFFSET_WID-1:0]        frag_offset_start;
    logic [OFFSET_WID-1:0]        frag_offset_end;

    logic                         frag_merged;
    logic [FRAGMENT_PTR_WID-1:0]  frag_merged_ptr;

    logic                         frag_ptr_dealloc_rdy;
    logic                         frag_ptr_dealloc_req;
    logic [FRAGMENT_PTR_WID-1:0]  frag_ptr_dealloc_value;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if__append  (.clk);
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) ctrl_if__prepend (.clk);

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
        .BUF_ID_WID             ( BUF_ID_WID ),
        .OFFSET_WID             ( OFFSET_WID ),
        .SEGMENT_LEN_WID        ( SEGMENT_LEN_WID ),
        .FRAGMENT_PTR_WID       ( FRAGMENT_PTR_WID ),
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
        .BUF_ID_WID             ( BUF_ID_WID ),
        .OFFSET_WID             ( OFFSET_WID ),
        .SEGMENT_LEN_WID        ( SEGMENT_LEN_WID ),
        .FRAGMENT_PTR_WID       ( FRAGMENT_PTR_WID ),
        .TIMER_WID              ( TIMER_WID )
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
