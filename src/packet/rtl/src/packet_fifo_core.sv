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
    localparam type META_T = packet_in_if.META_T;

    localparam int  ADDR_WID = $clog2(DEPTH);
    localparam int  PTR_WID = ADDR_WID + 1;
    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam type PTR_T = logic[PTR_WID-1:0];

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
            // (Local) interfaces
            packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) wr_descriptor_if__in_clk  (.clk(packet_in_if.clk),  .srst(packet_in_if.srst));
            packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) wr_descriptor_if__out_clk (.clk(packet_out_if.clk), .srst(packet_out_if.srst));
            packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) rd_descriptor_if__in_clk  (.clk(packet_in_if.clk),  .srst(packet_in_if.srst));
            packet_descriptor_intf #(.ADDR_T(ADDR_T), .META_T(META_T)) rd_descriptor_if__out_clk (.clk(packet_out_if.clk), .srst(packet_out_if.srst));

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
                .mem_init_done
            );
            // Descriptor FIFOs
            // -- Forward (in to out)
            packet_descriptor_fifo #(
                .DEPTH         ( MAX_DESCRIPTORS ),
                .ASYNC         ( ASYNC )
            ) i_packet_descriptor_fifo (
                .from_tx       ( wr_descriptor_if__in_clk ),
                .to_rx         ( wr_descriptor_if__out_clk )
            );
            if (ASYNC) begin : g__async
                // -- Reverse (out to in)
                packet_descriptor_fifo #(
                    .DEPTH         ( 8 ),
                    .ASYNC         ( 1 )
                ) i_packet_descriptor_fifo (
                    .from_tx       ( rd_descriptor_if__out_clk ),
                    .to_rx         ( rd_descriptor_if__in_clk )
                );
            end : g__async
            else begin : g__sync
                packet_descriptor_intf_connector i_packet_descriptor_intf_connector (
                    .from_tx   ( rd_descriptor_if__out_clk ),
                    .to_rx     ( rd_descriptor_if__in_clk )
                );
            end : g__sync

            // Read FSM
            packet_read          #(
                .IGNORE_RDY       ( IGNORE_RDY_OUT ),
                .MAX_RD_LATENCY   ( MAX_RD_LATENCY )
            ) i_packet_read       (
                .clk              ( packet_out_if.clk ),
                .srst             ( packet_out_if.srst ),
                .packet_if        ( packet_out_if ),
                .descriptor_if    ( wr_descriptor_if__out_clk ),
                .event_if         ( event_out_if ),
                .mem_rd_if
            );

            assign rd_descriptor_if__out_clk.valid = wr_descriptor_if__out_clk.valid && wr_descriptor_if__out_clk.rdy;
            assign rd_descriptor_if__out_clk.addr = wr_descriptor_if__out_clk.addr;
            assign rd_descriptor_if__out_clk.size = wr_descriptor_if__out_clk.size;
            assign rd_descriptor_if__out_clk.meta = wr_descriptor_if__out_clk.meta;
            assign rd_descriptor_if__out_clk.err = wr_descriptor_if__out_clk.err;

        end : g__store_and_forward
    endgenerate

endmodule : packet_fifo_core
