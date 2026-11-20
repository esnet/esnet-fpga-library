// Exercise both handshake modes, vector/scalar payloads and opposite clock
// ratios. The unrelated bus uses the same register names but no handshake.
module sync_bus_cdc_wrapper (
    input logic clk_a, clk_b, rst_a, rst_b,
    input logic [3:0] req,
    input logic [16:0] data_in,
    output logic [3:0] rdy, ack,
    output logic [31:0] data_out,
    input logic arbitrary_enable,
    output logic [6:0] arbitrary_out
);
    sync_bus #(.DATA_WID(13), .RST_VALUE(0), .HANDSHAKE_MODE(sync_pkg::HANDSHAKE_MODE_4PHASE)) four_phase (
        .clk_in(clk_a), .rst_in(rst_a), .req_in(req[0]), .rdy_in(rdy[0]), .data_in(data_in[12:0]),
        .clk_out(clk_b), .rst_out(rst_b), .ack_out(ack[0]), .data_out(data_out[12:0])
    );
    sync_bus #(.DATA_WID(17), .RST_VALUE(0), .HANDSHAKE_MODE(sync_pkg::HANDSHAKE_MODE_2PHASE)) two_phase (
        .clk_in(clk_b), .rst_in(rst_b), .req_in(req[1]), .rdy_in(rdy[1]), .data_in,
        .clk_out(clk_a), .rst_out(rst_a), .ack_out(ack[1]), .data_out(data_out[29:13])
    );
    sync_bus #(.DATA_WID(1), .RST_VALUE(0), .HANDSHAKE_MODE(sync_pkg::HANDSHAKE_MODE_4PHASE)) scalar_four (
        .clk_in(clk_a), .rst_in(rst_a), .req_in(req[2]), .rdy_in(rdy[2]), .data_in(data_in[0]),
        .clk_out(clk_b), .rst_out(rst_b), .ack_out(ack[2]), .data_out(data_out[30])
    );
    sync_bus #(.DATA_WID(1), .RST_VALUE(0), .HANDSHAKE_MODE(sync_pkg::HANDSHAKE_MODE_2PHASE)) scalar_two (
        .clk_in(clk_b), .rst_in(rst_b), .req_in(req[3]), .rdy_in(rdy[3]), .data_in(data_in[0]),
        .clk_out(clk_a), .rst_out(rst_a), .ack_out(ack[3]), .data_out(data_out[31])
    );
    sync_bus_cdc_unrelated unrelated (
        .clk_in(clk_a), .clk_out(clk_b), .data_in(data_in[6:0]),
        .enable(arbitrary_enable), .data_out(arbitrary_out)
    );
endmodule

module sync_bus_cdc_unrelated (
    input logic clk_in, clk_out, enable,
    input logic [6:0] data_in,
    output logic [6:0] data_out
);
    (* DONT_TOUCH = "TRUE" *) logic [6:0] __sync_ff_bus_data_in;
    (* ASYNC_REG = "TRUE" *) logic [6:0] __sync_ff_bus_data_out;
    logic enable_q;
    // Deliberately unsafe: source data changes without waiting for acceptance.
    always @(posedge clk_in) __sync_ff_bus_data_in <= data_in;
    always @(posedge clk_out) begin
        enable_q <= enable;
        if (enable_q) __sync_ff_bus_data_out <= __sync_ff_bus_data_in;
    end
    assign data_out = __sync_ff_bus_data_out;
endmodule
