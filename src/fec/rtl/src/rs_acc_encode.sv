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

    input  logic [DATA_WID-1:0] data_in,
    input  logic data_in_valid,
    input  logic [$clog2(CLKS_PER_BLK)-1:0] data_in_blk_size,
    output logic data_in_ready,

    output logic [DATA_WID-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    // derived parameters.
    localparam CLKS_PER_CW_BLK = CLKS_PER_BLK * RS_N / RS_K;

    logic [DATA_WID-1:0] pad_data;
    logic pad_valid;
    logic pad_ready;

    logic [DATA_WID-1:0] parity_data;
    logic parity_valid;
    logic parity_ready;

    logic [$clog2(CLKS_PER_CW_BLK)-1:0] index;
    logic parity_sel;

//    logic  _data_in_valid,  _data_in_ready;
//    assign _data_in_valid =  data_in_valid && data_out_ready && !parity_sel;
//    assign  data_in_ready = _data_in_ready && data_out_ready && !parity_sel;

    rs_acc_pad #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN), .MODE(INSERT)) rs_acc_pad_0 (
        .clk              (clk),
        .srst             (srst),
        .data_in          (data_in),
//        .data_in_valid    (_data_in_valid),
//        .data_in_ready    (_data_in_ready),
        .data_in_valid    (data_in_valid),
        .data_in_ready    (data_in_ready),
        .data_in_blk_size (data_in_blk_size),
        .data_out         (pad_data),
        .data_out_valid   (pad_valid),
        .data_out_ready   (pad_ready)
    );

    logic  _pad_valid,  _pad_ready;
    assign _pad_valid =  pad_valid && data_out_ready && !parity_sel;
    assign  pad_ready = _pad_ready && data_out_ready && !parity_sel;

    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_2T), .COL_LEN(COL_LEN)) rs_acc (
        .clk              (clk),
        .srst             (srst),
        .coef_matrix      (RS_P_LUT),
        .data_in          (pad_data),
//        .data_in_valid    (pad_valid),
//        .data_in_ready    (pad_ready),
        .data_in_valid    (_pad_valid),
        .data_in_ready    (_pad_ready),
        .data_out         (parity_data),
        .data_out_valid   (parity_valid),
        .data_out_ready   (parity_ready)
    );

    always_ff @(posedge clk)
        if (srst) begin
            index <= '0;
            parity_sel <=  0;
        end else if (data_out_valid && data_out_ready) begin
            if (index == CLKS_PER_CW_BLK-1) begin
                index <= '0;
                parity_sel <= 0;
            end else if (index == CLKS_PER_BLK-1) begin
                index <= index+1;
                parity_sel <= 1;
            end else
                index <= index+1;
        end

    assign parity_ready = data_out_ready;

//    assign data_out       = parity_sel ? parity_data  : data_in;
//    assign data_out_valid = parity_sel ? parity_valid : data_in_valid;
    assign data_out       = parity_sel ? parity_data  : pad_data;
    assign data_out_valid = parity_sel ? parity_valid : pad_valid;

endmodule;  // rs_acc_encode
