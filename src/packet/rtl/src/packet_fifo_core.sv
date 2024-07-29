module packet_fifo_core
#(
    parameter bit  ASYNC = 0,
    parameter bit  CUT_THROUGH = 0,
    parameter int  IGNORE_RDY_IN = 0,
    parameter int  IGNORE_RDY_OUT = 0,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  DEPTH = 512,
    parameter int  MAX_DESCRIPTORS = 32,
    parameter int  MAX_RD_LATENCY = 8
 ) (
    // Packet input (synchronous to packet_in_if.clk)
    packet_intf.rx              packet_in_if,
    packet_event_intf.publisher event_in_if,
    mem_wr_intf.controller      mem_wr_if,
    
    // Packet output (synchronous to packet_out_if.clk)
    packet_intf.tx              packet_out_if,
    packet_event_intf.publisher event_out_if,
    mem_rd_intf.controller      mem_rd_if
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_in_if.DATA_BYTE_WID;
    localparam type META_T = packet_in_if.META_T;

    localparam int  ADDR_WID = $clog2(DEPTH);
    parameter int   PTR_WID = ADDR_WID + 1;
    parameter type  ADDR_T = logic[ADDR_WID-1:0];
    parameter type  PTR_T = logic[PTR_WID-1:0];

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_out_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_out_if.DATA_BYTE_WID");
        std_pkg::param_check($bits(packet_out_if.META_T), $bits(META_T), "packet_out_if.META_T");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    generate
        if (CUT_THROUGH) begin : g__cut_through
            // TODO
        end : g__cut_through
        else begin : g__store_and_forward
            // (Local) signals
            PTR_T head_ptr;
            PTR_T tail_ptr;

            // (Local) interfaces
            packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) descriptor_in_if  (.clk(packet_in_if.clk),  .srst(packet_in_if.srst));
            packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) descriptor_out_if (.clk(packet_out_if.clk), .srst(packet_out_if.srst));

            // Enqueue FSM
            packet_enqueue #(
                .DATA_BYTE_WID ( DATA_BYTE_WID ),
                .BUFFER_WORDS  ( DEPTH ),
                .META_T        ( META_T ),
                .IGNORE_RDY    ( IGNORE_RDY_IN ),
                .MIN_PKT_SIZE  ( MIN_PKT_SIZE ),
                .MAX_PKT_SIZE  ( MAX_PKT_SIZE )
            ) i_packet_enqueue (
                .clk           ( packet_in_if.clk ),
                .srst          ( packet_in_if.srst ),
                .packet_if     ( packet_in_if ),
                .descriptor_if ( descriptor_in_if ),
                .event_if      ( event_in_if ),
                .*
            );
            // Descriptor FIFO
            packet_descriptor_fifo #(
                .DEPTH         ( MAX_DESCRIPTORS ),
                .ASYNC         ( ASYNC )
            ) i_packet_descriptor_fifo (
                .from_tx       ( descriptor_in_if ),
                .to_rx         ( descriptor_out_if )
            );    
            // Dequeue FSM
            packet_dequeue #(
                .DATA_BYTE_WID ( DATA_BYTE_WID ),
                .BUFFER_WORDS  ( DEPTH ),
                .META_T        ( META_T ),
                .IGNORE_RDY    ( IGNORE_RDY_OUT ),
                .MAX_RD_LATENCY( MAX_RD_LATENCY )
            ) i_packet_dequeue (
                .clk           ( packet_out_if.clk ),
                .srst          ( packet_out_if.srst ),
                .packet_if     ( packet_out_if ),
                .descriptor_if ( descriptor_out_if ),
                .event_if      ( event_out_if ),
                .*
            );
        end : g__store_and_forward
    endgenerate

endmodule : packet_fifo_core
