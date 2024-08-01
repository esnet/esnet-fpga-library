module packet_enqueue
#(
    parameter int  DATA_BYTE_WID = 1,
    parameter int  BUFFER_WORDS = 1, // Buffer size (in words of DATA_BYTE_WID)
    parameter type META_T = logic,
    parameter int  IGNORE_RDY = 0,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    // Derived parameters (don't override)
    parameter int  ADDR_WID = $clog2(BUFFER_WORDS),
    parameter int  PTR_WID = ADDR_WID + 1,
    parameter type ADDR_T = logic[ADDR_WID-1:0],
    parameter type PTR_T = logic[PTR_WID-1:0]
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Packet data interface
    packet_intf.rx              packet_if,

    // Circular buffer interface
    output PTR_T                head_ptr,
    input  PTR_T                tail_ptr,

    // Packet completion interface
    packet_descriptor_intf.tx   descriptor_if,

    // Packet reporting interface
    packet_event_intf.publisher event_if,

    // Memory write interface
    mem_wr_intf.controller      mem_wr_if
);
    // -----------------------------
    // Imports
    // -----------------------------
    import packet_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int MIN_PKT_WORDS = MIN_PKT_SIZE % DATA_BYTE_WID == 0 ? MIN_PKT_SIZE / DATA_BYTE_WID : MIN_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int WORD_CNT_WID = $clog2(MAX_PKT_WORDS+1);

    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE + 1);
    localparam type SIZE_T = logic[SIZE_WID-1:0];

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_WID, "mem_wr_if.DATA_WID");
        std_pkg::param_check($bits(descriptor_if.ADDR_T),ADDR_WID,"descriptor_if.ADDR_WID");
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
    PTR_T        __wr_ptr;
    PTR_T        __head_ptr;
    PTR_T        __count;
    logic        __full;
    logic        rdy;

    word_cnt_t   __words;

    logic        reset_wr_ptr;
    logic        rewind_wr_ptr;
    logic        inc_wr_ptr;

    logic        __pkt_done;
    status_t     __pkt_status;
    logic[31:0]  __pkt_size;

    state_t      state;
    state_t      nxt_state;

    logic        desc_valid;
    status_t     desc_status;
    ADDR_T       desc_addr;
    SIZE_T       desc_size;
    META_T       desc_meta;

    logic        packet_event;
    logic[31:0]  packet_event_size;
    status_t     packet_event_status;

    // -----------------------------
    // Full/Write Ready
    // -----------------------------
    assign __count = __wr_ptr - tail_ptr;

    always @(posedge clk) begin
        if (srst)                         __full <= 1'b0;
        else begin
            if (__count > BUFFER_WORDS-2) __full <= 1'b1;
            else                          __full <= 1'b0;
        end
    end

    generate
        if (IGNORE_RDY) begin : g__ignore_rdy
            assign rdy = 1'b1;
        end : g__ignore_rdy
        else begin : g__obey_rdy
            initial rdy = 1'b0;
            always @(posedge clk) begin
                if (srst)                         rdy <= 1'b0;
                else begin
                    if (__count > BUFFER_WORDS-2) rdy <= 1'b0;
                    else                          rdy <= 1'b1;
                end
            end
        end : g__obey_rdy
    endgenerate

    assign packet_if.rdy = rdy;

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
        reset_wr_ptr = 1'b0;
        rewind_wr_ptr = 1'b0;
        inc_wr_ptr = 1'b0;
        __pkt_done = 1'b0;
        __pkt_status = STATUS_UNDEFINED;
        case (state)
            RESET: begin
                reset_wr_ptr = 1'b1;
                nxt_state = SOP;
            end
            SOP: begin
                if (packet_if.valid && rdy) begin
                    if (packet_if.eop) begin
                        __pkt_done = 1'b1;
                        if (packet_if.err) __pkt_status = STATUS_ERR;
                        else if (MIN_PKT_SIZE < DATA_BYTE_WID) begin
                            if (packet_if.mty > (DATA_BYTE_WID - MIN_PKT_SIZE)) __pkt_status = STATUS_SHORT;
                            else begin
                                inc_wr_ptr = 1'b1;
                                __pkt_status = STATUS_OK;
                            end
                        end else if (MAX_PKT_SIZE < DATA_BYTE_WID) begin
                            if (packet_if.mty < (DATA_BYTE_WID - MAX_PKT_SIZE)) __pkt_status = STATUS_LONG;
                            else begin
                                inc_wr_ptr = 1'b1;
                                __pkt_status = STATUS_OK;
                            end
                        end else if (__full) __pkt_status = STATUS_OFLOW;
                        else begin
                            inc_wr_ptr = 1'b1;
                            __pkt_status = STATUS_OK;
                        end
                    end else if (__full) begin
                        nxt_state = FLUSH;
                    end else begin
                        inc_wr_ptr = 1'b1;
                        nxt_state = MOP;
                    end
                end
            end
            MOP: begin
                if (packet_if.valid && rdy) begin
                    if (packet_if.eop) begin
                        __pkt_done = 1'b1;
                        if (packet_if.err) begin
                            rewind_wr_ptr = 1'b1;
                            __pkt_status = STATUS_ERR;
                        end else if (__pkt_size < MIN_PKT_SIZE) begin
                            rewind_wr_ptr = 1'b1;
                            __pkt_status = STATUS_SHORT;
                        end else if (__pkt_size > MAX_PKT_SIZE) begin
                            rewind_wr_ptr = 1'b1;
                            __pkt_status = STATUS_LONG;
                        end else if (__full) begin
                            rewind_wr_ptr = 1'b1;
                            __pkt_status = STATUS_OFLOW;
                        end else begin
                            inc_wr_ptr = 1'b1;
                            __pkt_status = STATUS_OK;
                        end
                        nxt_state = SOP;
                    end else begin
                        if (__words == MAX_PKT_WORDS) begin
                            nxt_state = FLUSH;
                        end else if (__full) begin
                            nxt_state = FLUSH;
                        end else begin
                            inc_wr_ptr = 1'b1;
                        end
                    end
                end
            end
            FLUSH: begin
                rewind_wr_ptr = 1'b1;
                if (packet_if.valid && rdy) begin
                    if (packet_if.eop) begin
                        __pkt_done = 1'b1;
                        if (packet_if.err)                  __pkt_status = STATUS_ERR;
                        else if (__pkt_size > MAX_PKT_SIZE) __pkt_status = STATUS_LONG;
                        else                                __pkt_status = STATUS_OFLOW;
                        nxt_state = SOP;
                    end
                end
            end
            default: begin
                nxt_state = RESET;
            end
        endcase
    end

    // Write pointer
    initial __wr_ptr = '0;
    always @(posedge clk) begin
        if (reset_wr_ptr) __wr_ptr <= '0;
        else if (inc_wr_ptr) __wr_ptr <= __wr_ptr + 1;
        else if (rewind_wr_ptr) __wr_ptr <= __head_ptr;
    end

    // Write word count
    initial __words = 1;
    always @(posedge clk) begin
        if (srst) __words <= 1;
        else begin
            if (__pkt_done) __words <= 1;
            else if (packet_if.valid && rdy) begin
                if (__words < MAX_PKT_WORDS) __words <= __words + 1;
            end
        end
    end
    assign __pkt_size = (__words * DATA_BYTE_WID) - packet_if.mty;

    // Drive memory write interface
    assign mem_wr_if.rst = 1'b0;
    assign mem_wr_if.en = rdy;
    assign mem_wr_if.req = packet_if.valid;
    assign mem_wr_if.addr = __wr_ptr[ADDR_WID-1:0];
    assign mem_wr_if.data = packet_if.data;

    // Latch and export packet descriptor
    initial desc_valid = 1'b0;
    always @(posedge clk) begin
        if (srst) desc_valid <= 1'b0;
        else begin
            if (__pkt_done && __pkt_status == STATUS_OK) desc_valid <= 1'b1;
            else                                         desc_valid <= 1'b0;
        end
    end
    always_ff @(posedge clk) begin
        if (__pkt_done && __pkt_status == STATUS_OK) begin
            desc_addr <= packet_if.sop ? __wr_ptr : __head_ptr[ADDR_WID-1:0];
            desc_size <= __pkt_size;
            desc_meta <= packet_if.meta;
        end
    end

    assign descriptor_if.valid  = desc_valid;
    assign descriptor_if.addr   = desc_addr;
    assign descriptor_if.size   = desc_size;
    assign descriptor_if.meta   = desc_meta;

    // Report packet event
    always_ff @(posedge clk) begin
        if (__pkt_done) begin
            packet_event <= 1'b1;
            packet_event_size <= __pkt_size;
            packet_event_status <= __pkt_status;
        end
    end
    assign event_if.evt = packet_event;
    assign event_if.size = packet_event_size;
    assign event_if.status = packet_event_status;

    // Update head pointer after successful packet write
    initial __head_ptr = '0;
    always @(posedge clk) begin
        if (reset_wr_ptr)       __head_ptr <= '0;
        else if (packet_if.sop) __head_ptr <= __wr_ptr;
    end
    assign head_ptr = __head_ptr;

endmodule : packet_enqueue
