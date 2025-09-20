// Bus synchronizer
// - synchronizes value carried on bus from input
//   clock domain to output clock domain using two-way handshake
// - NOTE: slow, but suitable for instances where the bus
//   is being sampled infrequently (e.g. latching a register read)
//   In many cases, an async FIFO is a better choice.
module sync_bus
    import sync_pkg::*;
#(
    parameter int                  DATA_WID = 1,
    parameter logic [DATA_WID-1:0] RST_VALUE = 'x,
    parameter handshake_mode_t     HANDSHAKE_MODE = HANDSHAKE_MODE_4PHASE
) (
    // Input clock domain
    input  logic                clk_in,
    input  logic                rst_in,
    output logic                rdy_in,
    input  logic                req_in,
    input  logic [DATA_WID-1:0] data_in,
    // Output clock domain
    input  logic                clk_out,
    input  logic                rst_out,
    output logic                ack_out,
    output logic [DATA_WID-1:0] data_out
);

    // Signals
    (* DONT_TOUCH= "TRUE" *) logic [DATA_WID-1:0] __sync_ff_bus_data_in;
    (* ASYNC_REG = "TRUE" *) logic [DATA_WID-1:0] __sync_ff_bus_data_out;
    logic _ack_out;

    // Latch input data
    always @(posedge clk_in) begin
        if (rst_in) __sync_ff_bus_data_in <= RST_VALUE;
        else begin
            if (req_in && rdy_in) __sync_ff_bus_data_in <= data_in;
        end
    end

    // Latch (stable) output data
    initial __sync_ff_bus_data_out = RST_VALUE;
    always @(posedge clk_out) begin
        if (rst_out) __sync_ff_bus_data_out <= RST_VALUE;
        else begin
            if (_ack_out) __sync_ff_bus_data_out <= __sync_ff_bus_data_in;
        end
    end

    // Two-way synchronization handshake
    // (pass request from input to output, wait for ack from output to input)
    sync_event  #(
        .MODE    ( HANDSHAKE_MODE )
    ) i_sync_event__handshake (
        .clk_in  ( clk_in ),
        .rst_in  ( rst_in ),
        .rdy_in  ( rdy_in ),
        .evt_in  ( req_in ),
        .clk_out ( clk_out ),
        .rst_out ( rst_out ),
        .evt_out ( _ack_out )
    );

    // Retimed output data
    assign data_out = __sync_ff_bus_data_out;

    // Align ack with output data
    initial ack_out = 1'b0;
    always @(posedge clk_out) begin
        if (rst_out) ack_out <= 1'b0;
        else         ack_out <= _ack_out;
    end

endmodule : sync_bus
