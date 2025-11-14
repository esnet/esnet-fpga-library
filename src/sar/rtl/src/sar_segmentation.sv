module sar_segmentation
#(
    parameter int NUM_FRAME_BUFFERS = 1,      // Number of buffers supported
    parameter int MAX_FRAME_SIZE    = 1,      // Maximum frame length (in bytes)
    parameter int MAX_SEGMENT_LEN   = 16348,  // Maximum configurable segment length (in bytes)
    // Derived parameters (don't override)
    parameter int BUF_ID_WID      = $clog2(NUM_FRAME_BUFFERS),
    parameter int OFFSET_WID      = $clog2(MAX_FRAME_SIZE),
    parameter int FRAME_SIZE_WID  = $clog2(MAX_FRAME_SIZE+1),
    parameter int SEGMENT_LEN_WID = $clog2(MAX_SEGMENT_LEN+1)
)(
    // Clock/reset
    input  logic                       clk,
    input  logic                       srst,

    output logic                       init_done,

    // Frame (input) interface
    output logic                       frame_ready,
    input  logic                       frame_valid,
    input  logic [BUF_ID_WID-1:0]      frame_buf_id,
    input  logic [FRAME_SIZE_WID-1:0]  frame_len,

    // Segment (output) interface
    input  logic                       seg_ready,
    output logic                       seg_valid,
    output logic [BUF_ID_WID-1:0]      seg_buf_id,
    output logic [OFFSET_WID-1:0]      seg_offset,
    output logic [SEGMENT_LEN_WID-1:0] seg_len,
    output logic                       seg_last,

    // AXI-L control
    axi4l_intf.peripheral              axil_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import sar_pkg::*;

    // -------------------------------------------------
    // Typedefs
    // -------------------------------------------------
    typedef enum logic [1:0] {
        RESET,
        READY,
        PROCESSING,
        DONE
    } state_t;

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic __srst;

    state_t state;
    state_t nxt_state;

    logic reset_offset;

    logic [OFFSET_WID-1:0] len;
    logic [OFFSET_WID-1:0] offset;
    logic [OFFSET_WID-1:0] offset_last;
    logic                  last;
    logic [SEGMENT_LEN_WID-1:0] len_last;

    logic [SEGMENT_LEN_WID-1:0] cfg_seg_len;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    axi4l_intf axil_if__clk ();

    sar_segmentation_reg_intf reg_if ();

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    sar_segmentation_reg_blk i_sar_segmentation_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    // Info
    assign reg_if.info_nxt_v = 1'b1;
    assign reg_if.info_nxt.num_buffers = NUM_FRAME_BUFFERS;
    assign reg_if.info_nxt.max_segment_len = MAX_SEGMENT_LEN;

    assign reg_if.info_frame_nxt_v = 1'b1;
    assign reg_if.info_frame_nxt.max_size = MAX_FRAME_SIZE;

    // Status
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset_mon = __srst;
    assign reg_if.status_nxt.ready_mon = init_done;

    // Block reset
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    // Segment length config
    always @(posedge clk) begin
        if (state == READY) cfg_seg_len <= reg_if._config.seg_len[SEGMENT_LEN_WID-1:0];
    end

    // -------------------------------------------------
    // Segmentation FSM
    // -------------------------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (__srst) state <= RESET;
        else        state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        frame_ready = 1'b0;
        reset_offset = 1'b1;
        seg_valid = 1'b0;
        case (state)
            RESET : begin
                nxt_state = READY;
            end
            READY : begin
                frame_ready = 1'b1;
                if (frame_valid) nxt_state = PROCESSING;
            end
            PROCESSING : begin
                seg_valid = 1'b1;
                reset_offset = 1'b0;
                if (seg_ready) begin
                    if (seg_last) nxt_state = DONE;
                end
            end
            DONE : begin
                nxt_state = READY;
            end
        endcase
    end

    // Latch frame metadata
    always_ff @(posedge clk) begin
        if (frame_valid && frame_ready) begin
            seg_buf_id <= frame_buf_id;
            len <= frame_len;
            offset_last <= frame_len - cfg_seg_len;
        end
    end

    // Track frame offset
    always_ff @(posedge clk) begin
        if (reset_offset) begin
            offset <= '0;
            last <= (frame_len <= cfg_seg_len);
            len_last <= cfg_seg_len;
        end else if (seg_valid && seg_ready) begin
            offset <= offset + cfg_seg_len;
            last <= (offset_last - offset) < cfg_seg_len;
            len_last <= frame_len - offset - cfg_seg_len;
        end
    end

    assign seg_offset = offset;
    assign seg_len = last ? len_last : cfg_seg_len;
    assign seg_last = last;

endmodule : sar_segmentation
