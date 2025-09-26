module packet_fifo_core
#(
    parameter bit  ASYNC = 0,
    parameter bit  CUT_THROUGH = 0,
    parameter bit  IGNORE_RDY_IN = 0,
    parameter bit  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
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
    mem_rd_intf.controller      mem_rd_if,

    input logic                 mem_init_done
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_in_if.DATA_BYTE_WID;
    localparam int  META_WID = packet_in_if.META_WID;

    localparam int  MAX_PKT_WORDS = MAX_PKT_SIZE % DATA_BYTE_WID == 0 ? MAX_PKT_SIZE / DATA_BYTE_WID : MAX_PKT_SIZE / DATA_BYTE_WID + 1;

    localparam int  ADDR_WID = $clog2(DEPTH);
    localparam int  PTR_WID = ADDR_WID + 1;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_out_if.DATA_BYTE_WID, packet_in_if.DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check(packet_out_if.META_WID, packet_in_if.META_WID, "to_rx.META_WID");
        if (!CUT_THROUGH) std_pkg::param_check_gt(DEPTH, MAX_PKT_WORDS, "DEPTH");
    end

    // -----------------------------
    // Logic
    // -----------------------------
    generate
        if (CUT_THROUGH) begin : g__cut_through
            // TODO
        end : g__cut_through
        else begin : g__store_and_forward
            // (Local) interfaces
            packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) wr_descriptor_if__in_clk  [1] (.clk(packet_in_if.clk),  .srst(packet_in_if.srst));
            packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) wr_descriptor_if__out_clk [1] (.clk(packet_out_if.clk), .srst(packet_out_if.srst));
            packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) rd_descriptor_if__in_clk  [1] (.clk(packet_in_if.clk),  .srst(packet_in_if.srst));
            packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) rd_descriptor_if__out_clk [1] (.clk(packet_out_if.clk), .srst(packet_out_if.srst));

            // Enqueue FSM
            packet_enqueue       #(
                .IGNORE_RDY       ( IGNORE_RDY_IN ),
                .DROP_ERRORED     ( DROP_ERRORED ),
                .MIN_PKT_SIZE     ( MIN_PKT_SIZE ),
                .MAX_PKT_SIZE     ( MAX_PKT_SIZE )
            ) i_packet_enqueue    (
                .clk              ( packet_in_if.clk ),
                .srst             ( packet_in_if.srst ),
                .packet_if        ( packet_in_if ),
                .wr_descriptor_if ( wr_descriptor_if__in_clk ),
                .rd_descriptor_if ( rd_descriptor_if__in_clk ),
                .event_if         ( event_in_if ),
                .mem_wr_if,
                .mem_wr_ctxt      ( ),
                .mem_init_done,
                // Unused for single-context implementation
                .ctxt_list_append_rdy ( ),
                .ctxt_out_valid       ( ),
                .ctxt_out             ( )
            );
            // Descriptor FIFOs
            // -- Forward (in to out)
            packet_descriptor_fifo #(
                .DEPTH         ( MAX_DESCRIPTORS ),
                .ASYNC         ( ASYNC )
            ) i_packet_descriptor_fifo (
                .from_tx       ( wr_descriptor_if__in_clk [0] ),
                .to_rx         ( wr_descriptor_if__out_clk[0] )
            );
            if (ASYNC) begin : g__async
                // -- Reverse (out to in)
                packet_descriptor_fifo #(
                    .DEPTH         ( 8 ),
                    .ASYNC         ( 1 )
                ) i_packet_descriptor_fifo (
                    .from_tx       ( rd_descriptor_if__out_clk[0] ),
                    .to_rx         ( rd_descriptor_if__in_clk [0] )
                );
            end : g__async
            else begin : g__sync
                packet_descriptor_intf_connector i_packet_descriptor_intf_connector (
                    .from_tx   ( rd_descriptor_if__out_clk[0] ),
                    .to_rx     ( rd_descriptor_if__in_clk [0] )
                );
            end : g__sync

            // Dequeue FSM
            packet_dequeue       #(
                .IGNORE_RDY       ( IGNORE_RDY_OUT ),
                .MAX_RD_LATENCY   ( MAX_RD_LATENCY )
            ) i_packet_read       (
                .clk              ( packet_out_if.clk ),
                .srst             ( packet_out_if.srst ),
                .packet_if        ( packet_out_if ),
                .wr_descriptor_if ( wr_descriptor_if__out_clk ),
                .rd_descriptor_if ( rd_descriptor_if__out_clk ),
                .event_if         ( event_out_if ),
                .mem_rd_if,
                .mem_rd_ctxt      ( ),
                .mem_init_done,
                // Unused for single-context implementation
                .ctxt_list_append_rdy ( ),
                .ctxt_out_valid       ( ),
                .ctxt_out             ( )
            );

        end : g__store_and_forward
    endgenerate

endmodule : packet_fifo_core
