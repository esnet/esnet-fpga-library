module rs_acc_encode
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_LEN  = 1024,
    // Derived parameters (don't override)
    parameter int CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID
) (
    input  logic clk,
    input  logic srst,

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // derived parameters.
    localparam CLKS_PER_CW_BLK = CLKS_PER_BLK * RS_N / RS_K;
    localparam CLKS_PER_COL = CLKS_PER_BLK / RS_K;

    // signals.
    logic [$clog2(CLKS_PER_CW_BLK)-1:0] index;
    logic parity_sel;

    logic [6:0] data_col_num, prty_col_num;

    // instantiate interfaces.
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) pad (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) pad_out (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) parity  (.clk(clk));


    rs_acc_pad #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN), .MODE(INSERT)) rs_acc_pad_0 (
        .clk              (clk),
        .srst             (srst),
        .data_in          (data_in),
        .data_out         (pad)
    );

    assign pad.ready = pad_out.ready && data_out.ready && !parity_sel;

    assign pad_out.data  = pad.data;
    assign pad_out.valid = pad.valid && data_out.ready && !parity_sel;
    assign pad_out.meta  = pad.meta;

    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_2T), .COL_LEN(COL_LEN)) rs_acc (
        .clk              (clk),
        .srst             (srst),
        .coef_matrix      (RS_P_LUT),
        .data_in          (pad_out),
        .data_out         (parity)
    );

    always_ff @(posedge clk)
        if (srst) begin
            index <= '0;
            parity_sel <=  0;
        end else if (data_out.valid && data_out.ready) begin
            if (index == CLKS_PER_CW_BLK-1) begin
                index <= '0;
                parity_sel <= 0;
            end else if (index == CLKS_PER_BLK-1) begin
                index <= index+1;
                parity_sel <= 1;
            end else
                index <= index+1;
        end

    always_comb begin
        parity.ready = data_out.ready;

        data_out.data  = parity_sel ? parity.data  : pad.data;
        data_out.valid = parity_sel ? parity.valid : pad.valid;
        data_out.meta  = parity_sel ? parity.meta  : pad.meta;

        data_out.meta.parity = parity_sel ? '1 : '0;

        data_col_num = index / CLKS_PER_COL;
        prty_col_num = data_col_num - RS_K;

        data_out.meta.ec_frame_num[6:$clog2(SYM_SIZE)] = parity_sel ? prty_col_num : data_col_num;
    end

endmodule  // rs_acc_encode
