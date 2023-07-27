// Bus synchronizer (sampled)
// - synchronizes sampled value of bus from input
//   clock domain to output clock domain using two-way handshake
// - sampling rate is as fast as possible, given two-way
//   synchronizer delay
// - NOTE: the sampling rate will be much lower than the clock
//   rate, so only suitable for instances where it is acceptable
//   for the bus to be sampled infrequently.
//   In many cases, an async FIFO is a better choice.
module sync_bus_sampled
    import sync_pkg::*;
#(
    parameter type     DATA_T = logic,
    parameter DATA_T   RST_VALUE = {$bits(DATA_T){1'bx}},
    parameter handshake_mode_t HANDSHAKE_MODE = HANDSHAKE_MODE_4PHASE
) (
    // Input clock domain
    input  logic  clk_in,
    input  logic  rst_in,
    input  DATA_T data_in,
    // Output clock domain
    input  logic  clk_out,
    input  logic  rst_out,
    output DATA_T data_out
);
    // Bus synchronizer (two-way handshake)
    // - request is processed only when synchronizer is ready
    //   i.e. when no synchronization process is in progress
    // - setting req_in = 1'b1 ensures that sampling/synchronizing
    //   happens as fast as possible given the two-way
    //   synchronizer delays
    sync_bus #(
        .DATA_T         ( DATA_T ),
        .RST_VALUE      ( RST_VALUE ),
        .HANDSHAKE_MODE ( HANDSHAKE_MODE )
    ) i_sync_bus  (
        .clk_in   ( clk_in ),
        .rst_in   ( rst_in ),
        .rdy_in   ( ),
        .req_in   ( 1'b1 ),
        .data_in  ( data_in ),
        .clk_out  ( clk_out ),
        .rst_out  ( rst_out ),
        .ack_out  ( ),
        .data_out ( data_out )
    );

endmodule : sync_bus_sampled
