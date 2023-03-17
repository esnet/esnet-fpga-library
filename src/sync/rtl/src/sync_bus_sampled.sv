module sync_bus_sampled #(
    parameter int      STAGES = 3,
    parameter type     DATA_T = logic,
    parameter int      SAMPLE_PERIOD = 8, // Input bus is sampled once every SAMPLE_PERIOD clk_in cycles
    parameter bit      LATCH_DATA_IN = 1'b1,
    parameter DATA_T   RST_VALUE = {$bits(DATA_T){1'bx}}
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

    // Parameters
    localparam int CNT_WID = $clog2(SAMPLE_PERIOD);

    // Parameter Checking
`ifdef SIMULATION
    initial assert(SAMPLE_PERIOD > 1) else $fatal("SAMPLE_PERIOD must be >= 2. (Got %0d).", SAMPLE_PERIOD);
`endif

    // Signals
    logic [CNT_WID-1:0] cnt;
    logic               req_in;

    // Sample counter
    initial cnt = '0;
    always @(posedge clk_in) begin
        if (rst_in) cnt <= '0;
        else        cnt <= (cnt < SAMPLE_PERIOD-1) ? cnt + 1 : '0;
    end

    assign req_in = (cnt == 1);

    // Bus synchronizer
    sync_bus #(
        .STAGES        ( STAGES ),
        .DATA_T        ( DATA_T ),
        .LATCH_DATA_IN ( LATCH_DATA_IN ),
        .RST_VALUE     ( RST_VALUE )
    ) i_sync_bus  (
        .clk_in   ( clk_in ),
        .rst_in   ( rst_in ),
        .req_in   ( req_in ),
        .data_in  ( data_in ),
        .clk_out  ( clk_out ),
        .rst_out  ( rst_out ),
        .req_out  ( ),
        .data_out ( data_out )
    );

endmodule : sync_bus_sampled
