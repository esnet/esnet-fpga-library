// Synchronizer metastability resolution stage
// - implements a pipeline of metastability FFs to be used
//   as the foundation of a general-purpose synchronizer library
// - registers signal in input clock domain to prevent glitch propagation
// - NOTE: may be insufficient on its own for synchronization
//   Specifically, while metastability is handled, no guarantees are
//   provided that transitions on the input are registered by the output
//   (i.e. no handshaking). An async FIFO, or the sync_event, sync_bus or
//   sync_ctr modules may be more appropriate in most cases.
module sync_meta #(
    parameter type  DATA_T = logic,
    parameter DATA_T RST_VALUE = 'x
) (
    // Input clock domain
    input  logic  clk_in,
    input  logic  rst_in,
    input  DATA_T sig_in,
    // Output clock domain
    input  logic  clk_out,
    input  logic  rst_out,
    output DATA_T sig_out
);
    localparam int STAGES = sync_pkg::RETIMING_STAGES;

    (* DONT_TOUCH = "TRUE" *) DATA_T __sync_ff_in;
    (* ASYNC_REG = "TRUE" *) DATA_T __sync_ff_meta [STAGES];

    // Register input signal in input clock domain
    initial __sync_ff_in = RST_VALUE;
    always @(posedge clk_in) begin
        if (rst_in) __sync_ff_in <= RST_VALUE;
        else        __sync_ff_in <= sig_in;
    end

    initial __sync_ff_meta = '{STAGES{RST_VALUE}};
    always @(posedge clk_out) begin
        if (rst_out) __sync_ff_meta <= '{STAGES{RST_VALUE}};
        else begin
            for (int i = 1; i < STAGES; i++) begin
                __sync_ff_meta[i] <= __sync_ff_meta[i-1];
            end
            __sync_ff_meta[0] <= __sync_ff_in;
        end
    end
    assign sig_out = __sync_ff_meta[STAGES-1];

endmodule : sync_meta
