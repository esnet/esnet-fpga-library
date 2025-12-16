// Convert transactions on a single (wide) interface into
// matched transactions on N (narrow) interfaces (slices)
module mem_rd_aggregate #(
    parameter int N = 2,
    parameter int ALIGNMENT_DEPTH = 8
) (
    mem_rd_intf.peripheral from_controller,
    mem_rd_intf.controller to_peripheral [N],

    // Status
    output logic req_oflow[N],
    output logic req_pending[N],
    output logic resp_oflow[N],
    output logic resp_pending[N]
);

    localparam int ADDR_WID = from_controller.ADDR_WID;
    localparam int NARROW_DATA_WID = to_peripheral[0].DATA_WID;

    initial begin
        std_pkg::param_check(from_controller.DATA_WID, N*NARROW_DATA_WID, "DATA_WID");
        std_pkg::param_check(from_controller.ADDR_WID, to_peripheral[0].ADDR_WID, "ADDR_WID");
    end

    logic [N-1:0] rdy_vec;
    logic         rdy;

    logic [N-1:0][NARROW_DATA_WID-1:0] data;

    logic [N-1:0] ack_vec;
    logic         ack;

    generate
        if (N > 1) begin : g__agg
            for (genvar i = 0; i < N; i++) begin : g__slice
                // Requests
                fifo_prefetch #(
                    .DATA_WID  ( ADDR_WID ),
                    .PIPELINE_DEPTH ( 32 ),
                    .REPORT_OFLOW   ( 1 )
                ) i_fifo_prefetch__req (
                    .clk     ( from_controller.clk ),
                    .srst    ( from_controller.rst ),
                    .wr      ( from_controller.req && from_controller.rdy ),
                    .wr_rdy  ( rdy_vec[i] ),
                    .wr_data ( from_controller.addr ),
                    .rd      ( to_peripheral[i].rdy ),
                    .rd_vld  ( to_peripheral[i].req ),
                    .rd_data ( to_peripheral[i].addr ),
                    .oflow   ( req_oflow[i] )
                );
                assign req_pending[i] = to_peripheral[i].req;

                assign to_peripheral[i].rst  = from_controller.rst;

                // Align responses
                fifo_ctxt #(
                    .DATA_WID ( NARROW_DATA_WID ),
                    .DEPTH    ( ALIGNMENT_DEPTH ),
                    .REPORT_OFLOW ( 1 ),
                    .REPORT_UFLOW ( 1 )
                ) i_fifo_ctxt__resp (
                    .clk      ( from_controller.clk ),
                    .srst     ( from_controller.rst ),
                    .wr       ( to_peripheral[i].ack ),
                    .wr_rdy   ( ),
                    .wr_data  ( to_peripheral[i].data ),
                    .rd       ( ack ),
                    .rd_vld   ( ack_vec[i] ),
                    .rd_data  ( data[i] ),
                    .oflow    ( resp_oflow[i] ),
                    .uflow    ( )
                );

                assign resp_pending[i] = ack_vec[i];

            end : g__slice

            always_ff @(posedge from_controller.clk) rdy <= &rdy_vec;
            assign ack = &ack_vec;

            assign from_controller.rdy = rdy;
            assign from_controller.data = data;
            assign from_controller.ack = ack;

        end : g__agg
        else begin : g__no_agg
            mem_rd_intf_connector i_mem_rd_if_connector (.from_controller, .to_peripheral(to_peripheral[0]));

            assign req_oflow[0] = 1'b0;
            assign req_pending[0] = 1'b0;
            assign resp_oflow[0] = 1'b0;
            assign resp_pending[0] = 1'b0;
        end : g__no_agg
    endgenerate

endmodule : mem_rd_aggregate
