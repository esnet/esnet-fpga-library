// Module: packet_scatter
//
// Description: 'Scatters' a packet to memory by interfacing with
//              a scatter controller that provides a series of available
//              buffers into which the packet segments can be written.
//              The memory interface (for both data and descriptors)
//              is generic, allowing connection to arbitrary memory
//              types (i.e. on-chip SRAM, HBM, etc.)
//
module packet_scatter #(
    parameter int  IGNORE_RDY = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  BUFFER_SIZE  = 1,
    parameter type PTR_T = logic,
    parameter type META_T = logic,
    // Derived parameters (don't override)
    parameter int  SIZE_WID = BUFFER_SIZE > 1 ? $clog2(BUFFER_SIZE) : 1,
    parameter type SIZE_T = logic[SIZE_WID-1:0]
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.rx              packet_if,

    // Scatter controller interface (provides buffers for packet data)
    alloc_intf.store_tx         scatter_if,

    // Packet completion interface
    packet_descriptor_intf.tx   descriptor_if,

    // Descriptor 'recycle' interface
    // output logic                recycle_req,
    // output PTR_T                recycle_ptr,

    // Packet reporting interface
    packet_event_intf.publisher event_if,

    // Memory write interface
    mem_wr_intf.controller      mem_wr_if,
    input logic                 mem_init_done
);
    // -----------------------------
    // Imports
    // -----------------------------
    import packet_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam int  MTY_WID = $clog2(DATA_BYTE_WID);
    localparam type MTY_T = logic[MTY_WID-1:0];

    localparam int  MIN_PKT_WORDS = MIN_PKT_SIZE % DATA_BYTE_WID == 0 ? MIN_PKT_SIZE / DATA_BYTE_WID : MIN_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int  MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int  PKT_WORD_CNT_WID = $clog2(MAX_PKT_WORDS+1);

    localparam int  BUFFER_WORDS = BUFFER_SIZE / DATA_BYTE_WID;
    localparam int  BUFFER_WORD_CNT_WID = $clog2(BUFFER_WORDS);

    localparam int  PTR_WID = $bits(PTR_T);
    localparam int  NUM_PTRS = 2**PTR_WID;
    localparam int  MEM_DEPTH = NUM_PTRS * BUFFER_WORDS;
    localparam int  ADDR_WID = $clog2(MEM_DEPTH);

    localparam int  META_WID = $bits(META_T);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_WID, "mem_wr_if.DATA_WID");
        std_pkg::param_check_gt(mem_wr_if.ADDR_WID, ADDR_WID,"mem_wr_if.ADDR_WID");
        std_pkg::param_check($bits(packet_if.META_T), META_WID, "packet_if.META_T");
        std_pkg::param_check(scatter_if.BUFFER_SIZE, BUFFER_SIZE, "scatter_if.BUFFER_SIZE");
        std_pkg::param_check($bits(scatter_if.PTR_T), PTR_WID, "scatter_if.PTR_T");
        std_pkg::param_check($bits(scatter_if.META_T), META_WID, "scatter_if.META_T");
        std_pkg::param_check($bits(descriptor_if.ADDR_T), PTR_WID, "descriptor_if.ADDR_WID");
        std_pkg::param_check($bits(descriptor_if.META_T), META_WID, "descriptor_if.META_T");
        std_pkg::param_check_gt($bits(descriptor_if.SIZE_T), $clog2(MAX_PKT_SIZE+1), "descriptor_if.SIZE_T");
        std_pkg::param_check(BUFFER_SIZE % DATA_BYTE_WID, 0, "BUFFER_SIZE");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic[BUFFER_WORD_CNT_WID-1:0] word_cnt_t;
    typedef logic[PKT_WORD_CNT_WID-1:0]    pkt_word_cnt_t;

    typedef enum logic [2:0] {
        RESET = 0,
        SOP = 1,
        MOP = 2,
        MOP_NXT = 3,
        FLUSH = 4
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic        rdy;

    state_t      state;
    state_t      nxt_state;

    logic        pkt_eop;
    logic        pkt_oflow;

    PTR_T        buffer_ptr;
    PTR_T        buffer_ptr_r;
    logic        buffer_req;
    logic        buffer_rdy;
    logic        buffer_wr;
    logic        buffer_done;

    word_cnt_t     words;
    pkt_word_cnt_t pkt_words;

    PTR_T        pkt_ptr;

    logic        oflow;

    META_T       meta;
    MTY_T        mty;
    logic        err;
    logic[31:0]  pkt_size;

    logic        pkt_done;
    status_t     pkt_status;
    logic        pkt_good;

    logic        packet_event;
    logic[31:0]  packet_event_size;
    status_t     packet_event_status;

    logic        recycle_req;
    PTR_T        recycle_ptr;

    // -----------------------------
    // Packet write FSM
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        rdy = 1'b0;
        buffer_req = 1'b0;
        buffer_rdy = 1'b0;
        buffer_done = 1'b0;
        buffer_wr = 1'b0;
        pkt_oflow = 1'b0;
        pkt_eop = 1'b0;
        case (state)
            RESET: begin
                if (mem_init_done) nxt_state = SOP;
            end
            SOP: begin
                buffer_rdy = scatter_if.rdy;
                rdy = mem_wr_if.rdy && buffer_rdy;
                if (packet_if.valid && packet_if.rdy) begin
                    if (IGNORE_RDY && !rdy) begin
                        pkt_oflow = 1'b1;
                        if (packet_if.eop) pkt_eop = 1'b1;
                        else nxt_state = FLUSH;
                    end else begin
                        buffer_req = 1'b1;
                        buffer_wr = 1'b1;
                        if (packet_if.eop) begin
                            pkt_eop = 1'b1;
                            buffer_done = 1'b1;
                        end else if (BUFFER_WORDS == 1) nxt_state = MOP_NXT;
                        else nxt_state = MOP;
                    end
                end
            end
            MOP: begin
                buffer_rdy = words < BUFFER_WORDS;
                rdy = mem_wr_if.rdy && buffer_rdy;
                if (packet_if.valid && packet_if.rdy) begin
                    if (IGNORE_RDY && !rdy) begin
                        pkt_oflow = 1'b1;
                        if (packet_if.eop) begin
                            pkt_eop = 1'b1;
                            buffer_done = 1'b1;
                            nxt_state = SOP;
                        end else nxt_state = FLUSH;
                    end else begin
                        buffer_wr = 1'b1;
                        if (packet_if.eop) begin
                            pkt_eop = 1'b1;
                            buffer_done = 1'b1;
                            nxt_state = SOP;
                        end else if (pkt_words == MAX_PKT_WORDS-1) nxt_state = FLUSH;
                        else if (words == BUFFER_WORDS-1) nxt_state = MOP_NXT;
                        else nxt_state = MOP;
                    end
                end
            end
            MOP_NXT: begin
                buffer_rdy = scatter_if.rdy;
                rdy = mem_wr_if.rdy && buffer_rdy;
                if (packet_if.valid && packet_if.rdy) begin
                    buffer_req = 1'b1;
                    if (IGNORE_RDY && !rdy) begin
                        pkt_oflow = 1'b1;
                        if (packet_if.eop) begin
                            pkt_eop = 1'b1;
                            buffer_done = 1'b1;
                            nxt_state = SOP;
                        end else nxt_state = FLUSH;
                    end else begin
                        buffer_wr = 1'b1;
                        if (packet_if.eop) begin
                            pkt_eop = 1'b1;
                            buffer_done = 1'b1;
                            nxt_state = SOP;
                        end else if (pkt_words == MAX_PKT_WORDS-1) nxt_state = FLUSH;
                        else if (BUFFER_WORDS == 1) begin
                            buffer_done = 1'b1;
                            nxt_state = MOP_NXT;
                        end else nxt_state = MOP;
                    end
                end
            end
            FLUSH: begin
                rdy = 1'b1;
                if (packet_if.valid && packet_if.eop) begin
                    pkt_eop = 1'b1;
                    buffer_done = 1'b1;
                    nxt_state = SOP;
                end
            end
            default: begin
                nxt_state = RESET;
            end
        endcase
    end

    assign packet_if.rdy = IGNORE_RDY ? 1'b1 : rdy;

    assign scatter_if.req = buffer_req; 

    // Count buffer words used
    initial words = 0;
    always @(posedge clk) begin
        if (srst) words <= 0;
        else begin
            if (buffer_done)    words <= 0;
            else if (buffer_wr) words <= words + 1;
        end
    end

    // Count packet words
    initial pkt_words = 0;
    always @(posedge clk) begin
        if (packet_if.valid && packet_if.rdy) begin
            if (packet_if.sop) pkt_words <= 1;
            else if (pkt_words <= MAX_PKT_WORDS) pkt_words <= pkt_words + 1;
        end
    end

    // Latch buffer pointer
    always_ff @(posedge clk) buffer_ptr_r <= buffer_ptr;

    always_comb begin
        buffer_ptr = buffer_ptr_r;
        if (scatter_if.req && scatter_if.rdy) buffer_ptr = scatter_if.ptr;
    end

    assign scatter_if.valid   = buffer_done;
    assign scatter_if.nxt_ptr = buffer_ptr;
    assign scatter_if.meta    = packet_if.meta;
    assign scatter_if.eof     = packet_if.eop;
    assign scatter_if.size    = packet_if.eop ? (words * DATA_BYTE_WID) + (DATA_BYTE_WID - packet_if.mty) : 0;
    assign scatter_if.err     = packet_if.err;

    // Latch pointer for SOP
    always_ff @(posedge clk) begin
        if (state == SOP) pkt_ptr <= scatter_if.ptr;
    end

    // Latch overflow indicator
    always_ff @(posedge clk) begin
        if (state == SOP) oflow <= pkt_oflow;
        else              oflow <= oflow | pkt_oflow;
    end

    // Latch EOP context
    always_ff @(posedge clk) begin
        pkt_done <= pkt_eop;
        if (pkt_eop) begin
            meta <= packet_if.meta;
            mty  <= packet_if.mty;
            err  <= packet_if.err;
        end
    end
    assign pkt_size = (pkt_words * DATA_BYTE_WID) - mty;

    // Determine packet write status
    always_comb begin
        pkt_status = STATUS_UNDEFINED;
        if (DROP_ERRORED && err)          pkt_status = STATUS_ERR;
        else if (pkt_size > MAX_PKT_SIZE) pkt_status = STATUS_LONG;
        else if (oflow)                   pkt_status = STATUS_OFLOW;
        else if (pkt_size < MIN_PKT_SIZE) pkt_status = STATUS_SHORT;
        else if (err)                     pkt_status = STATUS_ERR;
        else                              pkt_status = STATUS_OK;
    end
    assign pkt_good = pkt_done && ((pkt_status == STATUS_OK) || (!DROP_ERRORED && (pkt_status == STATUS_ERR)));

    // Drive memory write interface
    assign mem_wr_if.rst = 1'b0;
    assign mem_wr_if.en = rdy;
    assign mem_wr_if.req = packet_if.valid && buffer_rdy;
    assign mem_wr_if.addr = (buffer_ptr * BUFFER_WORDS) + words;
    assign mem_wr_if.data = packet_if.data;

    // Drive descriptor
    assign descriptor_if.valid  = pkt_good;
    assign descriptor_if.addr   = pkt_ptr;
    assign descriptor_if.size   = pkt_size;
    assign descriptor_if.meta   = meta;
    assign descriptor_if.err    = err;

    // Recycle descriptors for 'bad' packets
    assign recycle_req = pkt_done && !pkt_good;
    assign recycle_ptr = pkt_ptr;

    // Report packet event
    assign event_if.evt = pkt_done;
    assign event_if.size = pkt_size;
    assign event_if.status = pkt_status;

endmodule : packet_scatter
