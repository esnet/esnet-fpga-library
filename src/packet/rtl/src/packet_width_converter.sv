// Performs a width conversion
// If the output interface is larger than the input interface, perform an upsizing conversion.
// (pack the larger output interface from multiple input words).
// If the output interface is narrower than the input interface, perform a downsizing conversion.
// (unpack the larger input interface to multiple output words).
// NOTE: (for now at least) only integer multiples of output/input interface sizes are supported
module packet_width_converter #(
    parameter bit LATCH_METADATA_ON_SOP = 0 // When set, latch metadata (meta signal) only on SOP, ignore for all subsequent cycles
                                            // Default behaviour is to latch metadata on EOP
) (
    packet_intf.rx   from_tx,
    packet_intf.tx   to_rx
);
    // Typedefs
    typedef enum {
        DOWNSIZE,
        UPSIZE
    } conversion_type_t;

    // Parameters
    localparam int DATA_IN_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int DATA_OUT_BYTE_WID = to_rx.DATA_BYTE_WID;
    localparam int META_WID = from_tx.META_WID;
    localparam conversion_type_t CONVERSION_TYPE = DATA_OUT_BYTE_WID > DATA_IN_BYTE_WID ? UPSIZE : DOWNSIZE;
    localparam int CONVERT_RATIO = CONVERSION_TYPE == UPSIZE ? DATA_OUT_BYTE_WID / DATA_IN_BYTE_WID : DATA_IN_BYTE_WID / DATA_OUT_BYTE_WID;
    localparam int MTY_IN_WID = $clog2(DATA_IN_BYTE_WID);
    localparam int MTY_OUT_WID = $clog2(DATA_OUT_BYTE_WID);

    typedef logic[$clog2(CONVERT_RATIO+1)-1:0] conv_state_t;

    // Parameter checking
    initial begin
        if (CONVERSION_TYPE == UPSIZE)   std_pkg::param_check(DATA_OUT_BYTE_WID % DATA_IN_BYTE_WID,  0, "For upsize, output interface width must be integer multiple of input interface width.");
        if (CONVERSION_TYPE == DOWNSIZE) std_pkg::param_check(DATA_IN_BYTE_WID  % DATA_OUT_BYTE_WID, 0, "For downsize, input interface width must be integer multiple of output interface width.");
        std_pkg::param_check(to_rx.META_WID, from_tx.META_WID, "Metadata width must be the same on input and output interfaces.");
    end

    logic                eop;
    logic [META_WID-1:0] meta;
    logic                err;

    generate
        if (CONVERSION_TYPE == UPSIZE) begin : g__upsize
            logic [0:CONVERT_RATIO-1] valid;
            logic [0:CONVERT_RATIO-1][0:DATA_IN_BYTE_WID-1][7:0] data;

            logic [MTY_IN_WID-1:0] mty;
            conv_state_t pack_state;

            assign to_rx.vld = (pack_state == CONVERT_RATIO) || ((pack_state > 0) && eop);
            assign from_tx.rdy = to_rx.rdy || !to_rx.vld;

            // Pack (narrow) input words into (wide) output interface, starting from left (i.e, big-endian, network byte order)
            initial pack_state = '0;
            always @(posedge from_tx.clk) begin
                if (from_tx.srst) pack_state <= '0;
                else begin
                    if (to_rx.vld && to_rx.rdy) begin
                        if (from_tx.vld && from_tx.rdy) pack_state <= 1;
                        else pack_state <= 0;
                    end else if (from_tx.vld && from_tx.rdy) pack_state <= pack_state + 1;
                end
            end

            always_ff @(posedge from_tx.clk) begin
                if (to_rx.vld && to_rx.rdy) begin
                    data[1:CONVERT_RATIO-1] <= '0;
                    if (from_tx.vld && from_tx.rdy) begin
                        data[0] <= from_tx.data;
                    end
                end else if (from_tx.vld && from_tx.rdy) begin
                    data[pack_state] <= from_tx.data;
                end
            end

            always_ff @(posedge from_tx.clk) begin
                if (from_tx.vld && from_tx.rdy) begin
                    eop  <= from_tx.eop;
                    mty  <= from_tx.mty;
                end
            end

            assign to_rx.data = data;
            assign to_rx.eop = eop;
            assign to_rx.mty = DATA_OUT_BYTE_WID - pack_state*DATA_IN_BYTE_WID + mty;

        end : g__upsize
        if (CONVERSION_TYPE == DOWNSIZE) begin : g__downsize
            logic [0:CONVERT_RATIO-1] valid;
            logic [0:CONVERT_RATIO-1][0:DATA_OUT_BYTE_WID-1][7:0] data;
            logic [MTY_IN_WID-1:0] mty;

            assign to_rx.vld = valid[0];
            assign from_tx.rdy = !valid[0] || (!valid[1] && to_rx.rdy);

            // Unpack (narrow) words to output interface from (wide) input interface, starting from left (i.e, big-endian, network byte order)
            initial valid = '0;
            always @(posedge from_tx.clk) begin
                if (from_tx.srst) valid <= '0;
                else begin
                    if (from_tx.vld && from_tx.rdy) begin
                        for (int i = 0; i < CONVERT_RATIO; i++) begin
                            if (from_tx.mty < (DATA_IN_BYTE_WID - i*DATA_OUT_BYTE_WID)) valid[i] <= 1'b1;
                            else valid[i] <= 1'b0;
                        end
                    end
                    else if (to_rx.vld && to_rx.rdy) valid <= valid << 1;
                end
            end

            always_ff @(posedge from_tx.clk) begin
                if (from_tx.vld && from_tx.rdy) begin
                    data <= from_tx.data;
                end else if (to_rx.vld && to_rx.rdy) begin
                    data <= (data << (DATA_OUT_BYTE_WID*8));
                end
            end

            always_ff @(posedge from_tx.clk) begin
                if (from_tx.vld && from_tx.rdy) begin
                    eop  <= from_tx.eop;
                    mty  <= from_tx.mty;
                end
            end

            assign to_rx.data = data[0];
            assign to_rx.eop  = !valid[1] && eop;
            assign to_rx.mty  = mty % DATA_OUT_BYTE_WID;

        end : g__downsize
    endgenerate

    // Handle metadata (common to upsize/downsize operations)
    always_ff @(posedge from_tx.clk) begin
        if (from_tx.vld && from_tx.rdy) begin
            err  <= from_tx.err;
            if (LATCH_METADATA_ON_SOP) begin
                if (from_tx.sop) meta <= from_tx.meta;
            end else meta <= from_tx.meta;
        end
    end

    assign to_rx.err  = err;
    assign to_rx.meta = meta;

endmodule : packet_width_converter
