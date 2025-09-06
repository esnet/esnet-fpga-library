// Convert transactions on a single (wide) interface into
// matched transactions on N (narrow) interfaces (slices)
module mem_wr_aggregate #(
    parameter int N = 2,
    parameter int ALIGNMENT_DEPTH = 8
) (
    mem_wr_intf.peripheral from_controller,
    mem_wr_intf.controller to_peripheral [N]
);

    localparam int PERIPHERAL_DATA_WID = to_peripheral[0].DATA_WID;

    initial begin
        std_pkg::param_check(from_controller.DATA_WID, N*to_peripheral[0].DATA_WID, "DATA_WID");
        std_pkg::param_check(from_controller.ADDR_WID,   to_peripheral[0].ADDR_WID, "ADDR_WID");
    end

    logic [N-1:0] rdy_vec;
    logic         rdy;

    logic [N-1:0] ack_vec;
    logic         ack;

    generate
        if (N > 1) begin : g__agg
            for (genvar i = 0; i < N; i++) begin : g__slice
                assign to_peripheral[i].rst  = from_controller.rst;
                assign to_peripheral[i].en   = from_controller.en;
                assign to_peripheral[i].req  = from_controller.req;
                assign to_peripheral[i].addr = from_controller.addr;
                assign to_peripheral[i].data = from_controller.data[i*PERIPHERAL_DATA_WID +: PERIPHERAL_DATA_WID];

                assign rdy_vec[i] = to_peripheral[i].rdy;

                // Align responses
                fifo_small_ctxt #(
                    .DATA_WID    ( 1 ),
                    .DEPTH       ( ALIGNMENT_DEPTH )
                ) i_fifo_ctxt (
                    .clk      ( from_controller.clk ),
                    .srst     ( from_controller.rst ),
                    .wr       ( to_peripheral[i].ack ),
                    .wr_rdy   ( ),
                    .wr_data  ( 1'b1 ),
                    .rd       ( ack ),
                    .rd_vld   ( ack_vec[i] ),
                    .rd_data  ( ),
                    .oflow    ( ),
                    .uflow    ( )
                );
            end : g__slice

            assign rdy = &rdy_vec;
            assign ack = &ack_vec;

            assign from_controller.rdy = rdy;
            assign from_controller.ack = ack;

        end : g__agg
        else begin : g__no_agg
            mem_wr_intf_connector i_mem_wr_if_connector (.from_controller, .to_peripheral(to_peripheral[0]));
        end : g__no_agg
    endgenerate

endmodule : mem_wr_aggregate
