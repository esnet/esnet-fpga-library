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
    input  logic [0:RS_N-1] err_loc_vec,

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // derived parameters.
    localparam DATA_SYM_WID = DATA_WID / SYM_SIZE;
    localparam CLKS_PER_COL = COL_LEN / DATA_SYM_WID;  // CLKS_PER_COL >= 4 (PIPE_STAGES).
    localparam CLKS_PER_CW_BLK = CLKS_PER_COL * RS_N;

    // signals.
    logic [$clog2(CLKS_PER_CW_BLK)-1:0] index;  // word index within FEC block.  1 word = 'DATA_WID' bits.

    logic [$clog2(CLKS_PER_BLK)-1:0] blk_size;

    assign data_in.ready = data_out.ready;

    always_ff @(posedge clk)
        if (srst)
            index <= '0;
        else if (data_in.valid && data_in.ready)
            index <= (index == CLKS_PER_CW_BLK-1) ? 0 : index+1;

    always_ff @(posedge clk) if (index == 0) blk_size <= data_in.blk_size;

    assign data_out.valid    = data_in.valid && !err_loc_vec[index / CLKS_PER_COL];
    assign data_out.blk_size = index==0 ? data_in.blk_size : blk_size;
    assign data_out.data     = data_in.data;

endmodule  // rs_acc_err_inj
