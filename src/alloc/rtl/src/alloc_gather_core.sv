module alloc_gather_core #(
    parameter int  CONTEXTS = 1,
    parameter int  PTR_WID = 1,
    parameter int  BUFFER_SIZE = 1,
    parameter int  META_WID = 1,
    parameter int  Q_DEPTH = 8,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
) (
    // Clock/reset
    input logic            clk,
    input logic            srst = 1'b0,

    // Control
    input  logic           en,

    // Gather interface
    alloc_intf.load_rx     gather_if [CONTEXTS],

    // Descriptor read interface
    mem_rd_intf.controller desc_mem_rd_if,
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
    typedef enum logic [1:0] {
        RESET,
        DISABLED,
        IDLE,
        READ
    } state_t;

    typedef struct packed {
        logic               sof;
        logic [PTR_WID-1:0] ptr;
    } req_ctxt_t;

    typedef struct packed {
        req_ctxt_t req;
        CTXT_SEL_T ctxt_id;
    } rd_ctxt_t;

    typedef struct packed {
        logic [PTR_WID-1:0]  ptr;
        logic                eof;
        logic [SIZE_WID-1:0] size;
        logic [META_WID-1:0] meta;
        logic                err;
    } buffer_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic [CONTEXTS-1:0] req;
    req_ctxt_t req_ctxt  [CONTEXTS];

    CTXT_SEL_T           ctxt_sel;
    logic [CONTEXTS-1:0] ctxt_sel_vec;

    state_t state;
    state_t nxt_state;

    rd_ctxt_t rd_ctxt_in;
    rd_ctxt_t rd_ctxt_out;

    logic   arb;

    logic   mem_rd_req;
    logic   mem_rd_rdy;

    DESC_T  _desc;

    // Per-context logic
    generate
        for (genvar g_ctxt = 0; g_ctxt < CONTEXTS; g_ctxt++) begin : g__ctxt
            // (Local) signals
            logic         __load_in_progress;
            logic         __rd_done;
            logic         __buffer_valid;
            buffer_ctxt_t __buffer_ctxt_in;
            buffer_ctxt_t __buffer_ctxt_out;

            assign __rd_done = desc_mem_rd_if.ack && (rd_ctxt_out.ctxt_id == g_ctxt);

            // Manage descriptor chain state
            initial __load_in_progress = 1'b0;
            always @(posedge clk) begin
                if (srst)                                                __load_in_progress <= 1'b0;
                else if (gather_if[g_ctxt].req && gather_if[g_ctxt].rdy) __load_in_progress <= 1'b1;
                else if (__rd_done && _desc.eof)                         __load_in_progress <= 1'b0;
            end
            
            assign gather_if[g_ctxt].rdy = !__load_in_progress;

            // Manage current descriptor state
            initial req[g_ctxt] = 1'b0;
            always @(posedge clk) begin
                if (srst)                                                req[g_ctxt] <= 1'b0;
                else if (gather_if[g_ctxt].req && gather_if[g_ctxt].rdy) req[g_ctxt] <= 1'b1;
                else if (__rd_done && !_desc.eof)                        req[g_ctxt] <= 1'b1;
                else if (ctxt_sel_vec[g_ctxt])                           req[g_ctxt] <= 1'b0;
            end

            // Latch request context
            always_ff @(posedge clk) begin
                if (gather_if[g_ctxt].req && gather_if[g_ctxt].rdy) begin
                    req_ctxt[g_ctxt].sof <= 1'b1;
                    req_ctxt[g_ctxt].ptr <= gather_if[g_ctxt].ptr;
                end else if (__rd_done) begin
                    req_ctxt[g_ctxt].sof <= 1'b0;
                    req_ctxt[g_ctxt].ptr <= _desc.nxt_ptr;
                end
            end

            // Response FIFO
            assign __buffer_ctxt_in.ptr  = req_ctxt[g_ctxt].ptr;
            assign __buffer_ctxt_in.eof  = _desc.eof;
            assign __buffer_ctxt_in.size = _desc.size;
            assign __buffer_ctxt_in.meta = _desc.meta;
            assign __buffer_ctxt_in.err  = _desc.err;

            fifo_ctxt #(
                .DATA_WID ( $bits(buffer_ctxt_t) ),
                .DEPTH    ( Q_DEPTH )
            ) i_fifo_ctxt (
                .clk,
                .srst,
                .wr_rdy  ( ),
                .wr      ( __rd_done ),
                .wr_data ( __buffer_ctxt_in ),
                .rd      ( gather_if[g_ctxt].ack ),
                .rd_vld  ( __buffer_valid ),
                .rd_data ( __buffer_ctxt_out ),
                .oflow   ( ),
                .uflow   ( )
            );

            assign gather_if[g_ctxt].vld     = __buffer_valid;
            assign gather_if[g_ctxt].nxt_ptr = __buffer_ctxt_out.ptr;
            assign gather_if[g_ctxt].eof     = __buffer_ctxt_out.eof;
            assign gather_if[g_ctxt].size    = __buffer_ctxt_out.size;
            assign gather_if[g_ctxt].meta    = __buffer_ctxt_out.meta;
            assign gather_if[g_ctxt].err     = __buffer_ctxt_out.err;

        end : g__ctxt
    endgenerate

    // -----------------------------
    // Read FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        arb = 1'b0;
        mem_rd_req = 1'b0;
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
                else if (|req) nxt_state = READ;
            end
            READ : begin
                mem_rd_req = 1'b1;
                if (mem_rd_rdy) nxt_state = IDLE;
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
        .req   ( req ),
        .grant ( ctxt_sel_vec ),
        .ack   ( '1 ),
        .sel   ( ctxt_sel )
    );

    // Read context FIFO
    always_ff @(posedge clk) begin
        if (arb) begin
            rd_ctxt_in.ctxt_id <= ctxt_sel;
            rd_ctxt_in.req <= req_ctxt[ctxt_sel];
        end
    end

    fifo_small_ctxt #(
        .DATA_WID ( $bits(rd_ctxt_t) ),
        .DEPTH    ( CONTEXTS )
    ) i_fifo_small_ctxt__rd_ctxt (
        .clk,
        .srst,
        .wr_rdy   ( ),
        .wr       ( mem_rd_req && mem_rd_rdy ),
        .wr_data  ( rd_ctxt_in ),
        .rd       ( desc_mem_rd_if.ack ),
        .rd_vld   ( ),
        .rd_data  ( rd_ctxt_out ),
        .oflow    ( ),
        .uflow    ( )
    );

    // -----------------------------
    // Drive descriptor memory interface
    // -----------------------------
    assign desc_mem_rd_if.rst = srst;
    assign desc_mem_rd_if.req = mem_rd_req;
    assign mem_rd_rdy = desc_mem_rd_if.rdy;
    assign desc_mem_rd_if.addr = rd_ctxt_in.req.ptr;
    assign _desc = desc_mem_rd_if.data;

endmodule : alloc_gather_core
