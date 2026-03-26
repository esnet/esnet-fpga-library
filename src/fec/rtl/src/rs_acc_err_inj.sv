module rs_acc_err_inj
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

    input  logic [0:RS_N-1] err_loc_vec,

    output logic [DATA_WID-1:0] data_out,
    output logic data_out_valid,
    output logic [$clog2(CLKS_PER_BLK)-1:0] data_out_blk_size,
    input  logic data_out_ready
);

    // derived parameters.
    localparam DATA_SYM_WID = DATA_WID / SYM_SIZE;
    localparam CLKS_PER_COL = COL_LEN / DATA_SYM_WID;  // CLKS_PER_COL >= 4 (PIPE_STAGES).
    localparam CLKS_PER_CW_BLK = CLKS_PER_COL * RS_N;

    // signals.
    logic [$clog2(CLKS_PER_CW_BLK)-1:0] index;  // word index within FEC block.  1 word = 'DATA_WID' bits.

    logic [$clog2(CLKS_PER_BLK)-1:0] blk_size;

    assign data_in_ready = data_out_ready;

    always_ff @(posedge clk)
        if (srst)
            index <= '0;
        else if (data_in_valid && data_in_ready)
            index <= (index == CLKS_PER_CW_BLK-1) ? 0 : index+1;

    always_ff @(posedge clk) if (index == 0) blk_size <= data_in_blk_size;

    assign data_out_valid    = data_in_valid && !err_loc_vec[index / CLKS_PER_COL];
    assign data_out_blk_size = index==0 ? data_in_blk_size : blk_size;
    assign data_out          = data_in;

endmodule;  // rs_acc_err_inj
