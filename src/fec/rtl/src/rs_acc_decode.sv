module rs_acc_decode
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int NUM_COL  = RS_K,
    parameter int COL_LEN  = 1024
) (
    input  logic clk,
    input  logic srst,
    input  logic [$clog2(NUM_H)-1:0] err_loc,

    input  logic [DATA_WID-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_WID-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    // derived parameters.
    localparam DATA_SYM_WID = DATA_WID / SYM_SIZE;
    localparam CLKS_PER_COL = COL_LEN / DATA_SYM_WID;  // CLKS_PER_COL >= 4 (PIPE_STAGES).
    localparam CLKS_PER_BLK = CLKS_PER_COL * RS_K;

    // parameter validation.
    initial std_pkg::param_check_gt(CLKS_PER_COL, 4, "CLKS_PER_COL i.e. COL_LEN/(DATA_WID/SYM_SIZE) >= 4");


    // instantiate H matrix selection block.
    logic [DATA_WID-1:0] h_sel_data_out;
    logic h_sel_data_valid;
    logic h_sel_data_ready;

    logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix;
    logic [0:RS_N-1] err_loc_vec;    

    rs_decode_h_select #(
        .DATA_WID       (DATA_WID)
    ) rs_decode_h_select_0 (
        .clk            (clk),
        .srst           (srst),
        .err_loc        (err_loc),

        .data_in        (data_in),
        .data_in_valid  (data_in_valid),
        .data_in_ready  (data_in_ready),

        .h_matrix       (h_matrix),
        .err_loc_vec    (err_loc_vec),

        .data_out       (h_sel_data_out),
        .data_out_valid (h_sel_data_valid),
        .data_out_ready (h_sel_data_ready)
    );


    // instantiate RS accumulator block.
    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_K), .COL_LEN(COL_LEN)) rs_acc_0 (
        .clk              (clk),
        .srst             (srst),
        .coef_matrix      (h_matrix),
        .data_in          (h_sel_data_out),
        .data_in_valid    (h_sel_data_valid),
        .data_in_ready    (h_sel_data_ready),
        .data_out         (data_out),
        .data_out_valid   (data_out_valid),
        .data_out_ready   (data_out_ready)
    );

endmodule;  // rs_acc_decode
