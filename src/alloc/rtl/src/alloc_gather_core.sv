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
    input logic                clk,
    input logic                srst,

    // Control
    input  logic               en,

    // Gather interface
    alloc_intf.load_rx         gather_if [CONTEXTS],

    // Pointer deallocation interface
    output logic               dealloc_req,
    input  logic               dealloc_rdy,
    output logic [PTR_WID-1:0] dealloc_ptr,

    // Descriptor read interface
    mem_rd_intf.controller     desc_mem_rd_if,
    input  logic               desc_mem_init_done
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  SIZE_WID = $clog2(BUFFER_SIZE);
    localparam int  CTXT_SEL_WID = CONTEXTS > 1 ? $clog2(CONTEXTS) : 1;
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
        req_ctxt_t               req;
        logic [CTXT_SEL_WID-1:0] ctxt_id;
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

    logic [CTXT_SEL_WID-1:0] ctxt_sel;

    state_t state;
    state_t nxt_state;

    rd_ctxt_t rd_ctxt_in;
    rd_ctxt_t rd_ctxt_out;

    logic   arb;

    logic   mem_rd_req;
    logic   mem_rd_rdy;

    logic   rd_ack;

    logic   rd_ctxt_fifo_rdy;
    logic   dealloc_fifo_rdy;

    DESC_T  _desc;

    initial req = '0;

    // Per-context logic
    generate
        for (genvar g_ctxt = 0; g_ctxt < CONTEXTS; g_ctxt++) begin : g__ctxt
            // (Local) signals
            logic         __load_in_progress;
            logic         __rd_done;
            logic         __buffer_valid;
            buffer_ctxt_t __buffer_ctxt_in;
            buffer_ctxt_t __buffer_ctxt_out;

            assign __rd_done = rd_ack && (rd_ctxt_out.ctxt_id == g_ctxt);

            // Manage descriptor chain state
            initial __load_in_progress = 1'b0;
            always @(posedge clk) begin
                if (srst)                                                __load_in_progress <= 1'b0;
                else if (gather_if[g_ctxt].req && gather_if[g_ctxt].rdy) __load_in_progress <= 1'b1;
                else if (__rd_done && _desc.eof)                         __load_in_progress <= 1'b0;
            end

            assign gather_if[g_ctxt].rdy = !__load_in_progress;

            // Manage current descriptor state
            always @(posedge clk) begin
                if (srst)                                                req[g_ctxt] <= 1'b0;
                else if (gather_if[g_ctxt].req && gather_if[g_ctxt].rdy) req[g_ctxt] <= 1'b1;
                else if (__rd_done && !_desc.eof)                        req[g_ctxt] <= 1'b1;
                else if (mem_rd_req && mem_rd_rdy && ctxt_sel == g_ctxt) req[g_ctxt] <= 1'b0;
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
                .DEPTH    ( Q_DEPTH ),
                .REPORT_OFLOW ( 1 )
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

    // Round-robin arbitration of the read interface
    initial ctxt_sel = 0;
    always @(posedge clk) ctxt_sel <= ctxt_sel < CONTEXTS-1 ? ctxt_sel + 1 : 0;

    assign mem_rd_rdy = desc_mem_rd_if.rdy && rd_ctxt_fifo_rdy && dealloc_fifo_rdy;
    assign mem_rd_req = en && req[ctxt_sel];

    // Read context FIFO
    assign rd_ctxt_in.ctxt_id = ctxt_sel;
    assign rd_ctxt_in.req = req_ctxt[ctxt_sel];

    fifo_ctxt        #(
        .DATA_WID     ( $bits(rd_ctxt_t) ),
        .DEPTH        ( CONTEXTS ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__rd_ctxt (
        .clk,
        .srst,
        .wr_rdy   ( rd_ctxt_fifo_rdy ),
        .wr       ( mem_rd_req && mem_rd_rdy ),
        .wr_data  ( rd_ctxt_in ),
        .rd       ( rd_ack ),
        .rd_vld   ( ),
        .rd_data  ( rd_ctxt_out ),
        .oflow    ( ),
        .uflow    ( )
    );

    // -----------------------------
    // Drive descriptor memory interface
    // -----------------------------
    assign desc_mem_rd_if.rst = 1'b0;
    assign desc_mem_rd_if.req = mem_rd_req;
    assign desc_mem_rd_if.addr = rd_ctxt_in.req.ptr;

    always_ff @(posedge clk) _desc <= desc_mem_rd_if.data;

    always_ff @(posedge clk) begin
        if (desc_mem_rd_if.ack) rd_ack <= 1'b1;
        else                    rd_ack <= 1'b0;
    end

    // -----------------------------
    // Deallocate pointers after use
    // -----------------------------
    fifo_ctxt #(
        .DATA_WID ( PTR_WID ),
        .DEPTH    ( CONTEXTS ),
        .REPORT_OFLOW ( 1 )
    ) i_fifo_ctxt__dealloc (
        .clk,
        .srst,
        .wr_rdy  ( dealloc_fifo_rdy ),
        .wr      ( rd_ack ),
        .wr_data ( rd_ctxt_out.req.ptr ),
        .rd      ( dealloc_rdy ),
        .rd_vld  ( dealloc_req ),
        .rd_data ( dealloc_ptr ),
        .oflow   ( ),
        .uflow   ( )
    );

endmodule : alloc_gather_core
