module rs_decode_h_select
    import fec_pkg::*;
#(
    parameter int DATA_WID = RS_K*SYM_SIZE,
    parameter int COL_LEN = 0,
    // Derived parameters (don't override)
    parameter int CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID
) (
    input  logic clk,
    input  logic srst,
    input  logic [$clog2(NUM_H)-1:0] err_loc,

    rs_acc_intf.rx  data_in,

    output logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix,
    output logic [0:RS_N-1] err_loc_vec,

    rs_acc_intf.tx  data_out
);

    // pipeline data and select 'h_matrix' and 'err_loc_vec'.
    always_ff @(posedge clk) if (data_out.ready) begin
        data_out.data  <= data_in.data;
        data_out.valid <= data_in.valid;
        data_out.meta  <= data_in.meta;

        h_matrix     <= RS_H_LUT[err_loc];
        err_loc_vec  <= RS_ERR_LOC_LUT[err_loc];
    end

    assign data_in.ready = data_out.ready;

endmodule  // rs_decode_h_select
