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

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // signals.
    logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix;
    logic [0:RS_N-1] err_loc_vec;    

    // instantiate interfaces.
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) h_sel (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) acc   (.clk(clk));


    // instantiate H matrix selection block.
    rs_decode_h_select #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) rs_decode_h_select_0 (
        .clk                (clk),
        .srst               (srst),
        .err_loc            (err_loc),
        .data_in            (data_in),
        .h_matrix           (h_matrix),
        .err_loc_vec        (err_loc_vec),
        .data_out           (h_sel)
    );

    // instantiate RS accumulator block.
    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_K), .COL_LEN(COL_LEN)) rs_acc_0 (
        .clk                (clk),
        .srst               (srst),
        .coef_matrix        (h_matrix),
        .data_in            (h_sel),
        .data_out           (acc)
    );

    // instantiate zero pad deletion block.
    rs_acc_pad #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN), .MODE(DELETE)) rs_acc_pad_0 (
        .clk                (clk),
        .srst               (srst),
        .data_in            (acc),
        .data_out           (data_out)
    );

endmodule  // rs_acc_decode
