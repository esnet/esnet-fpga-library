// Manages a bank of NUM_QS packet queues
//
// Enqueues new descriptors onto the specified packet queue,
// storing the descriptor in a circular buffer in memory.
// Supports multiple ingress contexts (i.e. physical ports) for
// descriptors, and merging into output queues.
//
// Dequeues packets from specified queues to a single
// egress context (physical port).
module packet_q_manager
#(
    parameter int  NUM_INPUT_IFS = 1,
    parameter int  NUM_QS = 2,
    parameter int  Q_DEPTH = 1024, // Maximum depth of all queues combined
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  NUM_TRANSACTIONS = 8,
    // Derived parameters (don't override)
    parameter int SEL_WID = NUM_INPUT_IFS > 1 ? $clog2(NUM_INPUT_IFS) : 1,
    parameter int  Q_SEL_WID = NUM_QS > 1 ? $clog2(NUM_QS) : 1,
    parameter int  SIZE_WID = $clog2(MAX_PKT_SIZE+1),
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1,
    parameter bit  SIM__RAM_MODEL = 1
 ) (
    input  logic                 clk,
    input  logic                 srst,

    output logic                 init_done,

    input  logic [Q_SEL_WID-1:0] desc_in_q  [NUM_INPUT_IFS],
    packet_descriptor_intf.rx    desc_in_if [NUM_INPUT_IFS],

    output logic                 enq_ack,
    output logic                 enq_nack,
    output logic [SEL_WID-1:0]   enq_src,
    output logic [Q_SEL_WID-1:0] enq_q,
    output logic [SIZE_WID-1:0]  enq_size,

    input  logic                 deq_req,
    output logic                 deq_rdy,
    input  logic [Q_SEL_WID-1:0] deq_q,
    output logic                 deq_ack,
    output logic                 deq_nack,
    output logic [SEL_WID-1:0]   deq_src,
    output logic [SIZE_WID-1:0]  deq_size,

    output logic [Q_SEL_WID-1:0] desc_out_q,
    packet_descriptor_intf.tx    desc_out_if,

    input  logic                 mem_init_done,
    mem_wr_intf.controller       q_mem_wr_if,
    mem_rd_intf.controller       q_mem_rd_if,
    
    // AXI-L control/monitoring
    axi4l_intf.peripheral        axil_if
 );
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PKT_PTR_WID = desc_in_if[0].ADDR_WID;
    localparam int META_WID = desc_in_if[0].META_WID;

    localparam int PTR_WID = $clog2(Q_DEPTH);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    generate
        for (genvar i = 0; i < NUM_INPUT_IFS; i++) begin
            initial std_pkg::param_check(desc_in_if[i].ADDR_WID, PKT_PTR_WID, $sformatf("desc_in_if[%0d].ADDR_WID", i));
            initial std_pkg::param_check(desc_in_if[i].META_WID, META_WID, $sformatf("desc_in_if[%0d].META_WID", i));
            initial std_pkg::param_check(desc_in_if[i].MAX_PKT_SIZE, MAX_PKT_SIZE, $sformatf("desc_in_if[%0d].MAX_PKT_SIZE", i));
        end
    endgenerate

    // Typedefs
    typedef struct packed {
        logic [PKT_PTR_WID-1:0] addr;
        logic [SIZE_WID-1:0]    size;
        logic [META_WID-1:0]    meta;
        logic                   err;
        logic [SEL_WID-1:0]     src;
    } desc_t;
    localparam int DESC_WID = $bits(desc_t);

    typedef struct packed {
        desc_t                desc;
        logic [Q_SEL_WID-1:0] q;
    } desc_plus_q_t;

    typedef struct packed {
        logic [SEL_WID-1:0]   src;
        logic [Q_SEL_WID-1:0] q;
        logic [SIZE_WID-1:0]  size;
    } enq_ctxt_t;
    localparam int ENQ_CTXT_WID = $bits(enq_ctxt_t);

    // (Local) typedefs
    typedef enum logic[1:0] {
    DEQ_RESET,
        DEQ_IDLE,
        DEQ_REQ,
        DEQ_LOAD_REQ
    } deq_state_t;

    // Signals
    logic                     alloc_ll_init_done;
    logic [SEL_WID-1:0]       sel;

    logic [NUM_INPUT_IFS-1:0] enq_req;
    logic [NUM_INPUT_IFS-1:0] enq_grant;
    logic [Q_SEL_WID-1:0]     enq_q_in [NUM_INPUT_IFS];
    desc_t                    enq_desc [NUM_INPUT_IFS];

    logic                     fifo_ctxt_enq_wr_rdy;
    enq_ctxt_t                fifo_ctxt_enq_wr_data;
    enq_ctxt_t                fifo_ctxt_enq_rd_data;

    logic                     store_req;
    logic                     store_rdy;
    logic [Q_SEL_WID-1:0]     store_list_sel;
    logic [DESC_WID-1:0]      store_meta;
    logic                     store_ack;
    logic                     store_nack;

    logic                     load_req;
    logic                     load_rdy;
    logic [Q_SEL_WID-1:0]     load_list_sel;
    desc_t                    load_meta;
    logic                     load_ack;
    logic                     load_nack;

    deq_state_t deq_state;
    deq_state_t nxt_deq_state;

    logic                     desc_fifo_wr_rdy;
    desc_plus_q_t             desc_fifo_wr_data;
    desc_plus_q_t             desc_fifo_rd_data;

    // Init done
    assign init_done = alloc_init_done;

    // Per-port queues/FSMs
    generate
        for (genvar g_if_in = 0; g_if_in < NUM_INPUT_IFS; g_if_in++) begin : g__if_in
            // (Local) signals
            desc_plus_q_t  enq_fifo_wr_data;
            desc_plus_q_t  enq_fifo_rd_data;
            logic          enq_rdy;

            // Enqueue FIFO
            assign enq_fifo_wr_data.desc.err  = desc_in_if[g_if_in].err;
            assign enq_fifo_wr_data.desc.addr = desc_in_if[g_if_in].addr;
            assign enq_fifo_wr_data.desc.meta = desc_in_if[g_if_in].meta;
            assign enq_fifo_wr_data.desc.size = desc_in_if[g_if_in].size;
            assign enq_fifo_wr_data.desc.src  = g_if_in;
            assign enq_fifo_wr_data.q = desc_in_q[g_if_in];

            fifo_sync    #(
                .DATA_WID ( $bits(desc_plus_q_t) ),
                .DEPTH    ( 32 )
            ) i_fifo_sync (
                .clk,
                .srst,
                .wr_rdy   ( desc_in_if[g_if_in].rdy ),
                .wr       ( desc_in_if[g_if_in].vld ),
                .wr_data  ( enq_fifo_wr_data ),
                .wr_count ( ),
                .full     ( ),
                .oflow    ( ),
                .rd       ( enq_rdy ),
                .rd_ack   ( enq_req[g_if_in]  ),
                .rd_data  ( enq_fifo_rd_data ),
                .rd_count ( ),
                .empty    ( ),
                .uflow    ( )
            );

            assign enq_desc [g_if_in] = enq_fifo_rd_data.desc;
            assign enq_q_in [g_if_in] = enq_fifo_rd_data.q;
            assign enq_rdy = (g_if_in == sel) && store_rdy;
        end : g__if_in
    endgenerate

    // Arbitrate between input contexts
    arb_rr #(
        .N  ( NUM_INPUT_IFS ),
        .MODE (arb_pkg::WCRR)
    ) i_arb_rr__enq (
        .clk,
        .srst,
        .en    ( 1'b1 ),
        .req   ( enq_req ),
        .grant ( enq_grant ),
        .ack   ( '1 ),
        .sel   ( sel )
    );

    assign store_req      = enq_req [sel] && fifo_ctxt_enq_wr_rdy;
    assign store_list_sel = enq_q_in[sel];
    assign store_meta     = enq_desc[sel];

    // Maintain context during store operation
    assign fifo_ctxt_enq_wr_data.src  = sel;
    assign fifo_ctxt_enq_wr_data.q    = enq_q_in[sel];
    assign fifo_ctxt_enq_wr_data.size = enq_desc[sel].size;

    fifo_ctxt #(
        .DATA_WID (ENQ_CTXT_WID),
        .DEPTH    (NUM_TRANSACTIONS),
        .REPORT_UFLOW ( 1 )
    ) i_fifo_ctxt__enq (
        .clk,
        .srst,
        .wr      ( store_req && store_rdy ),
        .wr_data ( fifo_ctxt_enq_wr_data ),
        .wr_rdy  ( fifo_ctxt_enq_wr_rdy ),
        .rd      ( store_ack || store_nack ),
        .rd_vld  ( ),
        .rd_data ( fifo_ctxt_enq_rd_data ),
        .oflow   ( ),
        .uflow   ( )
    );

    // Report enqueue status after store operation completes
    assign enq_ack  = store_ack;
    assign enq_nack = store_nack;
    assign enq_src  = fifo_ctxt_enq_rd_data.src;
    assign enq_q    = fifo_ctxt_enq_rd_data.q;
    assign enq_size = fifo_ctxt_enq_rd_data.size;

    // Dequeue FSM
    initial deq_state = DEQ_RESET;
    always @(posedge clk) begin
        if (srst) deq_state <= DEQ_RESET;
        else      deq_state <= nxt_deq_state;
    end

    always_comb begin
        nxt_deq_state = deq_state;
        deq_rdy = 1'b0;
        load_req = 1'b0;
        case (deq_state)
            DEQ_RESET : begin
                if (alloc_init_done) nxt_deq_state = DEQ_IDLE;
            end
            DEQ_IDLE : begin
                deq_rdy = 1'b1;
                if (deq_req) nxt_deq_state = DEQ_LOAD_REQ;
            end
            DEQ_LOAD_REQ : begin
                load_req = 1'b1;
                if (load_rdy) nxt_deq_state = DEQ_IDLE;
            end
            default : begin
                nxt_deq_state = DEQ_RESET;
            end
        endcase
    end

    assign load_list_sel = deq_q;

    assign desc_fifo_wr_data.desc = load_meta;
    assign desc_fifo_wr_data.q    = load_list_sel;

    fifo_queue   #(
        .DATA_WID ( $bits(desc_plus_q_t) ),
        .DEPTH    ( 16 ),
        .REPORT_OFLOW ( 1 ),
        .REPORT_UFLOW ( 0 )
    ) i_fifo_queue__deq (
        .clk,
        .srst,
        .wr      ( load_ack ),
        .wr_rdy  ( desc_fifo_wr_rdy ),
        .wr_data ( desc_fifo_wr_data ),
        .rd      ( desc_out_if.rdy ),
        .rd_vld  ( desc_out_if.vld ),
        .rd_data ( desc_fifo_rd_data ),
        .oflow   ( ),
        .uflow   ( )
    );

    assign desc_out_if.addr = desc_fifo_rd_data.desc.addr;
    assign desc_out_if.size = desc_fifo_rd_data.desc.size;
    assign desc_out_if.meta = desc_fifo_rd_data.desc.meta;
    assign desc_out_if.err  = desc_fifo_rd_data.desc.err;
    assign desc_out_q = desc_fifo_rd_data.q;

    assign deq_ack  = load_ack && desc_fifo_wr_rdy;
    assign deq_nack = load_nack || (load_ack && !desc_fifo_wr_rdy);
    assign deq_size = load_meta.size;
    assign deq_src  = load_meta.src;

    alloc_axil_ll_core #(
        .LIST_CONTEXTS  ( NUM_QS ),
        .PTR_WID        ( PTR_WID ),
        .META_WID       ( DESC_WID ),
        .N_ALLOC        ( 2 ),      // (powers of 2 only) Controls parallelism of allocator logic; can be
                                    // used to increase allocation throughput. See alloc_bv for details.
        .NUM_RD_TRANSACTIONS ( NUM_TRANSACTIONS )
    ) i_alloc_axil_ll_core (
        .clk,
        .srst,
        .en ( 1'b1 ),
        .init_done (alloc_init_done),
        .store_req,
        .store_rdy,
        .store_list_sel,
        .store_meta,
        .store_ack,
        .store_nack,
        .load_req,
        .load_rdy,
        .load_list_sel,
        .load_meta,
        .load_ack,
        .load_nack,
        .mem_wr_if ( q_mem_wr_if ),
        .mem_rd_if ( q_mem_rd_if ),
        .mem_init_done,
        .axil_if
    );

endmodule : packet_q_manager
