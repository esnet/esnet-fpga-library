module rs_acc_encode
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_LEN  = 1024
) (
    input  logic clk,
    input  logic srst,

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
    localparam CLKS_PER_BLK = CLKS_PER_COL * RS_N;

    // parameter validation.
    initial std_pkg::param_check_gt(CLKS_PER_COL, 4, "CLKS_PER_COL i.e. COL_LEN/(DATA_WID/SYM_SIZE) >= 4");

    logic [DATA_WID-1:0] parity_data;
    logic parity_valid;
    logic parity_ready;

    logic [$clog2(CLKS_PER_BLK)-1:0] index;
    logic buf_sel;

    logic  _data_in_valid,  _data_in_ready;
    assign _data_in_valid =  data_in_valid && data_out_ready && !buf_sel;
    assign  data_in_ready = _data_in_ready && data_out_ready && !buf_sel;

    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_2T), .COL_LEN(COL_LEN)) rs_acc (
        .clk              (clk),
        .srst             (srst),
        .coef_matrix      (RS_P_LUT),
        .data_in          (data_in),
        .data_in_valid    (_data_in_valid),
        .data_in_ready    (_data_in_ready),
        .data_out         (parity_data),
        .data_out_valid   (parity_valid),
        .data_out_ready   (parity_ready)
    );

    always_ff @(posedge clk)
        if (srst) begin
            index   <= '0;
            buf_sel <=  0;
        end else if (data_out_valid && data_out_ready) begin
            if (index == CLKS_PER_BLK-1) begin
                index   <= '0;
                buf_sel <= 0;
            end else if (index == CLKS_PER_COL*RS_K-1) begin
                index   <= index+1;
                buf_sel <= 1;
            end else
                index   <= index+1;
        end

    assign parity_ready   = data_out_ready;

    assign data_out       = buf_sel ? parity_data  : data_in;
    assign data_out_valid = buf_sel ? parity_valid : data_in_valid;

endmodule;  // rs_acc_encode
