// Module: packet_write
//
// Description: Writes a packet to memory, starting at a given address,
//              and generates a descriptor. The memory interface
//              is generic, allowing connection to arbitrary memory
//              types (i.e. on-chip SRAM, HBM, etc.)
//
module packet_write
#(
    parameter int  IGNORE_RDY = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.rx              packet_if,

    // Next descriptor interface (allocator)
    packet_descriptor_intf.rx   nxt_descriptor_if,

    // Packet completion interface
    packet_descriptor_intf.tx   descriptor_if,

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
    localparam int DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;

    localparam int MIN_PKT_WORDS = MIN_PKT_SIZE % DATA_BYTE_WID == 0 ? MIN_PKT_SIZE / DATA_BYTE_WID : MIN_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int WORD_CNT_WID = $clog2(MAX_PKT_WORDS+1);

    localparam type ADDR_T = descriptor_if.ADDR_T;
    localparam int  ADDR_WID = $bits(ADDR_T);
    localparam int  MEM_DEPTH = 2**ADDR_WID;

    localparam type META_T = packet_if.META_T;
    localparam int  META_WID = $bits(META_T);

    localparam type SIZE_T = descriptor_if.SIZE_T;
    localparam int  SIZE_WID = $bits(SIZE_T);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_WID, "mem_wr_if.DATA_WID");
        std_pkg::param_check(mem_wr_if.ADDR_WID, ADDR_WID,"descriptor_if.ADDR_WID");
        std_pkg::param_check($bits(nxt_descriptor_if.ADDR_T), ADDR_WID,"nxt_descriptor_if.ADDR_WID");
        std_pkg::param_check_gt(SIZE_WID, $clog2(MAX_PKT_SIZE), "SIZE_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic[WORD_CNT_WID-1:0] word_cnt_t;

    typedef enum logic [1:0] {
        RESET = 0,
        SOP = 1,
        MOP = 2,
        FLUSH = 3
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic        rdy;

    ADDR_T       addr;
    ADDR_T       addr_reg;

    word_cnt_t   words;
    word_cnt_t   desc_words;

    logic        pkt_done;
    status_t     pkt_status;
    logic[31:0]  pkt_size;

    state_t      state;
    state_t      nxt_state;

    logic        desc_valid;

    logic        packet_event;
    logic[31:0]  packet_event_size;
    status_t     packet_event_status;

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
        desc_valid = 1'b0;
        pkt_done = 1'b0;
        pkt_status = STATUS_UNDEFINED;
        case (state)
            RESET: begin
                if (mem_init_done) nxt_state = SOP;
            end
            SOP: begin
                rdy = mem_wr_if.rdy && nxt_descriptor_if.valid && (nxt_descriptor_if.size >= DATA_BYTE_WID);
                if (packet_if.valid && packet_if.rdy) begin
                    if (packet_if.eop) begin
                        pkt_done = 1'b1;
                        if (DROP_ERRORED && packet_if.err) pkt_status = STATUS_ERR;
                        else if ((MIN_PKT_SIZE < DATA_BYTE_WID) && (packet_if.mty > (DATA_BYTE_WID - MIN_PKT_SIZE))) pkt_status = STATUS_SHORT;
                        else if ((MAX_PKT_SIZE < DATA_BYTE_WID) && (packet_if.mty < (DATA_BYTE_WID - MAX_PKT_SIZE))) pkt_status = STATUS_LONG;
                        else if (!rdy) pkt_status = STATUS_OFLOW;
                        else begin
                            desc_valid = 1'b1;
                            pkt_status = packet_if.err ? STATUS_ERR : STATUS_OK;
                        end
                    end else if (IGNORE_RDY && !rdy) nxt_state = FLUSH;
                    else nxt_state = MOP;
                end
            end
            MOP: begin
                rdy = mem_wr_if.rdy && (words <= desc_words);
                if (packet_if.valid && packet_if.rdy) begin
                    if (packet_if.eop) begin
                        pkt_done = 1'b1;
                        if (DROP_ERRORED && packet_if.err) pkt_status = STATUS_ERR;
                        else if (pkt_size < MIN_PKT_SIZE) pkt_status = STATUS_SHORT;
                        else if (pkt_size > MAX_PKT_SIZE) pkt_status = STATUS_LONG;
                        else if (!rdy) pkt_status = STATUS_OFLOW;
                        else begin
                            desc_valid = 1'b1;
                            pkt_status = packet_if.err ? STATUS_ERR : STATUS_OK;
                        end
                        nxt_state = SOP;
                    end else if (words == MAX_PKT_WORDS) nxt_state = FLUSH;
                    else if (IGNORE_RDY && !rdy) nxt_state = FLUSH;
                end
            end
            FLUSH: begin
                rdy = 1'b1;
                if (packet_if.valid) begin
                    if (packet_if.eop) begin
                        pkt_done = 1'b1;
                        if (packet_if.err)                pkt_status = STATUS_ERR;
                        else if (pkt_size > MAX_PKT_SIZE) pkt_status = STATUS_LONG;
                        else                              pkt_status = STATUS_OFLOW;
                        nxt_state = SOP;
                    end
                end
            end
            default: begin
                nxt_state = RESET;
            end
        endcase
    end

    assign packet_if.rdy = IGNORE_RDY ? 1'b1 : rdy;

    // Acknowledge next descriptor allocation
    assign nxt_descriptor_if.rdy = desc_valid;

    // Write address
    always_ff @(posedge clk) addr_reg <= addr;

    always_comb begin
        addr = addr_reg;
        if (state == SOP) addr = nxt_descriptor_if.addr;
        else if (state == MOP && packet_if.valid && rdy) addr = addr + 1;
    end

    // Descriptor word count
    always_ff @(posedge clk) begin
        if (nxt_descriptor_if.size / DATA_BYTE_WID > MAX_PKT_WORDS) desc_words <= MAX_PKT_WORDS;
        else                                                        desc_words <= nxt_descriptor_if.size / DATA_BYTE_WID;
    end

    // Write word count
    initial words = 1;
    always @(posedge clk) begin
        if (srst) words <= 1;
        else begin
            if (pkt_done) words <= 1;
            else if (packet_if.valid && rdy) begin
                if (words < MAX_PKT_WORDS) words <= words + 1;
            end
        end
    end
    assign pkt_size = (words * DATA_BYTE_WID) - packet_if.mty;

    // Drive memory write interface
    assign mem_wr_if.rst = 1'b0;
    assign mem_wr_if.en = rdy;
    assign mem_wr_if.req = packet_if.valid;
    assign mem_wr_if.addr = addr;
    assign mem_wr_if.data = packet_if.data;
     
    // Drive descriptor
    assign descriptor_if.valid  = desc_valid;
    assign descriptor_if.addr   = nxt_descriptor_if.addr;
    assign descriptor_if.size   = pkt_size;
    assign descriptor_if.meta   = packet_if.meta;
    assign descriptor_if.err    = packet_if.err;

    // Report packet event
    always_ff @(posedge clk) begin
        packet_event <= pkt_done;
        packet_event_size <= pkt_size;
        packet_event_status <= pkt_status;
    end

    assign event_if.evt = packet_event;
    assign event_if.size = packet_event_size;
    assign event_if.status = packet_event_status;

endmodule : packet_write
