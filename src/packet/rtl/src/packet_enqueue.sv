module packet_enqueue
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

    // Packet write completion interface
    packet_descriptor_intf.tx   wr_descriptor_if,

    // Packet read completion interface
    packet_descriptor_intf.rx   rd_descriptor_if,

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

    localparam type ADDR_T = wr_descriptor_if.ADDR_T;
    localparam int ADDR_WID = $bits(ADDR_T);
    localparam int MEM_DEPTH = 2**ADDR_WID;
    localparam int PTR_WID = ADDR_WID + 1;
    localparam type PTR_T = logic[PTR_WID-1:0];

    localparam type META_T = packet_if.META_T;
    localparam int META_WID = $bits(META_T);

    localparam type SIZE_T = wr_descriptor_if.SIZE_T;
    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE + 1);

    localparam int MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;
    localparam int WORD_CNT_WID = $clog2(MAX_PKT_WORDS+1);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(mem_wr_if.DATA_WID, DATA_WID, "mem_wr_if.DATA_WID");
        std_pkg::param_check(mem_wr_if.ADDR_WID, ADDR_WID, "mem_wr_if.ADDR_WID");
        std_pkg::param_check($bits(wr_descriptor_if.META_T), META_WID, "wr_descriptor_if.META_T");
        std_pkg::param_check($bits(rd_descriptor_if.META_T), META_WID, "rd_descriptor_if.META_T");
        std_pkg::param_check($bits(rd_descriptor_if.ADDR_T),ADDR_WID,"rd_descriptor_if.ADDR_T");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    PTR_T  head_ptr;
    PTR_T  tail_ptr;
    PTR_T  count;
    PTR_T  avail;

    PTR_T  desc_words;
    SIZE_T desc_size;

    // -----------------------------
    // Interfaces
    // -----------------------------
    packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) nxt_descriptor_if (.clk(clk));

    // -----------------------------
    // Pointer logic
    // -----------------------------
    initial head_ptr = '0;
    always @(posedge clk) begin
        if (srst) head_ptr <= '0;
        else if (wr_descriptor_if.valid) head_ptr <= head_ptr + (wr_descriptor_if.size-1)/DATA_BYTE_WID + 1;
    end

    always @(posedge clk) begin
        if (srst) tail_ptr <= '0;
        else if (rd_descriptor_if.valid) tail_ptr <= tail_ptr + (rd_descriptor_if.size-1)/DATA_BYTE_WID + 1;
    end
    assign rd_descriptor_if.rdy = 1'b1;

    // -----------------------------
    // Full/Write Ready
    // -----------------------------
    assign count = head_ptr - tail_ptr;
    assign avail = MEM_DEPTH - count;

    initial desc_words = 0;
    always @(posedge clk) begin
        if (srst) desc_words <= MAX_PKT_WORDS;
        else begin
            if (avail >= MAX_PKT_WORDS) desc_words <= MAX_PKT_WORDS;
            else desc_words <= avail;
        end
    end
    assign desc_size = desc_words * DATA_BYTE_WID;

    // -----------------------------
    // Packet write
    // -----------------------------
    packet_write     #(
        .IGNORE_RDY   ( IGNORE_RDY ),
        .DROP_ERRORED ( DROP_ERRORED ),
        .MIN_PKT_SIZE ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE )
    ) i_packet_write  (
        .clk,
        .srst,
        .packet_if,
        .nxt_descriptor_if,
        .descriptor_if ( wr_descriptor_if ),
        .event_if,
        .mem_wr_if,
        .mem_init_done
    );

    assign nxt_descriptor_if.valid = 1'b1;
    assign nxt_descriptor_if.addr = head_ptr;
    assign nxt_descriptor_if.size = desc_size;
    assign nxt_descriptor_if.meta = 'x;
    assign nxt_descriptor_if.err = 1'bx;

endmodule : packet_enqueue
