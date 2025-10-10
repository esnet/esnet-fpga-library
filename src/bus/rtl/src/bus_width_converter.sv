// Performs a width conversion
// If the output interface is larger than the input interface, perform an upsizing conversion.
// (pack the larger output interface from multiple input words).
// If the output interface is narrower than the input interface, perform a downsizing conversion.
// (unpack the larger input interface to multiple output words).
// NOTE: (for now at least) only integer multiples of output/input interface sizes are supported
module bus_width_converter #(
    parameter bit BIGENDIAN = 1 // Pack/(unpack) first word into/(out of) MSbs of larger interface
) (
    input logic   srst,
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Typedefs
    typedef enum {
        DOWNSIZE,
        UPSIZE
    } conversion_type_t;

    // Parameters
    localparam int BUS_WIDTH_IN = from_tx.DATA_WID;
    localparam int BUS_WIDTH_OUT = to_rx.DATA_WID;
    localparam conversion_type_t CONVERSION_TYPE = BUS_WIDTH_OUT > BUS_WIDTH_IN ? UPSIZE : DOWNSIZE;
    localparam int CONVERT_RATIO = CONVERSION_TYPE == UPSIZE ? BUS_WIDTH_OUT / BUS_WIDTH_IN : BUS_WIDTH_IN / BUS_WIDTH_OUT;

    // Parameter checking
    initial begin
        if (CONVERSION_TYPE == UPSIZE)   std_pkg::param_check(BUS_WIDTH_OUT % BUS_WIDTH_IN,  0, "For upsize, output bus width must be integer multiple of input bus width.");
        if (CONVERSION_TYPE == DOWNSIZE) std_pkg::param_check(BUS_WIDTH_IN  % BUS_WIDTH_OUT, 0, "For downsize, input bus width must be integer multiple of output bus width.");
    end

    generate
        if (CONVERSION_TYPE == UPSIZE) begin : g__upsize
            logic [CONVERT_RATIO-1:0] valid;
            logic [CONVERT_RATIO-1:0][BUS_WIDTH_IN-1:0] data;

            assign to_rx.valid = valid[CONVERT_RATIO-1];
            assign from_tx.ready = to_rx.ready || !to_rx.valid;

            initial valid = '0;
            always @(posedge from_tx.clk) begin
                if (srst) valid <= '0;
                else begin
                    if (to_rx.valid && to_rx.ready) valid <= '0;
                    else if (from_tx.valid && from_tx.ready) valid <= (valid << 1);
                    if (from_tx.valid && from_tx.ready) valid[0] <= 1'b1;
                end
            end

            always_ff @(posedge from_tx.clk) begin
                if (from_tx.valid && from_tx.ready) data <= (data << BUS_WIDTH_IN) | from_tx.data;
            end

            if (BIGENDIAN) begin : g__big_endian
                assign to_rx.data = data;
            end : g__big_endian
            else begin : g__little_endian
                assign to_rx.data = {<<BUS_WIDTH_IN{data}};
            end : g__little_endian

        end : g__upsize
        if (CONVERSION_TYPE == DOWNSIZE) begin : g__downsize
            logic [CONVERT_RATIO-1:0] valid;
            logic [CONVERT_RATIO-1:0][BUS_WIDTH_OUT-1:0] data;
            logic [BUS_WIDTH_IN-1:0] data_in;

            assign to_rx.valid = valid[0];
            assign from_tx.ready = !valid[0] || (!valid[1] && to_rx.ready);

            initial valid = '0;
            always @(posedge from_tx.clk) begin
                if (srst) valid <= '0;
                else begin
                    if (from_tx.valid && from_tx.ready) valid <= '1;
                    else if (to_rx.valid && to_rx.ready) valid <= valid >> 1;
                end
            end

            if (BIGENDIAN) begin : g__big_endian
                assign data_in = {<<BUS_WIDTH_OUT{from_tx.data}};
            end : g__big_endian
            else begin : g__little_endian
                assign data_in = from_tx.data;
            end : g__little_endian

            always_ff @(posedge from_tx.clk) begin
                if (from_tx.valid && from_tx.ready) data <= data_in;
                else if (to_rx.valid && to_rx.ready) data <= (data >> BUS_WIDTH_OUT);
            end

            assign to_rx.data = data[0];

        end : g__downsize
    endgenerate

endmodule : bus_width_converter
