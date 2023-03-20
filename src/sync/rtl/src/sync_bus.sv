module sync_bus #(
    parameter int      STAGES = 3,
    parameter type     DATA_T = logic,
    parameter bit      LATCH_DATA_IN = 1'b1,
    parameter DATA_T   RST_VALUE = {$bits(DATA_T){1'bx}}
) (
    // Input clock domain
    input  logic  clk_in,
    input  logic  rst_in,
    input  logic  req_in,
    input  DATA_T data_in,
    // Output clock domain
    input  logic  clk_out,
    input  logic  rst_out,
    output logic  req_out,
    output DATA_T data_out
);

    // Signals
    logic  _req_in;
    logic  _req_out;
    DATA_T _data_in;
    (* ASYNC_REG = "TRUE" *) DATA_T __sync_bus_ff_data;

    generate
        if (LATCH_DATA_IN) begin : g__latch_data_in
            // Optionally latch input data
            initial _data_in = RST_VALUE;
            always @(posedge clk_in) begin
                if (rst_in) _data_in <= RST_VALUE;
                else if (req_in) _data_in <= data_in;
            end

            // Delay input request to align with data
            initial _req_in = 1'b0;
            always @(posedge clk_in) begin
                if (rst_in) _req_in <= 1'b0;
                else        _req_in <= req_in;
            end
        end : g__latch_data_in
        else begin : g__data_in
            assign _req_in = req_in;
            assign _data_in = data_in;
        end : g__data_in
    endgenerate

    // Synchronize request pulse
    sync_pulse    #(
        .STAGES    ( STAGES )
    ) i_sync_pulse (
        .clk_in    ( clk_in ),
        .rst_in    ( rst_in ),
        .pulse_in  ( _req_in ),
        .clk_out   ( clk_out ),
        .rst_out   ( rst_out ),
        .pulse_out ( _req_out )
    );

    // Latch (stable) data
    initial __sync_bus_ff_data = RST_VALUE;
    always @(posedge clk_out) begin
        if (rst_out) __sync_bus_ff_data <= RST_VALUE;
        else begin
            if (_req_out) __sync_bus_ff_data <= _data_in;
        end
    end

    assign data_out = __sync_bus_ff_data;

    // Delay output request indication to align with data
    initial req_out = 1'b0;
    always @(posedge clk_out) begin
        if (rst_out) req_out <= 1'b0;
        else         req_out <= _req_out;
    end

endmodule : sync_bus
