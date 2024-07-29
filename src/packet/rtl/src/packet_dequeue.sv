module packet_dequeue
    import packet_pkg::*;
#(
    parameter int  DATA_BYTE_WID = 1,
    parameter int  BUFFER_WORDS = 1, // Buffer size (in words of DATA_BYTE_WID)
    parameter type META_T = logic,
    parameter bit  IGNORE_RDY = 0,
    parameter int  MAX_RD_LATENCY = 8,
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
    packet_intf.tx              packet_if,

    // Circular buffer interface
    input  PTR_T                head_ptr,
    output PTR_T                tail_ptr,

    // Packet completion interface
    packet_descriptor_intf.rx   descriptor_if,

    // Packet reporting interface
    packet_event_intf.publisher event_if, 

    // Memory write interface
    mem_rd_intf.controller      mem_rd_if
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];
    localparam int  MTY_WID  = $clog2(DATA_BYTE_WID);
    localparam type MTY_T    = logic[MTY_WID-1:0];

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
        std_pkg::param_check(mem_rd_if.DATA_WID, DATA_WID, "mem_rd_if.DATA_WID");
        std_pkg::param_check($bits(descriptor_if.ADDR_T),ADDR_WID,"descriptor_if.ADDR_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [1:0] {
        RESET = 0,
        SOP = 1,
        MOP = 2,
        FLUSH = 3
    } state_t;

    typedef struct packed {
        logic  eop;
        MTY_T  mty;
        META_T meta;
    } ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    PTR_T  __rd_ptr;
    PTR_T  __count;
    logic  __empty;
    logic  __prefetch_rdy;

    ADDR_T __desc_addr_last;

    ctxt_t ctxt_in;
    ctxt_t ctxt_out;

    // -----------------------------
    // Buffer count/empty
    // -----------------------------
    assign __count = head_ptr - __rd_ptr;
    assign __empty = (__count == 0);

    // -----------------------------
    // Read/tail pointer
    // -----------------------------
    initial __rd_ptr = '0;
    always @(posedge clk) begin
        if (srst)                                __rd_ptr <= '0;
        else if (mem_rd_if.req && mem_rd_if.rdy) __rd_ptr <= __rd_ptr + 1;
    end

    // Tail pointer is exact copy of read pointer; don't need to wait
    // until full packet is read since as each word is read out it is
    // no longer needed, and there is no scenario where the read pointer
    // could be rewound (i.e. no retransmission supported)
    assign tail_ptr = __rd_ptr;

    // -----------------------------
    // Drive memory read interface
    // -----------------------------
    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.addr = __rd_ptr[ADDR_WID-1:0];
    assign mem_rd_if.req = !__empty && __prefetch_rdy && descriptor_if.valid;

    // -----------------------------
    // Synthesize packet context from descriptor
    // -----------------------------
    assign __desc_addr_last = descriptor_if.addr + (descriptor_if.size - 1) / DATA_BYTE_WID;
    assign ctxt_in.eop = (__rd_ptr == __desc_addr_last);
    assign ctxt_in.mty = ctxt_in.eop ? (DATA_BYTE_WID - descriptor_if.size % DATA_BYTE_WID) % DATA_BYTE_WID : '0;
    assign ctxt_in.meta = descriptor_if.meta;

    assign descriptor_if.rdy = mem_rd_if.req && mem_rd_if.rdy ? ctxt_in.eop : 1'b0;

    generate
        if (IGNORE_RDY) begin : g__ignore_rdy
            // Backpressure from receiver not supported; no prefetch needed
            assign __prefetch_rdy = 1'b1;
           
            assign packet_if.valid = mem_rd_if.ack;
            assign packet_if.data = mem_rd_if.data;

            fifo_small  #(
                .DATA_T  ( ctxt_t ),
                .DEPTH   ( MAX_RD_LATENCY )
            ) i_fifo_small__ctxt (
                .clk     ( clk ),
                .srst    ( srst ),
                .wr      ( mem_rd_if.req && mem_rd_if.rdy ),
                .wr_data ( ctxt_in ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( mem_rd_if.ack ),
                .rd_data ( ctxt_out ),
                .empty   ( ),
                .uflow   ( )
            );

        end : g__ignore_rdy
        else begin : g__obey_rdy
            // Backpressure from receiver supported; prefetch needed

            // (Local) parameters
            localparam int PREFETCH_DEPTH = MAX_RD_LATENCY * 2 > 8 ? MAX_RD_LATENCY * 2 : 8;
            localparam int PREFETCH_CNT_WID = $clog2(PREFETCH_DEPTH+1);
            // (Local) typedefs
            typedef logic[PREFETCH_CNT_WID-1:0] prefetch_cnt_t;
            // (Local) signals
            prefetch_cnt_t __prefetch_cnt;
            logic          __prefetch_oflow;

            // Prefetch buffer (data)
            fifo_sync    #(
                .DATA_T   ( DATA_T ),
                .DEPTH    ( PREFETCH_DEPTH ),
                .FWFT     ( 1 )
            ) i_fifo_sync__prefetch_data (
                .clk      ( clk ),
                .srst     ( srst ),
                .wr_rdy   ( ),
                .wr       ( mem_rd_if.ack ),
                .wr_data  ( mem_rd_if.data ),
                .wr_count ( __prefetch_cnt ),
                .full     ( ),
                .oflow    ( __prefetch_oflow ),
                .rd       ( packet_if.rdy ),
                .rd_ack   ( packet_if.valid ),
                .rd_data  ( packet_if.data ),
                .rd_count ( ),
                .empty    ( ),
                .uflow    ( )
            );

            // Prefetch buffer (context)
            fifo_sync    #(
                .DATA_T   ( ctxt_t ),
                .DEPTH    ( PREFETCH_DEPTH ),
                .FWFT     ( 1 )
            ) i_fifo_sync__prefetch_ctxt (
                .clk      ( clk ),
                .srst     ( srst ),
                .wr_rdy   ( ),
                .wr       ( mem_rd_if.req && mem_rd_if.rdy),
                .wr_data  ( ctxt_in ),
                .wr_count ( ),
                .full     ( ),
                .oflow    ( ),
                .rd       ( packet_if.valid && packet_if.rdy ),
                .rd_data  ( ctxt_out ),
                .rd_ack   ( ),
                .rd_count ( ),
                .empty    ( ),
                .uflow    ( )
            );

            // Ready
            assign __prefetch_rdy = (__prefetch_cnt <= PREFETCH_DEPTH / 2);

        end : g__obey_rdy
    endgenerate

    assign packet_if.eop  = ctxt_out.eop;
    assign packet_if.mty  = ctxt_out.mty;
    assign packet_if.err  = 1'b0;
    assign packet_if.meta = ctxt_out.meta;

    // Drive event interface
    assign event_if.evt = packet_if.valid && (packet_if.rdy || IGNORE_RDY) && packet_if.eop;
    assign event_if.size = 0; // TODO
    assign event_if.status = STATUS_OK;


endmodule : packet_dequeue
