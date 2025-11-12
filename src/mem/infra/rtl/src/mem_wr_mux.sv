// Mux transactions from multiple control interfaces into
// a single peripheral interface, while maintaining state
module mem_wr_mux #(
    parameter int N = 2,
    parameter int NUM_TRANSACTIONS = 8,
    // Derived parameters (don't override)
    parameter int SEL_WID = N > 1 ? $clog2(N): 1
) (
    mem_wr_intf.peripheral from_controller [N],
    mem_wr_intf.controller to_peripheral,
    input logic [SEL_WID-1:0] sel
);
    localparam int ADDR_WID = to_peripheral[0].ADDR_WID;
    localparam int DATA_WID = to_peripheral[0].DATA_WID;

    initial begin
        std_pkg::param_check(from_controller[0].DATA_WID, DATA_WID, "DATA_WID");
        std_pkg::param_check(from_controller[0].ADDR_WID, ADDR_WID, "ADDR_WID");
    end

    logic clk;
    logic srst;

    assign clk = from_controller[0].clk;
    assign srst = from_controller[0].rst;

    generate
        if (N > 1) begin : g__multi_input
            localparam int N_POW2 = 2**SEL_WID;

            logic en                  [N_POW2];
            logic req                 [N_POW2];
            logic [ADDR_WID-1:0] addr [N_POW2];
            logic [DATA_WID-1:0] data [N_POW2];

            logic rdy [N];
            logic ack [N];

            for (genvar g_if = 0; g_if < N; g_if++) begin : g__input
                assign en[g_if] = from_controller[g_if].en;
                assign req[g_if] = from_controller[g_if].req;
                assign addr[g_if] = from_controller[g_if].addr;
                assign data[g_if] = from_controller[g_if].data;
                assign from_controller[g_if].rdy = rdy[g_if];
                assign from_controller[g_if].ack = ack[g_if];
            end : g__input
            // Assign values for sel 'out-of-range'
            for (genvar g_if = N; g_if < N_POW2; g_if++) begin : g__input_out_of_range
                assign en[g_if] = 1'b0;
                assign req[g_if] = 1'b0;
                assign addr[g_if] = 'x;
                assign data[g_if] = 'x;
            end : g__input_out_of_range

            // Request mux
            assign to_peripheral.rst  = srst;

            always_comb begin
                to_peripheral.en = en[sel];
                to_peripheral.req = req[sel];
                to_peripheral.addr = addr[sel];
                to_peripheral.data = data[sel];
                for (int i = 0; i < N; i++) begin
                    if (sel == SEL'(i)) rdy[i] = to_peripheral.rdy;
                    else                rdy[i] = 1'b0;
                end
            end

            // Context FIFO
            fifo_small_ctxt #(
                .DATA_WID    ( SEL_WID ),
                .DEPTH       ( NUM_TRANSACTIONS )
            ) i_fifo_small_ctxt (
                .clk,
                .srst,
                .wr_rdy  ( ),
                .wr      ( to_peripheral.rdy && to_peripheral.en && to_peripheral.req ),
                .wr_data ( sel ),
                .rd      ( to_peripheral.ack ),
                .rd_vld  ( ),
                .rd_data ( sel_out ),
                .oflow   ( ),
                .uflow   ( )
            );

            // Response demux
            always_comb begin
                for (int i = 0; i < N; i++) begin
                    if (sel_out == SEL'(i)) ack[i] = to_peripheral.ack;
                    else                    ack[i] = 1'b0;
                end
            end

        end : g__multi_input
        else begin : g__single_input
            mem_wr_intf_connector i_mem_wr_intf_connector (.from_controller(from_controller[0]), .to_peripheral);
        end : g__single_input

    endgenerate

endmodule : mem_wr_mux
