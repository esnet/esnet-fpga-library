module rs_acc_decode
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_LEN  = 1024,
    // Derived parameters (don't override)
    parameter int CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID
) (
    input  logic clk,
    input  logic srst,
    input  logic [$clog2(NUM_H)-1:0] err_loc,

    input  logic [DATA_WID-1:0] data_in,
    input  logic data_in_valid,
    input  logic [$clog2(CLKS_PER_BLK)-1:0] data_in_blk_size,
    output logic data_in_ready,

    output logic [DATA_WID-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    // instantiate H matrix selection block.
    logic [DATA_WID-1:0] h_sel_data_out;
    logic h_sel_data_valid;
    logic [$clog2(CLKS_PER_BLK)-1:0] h_sel_blk_size;
    logic h_sel_data_ready;

    logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix;
    logic [0:RS_N-1] err_loc_vec;    

    rs_decode_h_select #(
        .DATA_WID           (DATA_WID),
        .COL_LEN            (COL_LEN)
    ) rs_decode_h_select_0 (
        .clk                (clk),
        .srst               (srst),
        .err_loc            (err_loc),

        .data_in            (data_in),
        .data_in_valid      (data_in_valid),
        .data_in_blk_size   (data_in_blk_size),
        .data_in_ready      (data_in_ready),

        .h_matrix           (h_matrix),
        .err_loc_vec        (err_loc_vec),

        .data_out           (h_sel_data_out),
        .data_out_valid     (h_sel_data_valid),
        .data_out_blk_size  (h_sel_blk_size),
        .data_out_ready     (h_sel_data_ready)
    );


    // instantiate RS accumulator block.
    logic [DATA_WID-1:0] acc_data_out;
    logic acc_data_valid;
    logic [$clog2(CLKS_PER_BLK)-1:0] acc_blk_size;
    logic acc_data_ready;

    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_K), .COL_LEN(COL_LEN)) rs_acc_0 (
        .clk                (clk),
        .srst               (srst),
        .coef_matrix        (h_matrix),
        .data_in            (h_sel_data_out),
        .data_in_valid      (h_sel_data_valid),
        .data_in_blk_size   (h_sel_blk_size),
        .data_in_ready      (h_sel_data_ready),
        .data_out           (acc_data_out),
        .data_out_valid     (acc_data_valid),
        .data_out_blk_size  (acc_blk_size),
        .data_out_ready     (acc_data_ready)
    );

    rs_acc_pad #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN), .MODE(DELETE)) rs_acc_pad_0 (
        .clk                (clk),
        .srst               (srst),
        .data_in            (acc_data_out),
        .data_in_valid      (acc_data_valid),
        .data_in_blk_size   (acc_blk_size),
        .data_in_ready      (acc_data_ready),
        .data_out           (data_out),
        .data_out_valid     (data_out_valid),
        .data_out_ready     (data_out_ready)
    );

endmodule;  // rs_acc_decode
