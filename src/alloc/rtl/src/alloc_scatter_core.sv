module alloc_scatter_core #(
    parameter int  CONTEXTS = 1,
    parameter int  PTR_WID = 1,
    parameter int  BUFFER_SIZE = 1,
    parameter int  MAX_FRAME_SIZE = 16384,
    parameter int  META_WID = 1,
    parameter int  Q_DEPTH = 32,
    // Derived parameters (don't override)
    parameter int  FRAME_SIZE_WID = $clog2(MAX_FRAME_SIZE+1),
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
) (
    // Clock/reset
    input logic            clk,
    input logic            srst = 1'b0,

    // Control
    input  logic           en,

    // Scatter interface
    alloc_intf.store_rx    scatter_if [CONTEXTS],

    // Completion interface
    output logic                      frame_valid [CONTEXTS],
    output logic                      frame_error,
    output logic [PTR_WID-1:0]        frame_ptr,
    output logic [FRAME_SIZE_WID-1:0] frame_size,

    // Pointer allocation interface
    output logic                alloc_req,
    input  logic                alloc_rdy,
    input  logic [PTR_WID-1:0]  alloc_ptr,

    // Descriptor write interface
    mem_wr_intf.controller desc_mem_wr_if,
    input  logic           desc_mem_init_done
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);

    localparam int  CTXT_SEL_WID = $clog2(CONTEXTS);
    localparam type CTXT_SEL_T = logic [CTXT_SEL_WID-1:0];

    localparam type DESC_T = alloc_pkg::alloc#(BUFFER_SIZE, PTR_WID, META_WID)::desc_t;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [2:0] {
        RESET,
        DISABLED,
        IDLE,
        WRITE,
        DONE,
        ERROR
    } state_t;

    typedef struct packed {
        logic                eof;
        logic                sof;
        logic [SIZE_WID-1:0] size;
        logic [PTR_WID-1:0]  ptr;
        logic [META_WID-1:0] meta;
        logic                err;
    } req_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    CTXT_SEL_T alloc_ctxt_sel;
    CTXT_SEL_T ctxt_sel;
    CTXT_SEL_T ctxt_sel_r;

    state_t state;
    state_t nxt_state;

    logic   alloc_q_wr_rdy [CONTEXTS];

    logic   arb;
    logic   done;
    logic   error;

    logic   mem_wr_req;
    logic   mem_wr_rdy;

    logic [PTR_WID-1:0]         _frame_ptr  [CONTEXTS];
    logic [FRAME_SIZE_WID-1:0]  _frame_size [CONTEXTS];
    logic                       _frame_error[CONTEXTS];

    logic [CONTEXTS-1:0]  desc_valid;
    logic [PTR_WID-1:0]   desc_ptr [CONTEXTS];
    DESC_T                desc     [CONTEXTS];
    logic [PTR_WID-1:0]   _desc_ptr;
    DESC_T                _desc;

    // Simple round-robin distribution function for pointer allocation prefetch
    initial alloc_ctxt_sel = 0;
    always @(posedge clk) begin
        alloc_ctxt_sel <= alloc_ctxt_sel < CONTEXTS-1 ? alloc_ctxt_sel + 1 : 0;
    end

    // Prefetch new pointer any time there is somewhere to hold onto it
    assign alloc_req = alloc_q_wr_rdy[alloc_ctxt_sel];

    generate
        for (genvar g_ctxt = 0; g_ctxt < CONTEXTS; g_ctxt++) begin : g__ctxt
            // (Local) signals
            logic               __alloc_q_wr;
            logic               __alloc_ptr_valid;
            logic [PTR_WID-1:0] __alloc_ptr;
            logic               __req_q_rd;
            req_ctxt_t          __req_ctxt_in;
            req_ctxt_t          __req_ctxt_nxt;
            logic               __req_ctxt_nxt_valid;
            logic               __req_ctxt_valid;
            req_ctxt_t          __req_ctxt;

            // Pre-fetch pointers to available buffers into per-context queues
            fifo_ctxt    #(
                .DATA_WID ( PTR_WID ),
                .DEPTH    ( Q_DEPTH )
            ) i_fifo_ctxt__alloc_q (
                .clk,
                .srst,
                .wr_rdy   ( alloc_q_wr_rdy[g_ctxt] ),
                .wr       ( __alloc_q_wr ),
                .wr_data  ( alloc_ptr ),
                .rd       ( scatter_if[g_ctxt].req ),
                .rd_vld   ( __alloc_ptr_valid ),
                .rd_data  ( __alloc_ptr ),
                .oflow    ( ),
                .uflow    ( )
            );

            assign __alloc_q_wr = (alloc_ctxt_sel == g_ctxt) && alloc_rdy;

            // Ready for next buffer request when a buffer is available
            // and there is somewhere to hold on to the request
            assign scatter_if[g_ctxt].rdy = __alloc_ptr_valid;
            assign scatter_if[g_ctxt].ptr = __alloc_ptr;

            // Request queue
            assign __req_ctxt_in.sof  = scatter_if[g_ctxt].sof;
            assign __req_ctxt_in.ptr  = scatter_if[g_ctxt].nxt_ptr;
            assign __req_ctxt_in.eof  = scatter_if[g_ctxt].eof;
            assign __req_ctxt_in.size = scatter_if[g_ctxt].size;
            assign __req_ctxt_in.meta = scatter_if[g_ctxt].meta;
            assign __req_ctxt_in.err  = scatter_if[g_ctxt].err;
  
            fifo_ctxt    #(
                .DATA_WID ( $bits(req_ctxt_t) ),
                .DEPTH    ( Q_DEPTH )
            ) i_fifo_ctxt__req_q (
                .clk,
                .srst,
                .wr_rdy   ( scatter_if[g_ctxt].ack ),
                .wr       ( scatter_if[g_ctxt].vld ),
                .wr_data  ( __req_ctxt_in ),
                .rd       ( __req_q_rd ),
                .rd_vld   ( __req_ctxt_nxt_valid ),
                .rd_data  ( __req_ctxt_nxt ),
                .oflow    ( ),
                .uflow    ( )
            );

            // Register to allow peeking at allocated pointer for next frame segment
            initial __req_ctxt_valid = 1'b0;
            always @(posedge clk) begin
                if (srst) __req_ctxt_valid <= 1'b0;
                else if (__req_q_rd) __req_ctxt_valid <= __req_ctxt_nxt_valid;
            end

            assign __req_q_rd = !__req_ctxt_valid || ((ctxt_sel_r == g_ctxt) && mem_wr_req && mem_wr_rdy);

            always_ff @(posedge clk) if (__req_q_rd) __req_ctxt <= __req_ctxt_nxt;

            // Maintain full-frame context
            always_ff @(posedge clk) begin
                if (__req_ctxt.sof) _frame_ptr[g_ctxt] <= __req_ctxt.ptr;
            end

            initial _frame_size[g_ctxt] = 0;
            always @(posedge clk) begin
                if (__req_ctxt.sof) _frame_size[g_ctxt] <= 0;
                if ((ctxt_sel_r == g_ctxt) && mem_wr_req && mem_wr_rdy) begin
                    if (__req_ctxt.eof) _frame_size[g_ctxt] <= _frame_size[g_ctxt] + __req_ctxt.size;
                    else                _frame_size[g_ctxt] <= _frame_size[g_ctxt] + BUFFER_SIZE;
                end
            end

            initial _frame_error[g_ctxt] = 1'b0;
            always @(posedge clk) begin
                if (__req_ctxt.sof)      _frame_error[g_ctxt] <= __req_ctxt.err;
                else if (__req_ctxt.err) _frame_error[g_ctxt] <= 1'b1;
            end

            assign desc_valid[g_ctxt] = __req_ctxt_valid && (__req_ctxt.eof || __req_ctxt_nxt_valid);
            assign desc_ptr[g_ctxt]     = __req_ctxt.ptr;
            assign desc[g_ctxt].sof     = __req_ctxt.sof;
            assign desc[g_ctxt].eof     = __req_ctxt.eof;
            assign desc[g_ctxt].nxt_ptr = __req_ctxt_nxt.ptr;
            assign desc[g_ctxt].size    = __req_ctxt.size;
            assign desc[g_ctxt].meta    = __req_ctxt.meta;
            assign desc[g_ctxt].err     = __req_ctxt.err;

        end : g__ctxt
    endgenerate

    // -----------------------------
    // Store (scatter) FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        arb = 1'b0;
        mem_wr_req = 1'b0;
        done = 1'b0;
        error = 1'b0;
        case (state)
            RESET : begin
                if (desc_mem_init_done) begin
                    if (en) nxt_state = IDLE;
                    else    nxt_state = DISABLED;
                end
            end
            DISABLED : begin
                if (en) nxt_state = IDLE;
            end
            IDLE : begin
                arb = 1'b1;
                if (!en) nxt_state = DISABLED;
                else if (|desc_valid) nxt_state = WRITE;
            end
            WRITE : begin
                mem_wr_req = 1'b1;
                if (mem_wr_rdy) begin
                    if (_desc.eof) nxt_state = DONE;
                    else nxt_state = IDLE;
                end
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

    // Work-conserving round-robin arbiter
    arb_rr #(
        .MODE ( arb_pkg::WCRR ),
        .N    ( CONTEXTS )
    ) i_arb_rr__ctxt (
        .clk,
        .srst,
        .en    ( arb ),
        .req   ( desc_valid ),
        .grant ( ),
        .ack   ( '1 ),
        .sel   ( ctxt_sel )
    );

    // Latch descriptor context
    always_ff @(posedge clk) begin
        if (arb) begin
            _desc_ptr <= desc_ptr[ctxt_sel];
            _desc     <= desc[ctxt_sel];
        end
    end

    // Latch context selection
    always_ff @(posedge clk) if (arb) ctxt_sel_r <= ctxt_sel;

    always_comb begin
        for (int i = 0; i < CONTEXTS; i++) begin
            if (ctxt_sel_r == i) frame_valid[i] = done || error;
            else                 frame_valid[i] = 1'b0;
        end
    end
    assign frame_error = error || _frame_error[ctxt_sel_r];
    assign frame_ptr   = _frame_ptr  [ctxt_sel_r];
    assign frame_size  = _frame_size [ctxt_sel_r];

    // -----------------------------
    // Drive descriptor memory interface
    // -----------------------------
    assign desc_mem_wr_if.rst = srst;
    assign desc_mem_wr_if.en = 1'b1;
    assign desc_mem_wr_if.req = mem_wr_req;
    assign mem_wr_rdy = desc_mem_wr_if.rdy;
    assign desc_mem_wr_if.addr = _desc_ptr;
    assign desc_mem_wr_if.data = _desc;

endmodule : alloc_scatter_core
