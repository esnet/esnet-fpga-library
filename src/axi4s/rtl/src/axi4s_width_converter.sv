// Performs a width conversion
// If the output interface is larger than the input interface, perform an upsizing conversion.
// (pack the larger output interface from multiple input words).
// If the output interface is narrower than the input interface, perform a downsizing conversion.
// (unpack the larger input interface to multiple output words).
// NOTE: (for now at least) only integer multiples of output/input interface sizes are supported
module axi4s_width_converter #(
    parameter bit LATCH_METADATA_ON_SOP = 0 // When set, latch metadata (tid/tdest/tuser signals) only on SOP, ignore for all subsequent cycles
                                            // Default behaviour is to latch metadata on EOP
) (
    axi4s_intf.rx   from_tx,
    axi4s_intf.tx   to_rx
);
    // Typedefs
    typedef enum {
        DOWNSIZE,
        UPSIZE
    } conversion_type_t;

    // Parameters
    localparam int DATA_IN_BYTE_WID = from_tx.DATA_BYTE_WID;
    localparam int DATA_OUT_BYTE_WID = to_rx.DATA_BYTE_WID;
    localparam type TID_T = from_tx.TID_T;
    localparam type TDEST_T = from_tx.TDEST_T;
    localparam type TUSER_T = from_tx.TUSER_T;
    localparam conversion_type_t CONVERSION_TYPE = DATA_OUT_BYTE_WID > DATA_IN_BYTE_WID ? UPSIZE : DOWNSIZE;
    localparam int CONVERT_RATIO = CONVERSION_TYPE == UPSIZE ? DATA_OUT_BYTE_WID / DATA_IN_BYTE_WID : DATA_IN_BYTE_WID / DATA_OUT_BYTE_WID;

    typedef logic[$clog2(CONVERT_RATIO+1)-1:0] conv_state_t;

    // Parameter checking
    initial begin
        if (CONVERSION_TYPE == UPSIZE)   std_pkg::param_check(DATA_OUT_BYTE_WID % DATA_IN_BYTE_WID,  0, "For upsize, output interface width must be integer multiple of input interface width.");
        if (CONVERSION_TYPE == DOWNSIZE) std_pkg::param_check(DATA_IN_BYTE_WID  % DATA_OUT_BYTE_WID, 0, "For downsize, input interface width must be integer multiple of output interface width.");
        std_pkg::param_check($bits(to_rx.TID_T),$bits(from_tx.TID_T), "TID width must be the same on input and output interfaces.");
        std_pkg::param_check($bits(to_rx.TDEST_T),$bits(from_tx.TDEST_T), "TDEST width must be the same on input and output interfaces.");
        std_pkg::param_check($bits(to_rx.TUSER_T),$bits(from_tx.TUSER_T), "TUSER width must be the same on input and output interfaces.");
    end

    TID_T   tid;
    TDEST_T tdest;
    TUSER_T tuser;

    assign to_rx.aclk = from_tx.aclk;
    assign to_rx.aresetn = from_tx.aresetn;

    generate
        if (CONVERSION_TYPE == UPSIZE) begin : g__upsize
            logic [CONVERT_RATIO-1:0] valid;
            logic [CONVERT_RATIO-1:0][DATA_IN_BYTE_WID-1:0][7:0] tdata;
            logic [CONVERT_RATIO-1:0][DATA_IN_BYTE_WID-1:0] tkeep;
            logic tlast;
            conv_state_t pack_state;

            assign to_rx.tvalid = (pack_state == CONVERT_RATIO) || ((pack_state > 0) && tlast);
            assign from_tx.tready = to_rx.tready || !to_rx.tvalid;

            // Pack (narrow) input words into (wide) output interface, starting from left (i.e, little-endian, AXI-S byte order)
            initial pack_state = '0;
            always @(posedge from_tx.aclk) begin
                if (!from_tx.aresetn) pack_state <= '0;
                else begin
                    if (to_rx.tvalid && to_rx.tready) begin
                        if (from_tx.tvalid && from_tx.tready) pack_state <= 1;
                        else pack_state <= 0;
                    end else if (from_tx.tvalid && from_tx.tready) pack_state <= pack_state + 1;
                end
            end

            always_ff @(posedge from_tx.aclk) begin
                if (to_rx.tvalid && to_rx.tready) begin
                    tdata[CONVERT_RATIO-1:1] <= '0;
                    tkeep[CONVERT_RATIO-1:1] <= '0;
                    if (from_tx.tvalid && from_tx.tready) begin
                        tdata[0] <= from_tx.tdata;
                        tkeep[0] <= from_tx.tkeep;
                    end
                end else if (from_tx.tvalid && from_tx.tready) begin
                    tdata[pack_state] <= from_tx.tdata;
                    tkeep[pack_state] <= from_tx.tkeep;
                end
            end

            always_ff @(posedge from_tx.aclk) begin
                if (from_tx.tvalid && from_tx.tready) tlast <= from_tx.tlast;
            end

            assign to_rx.tdata = tdata;
            assign to_rx.tkeep = tkeep;
            assign to_rx.tlast = tlast;

        end : g__upsize
        if (CONVERSION_TYPE == DOWNSIZE) begin : g__downsize
            logic [CONVERT_RATIO-1:0] valid;
            logic [CONVERT_RATIO-1:0][DATA_OUT_BYTE_WID-1:0][7:0] tdata;
            logic [CONVERT_RATIO-1:0][DATA_OUT_BYTE_WID-1:0] tkeep;
            logic [DATA_IN_BYTE_WID-1:0] tkeep_in;
            logic tlast;

            assign to_rx.tvalid = valid[0];
            assign from_tx.tready = !valid[0] || (!valid[1] && to_rx.tready);

            // Unpack (narrow) words to output interface from (wide) input interface, starting from right (i.e, little-endian, AXI-S byte order)
            initial valid = '0;
            always @(posedge from_tx.aclk) begin
                if (!from_tx.aresetn) valid <= '0;
                else begin
                    if (from_tx.tvalid && from_tx.tready) begin
                        for (int i = 0; i < CONVERT_RATIO; i++) begin
                            if (tkeep_in[i*DATA_OUT_BYTE_WID]) valid[i] <= 1'b1;
                            else valid[i] <= 1'b0;
                        end
                    end
                    else if (to_rx.tvalid && to_rx.tready) valid <= valid >> 1;
                end
            end

            assign tkeep_in = from_tx.tkeep;

            always_ff @(posedge from_tx.aclk) begin
                if (from_tx.tvalid && from_tx.tready) begin
                    tdata <= from_tx.tdata;
                    tkeep <= tkeep_in;
                end else if (to_rx.tvalid && to_rx.tready) begin
                    tdata <= (tdata >> (DATA_OUT_BYTE_WID*8));
                    tkeep <= (tkeep >> DATA_OUT_BYTE_WID);
                end
            end

            always_ff @(posedge from_tx.aclk) begin
                if (from_tx.tvalid && from_tx.tready) tlast <= from_tx.tlast;
            end

            assign to_rx.tdata = tdata[0];
            assign to_rx.tlast = !valid[1] && tlast;
            assign to_rx.tkeep = tkeep[0];

        end : g__downsize
    endgenerate

    // Handle metadata (common to upsize/downsize operations)
    always_ff @(posedge from_tx.aclk) begin
        if (from_tx.tvalid && from_tx.tready) begin
            if (LATCH_METADATA_ON_SOP) begin
                if (from_tx.sop) begin
                    tid <= from_tx.tid;
                    tdest <= from_tx.tdest;
                    tuser <= from_tx.tuser;
                end
            end else begin
                tid <= from_tx.tid;
                tdest <= from_tx.tdest;
                tuser <= from_tx.tuser;
            end
        end
    end

    assign to_rx.tid = tid;
    assign to_rx.tdest = tdest;
    assign to_rx.tuser = tuser;

endmodule : axi4s_width_converter
