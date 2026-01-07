module rs_decode_h_select
    import fec_pkg::*;
#(
    parameter int DATA_BYTE_WID = RS_K,
    parameter int NUM_THREADS = 1  // # threads = # symbols per data unit e.g. 2 symbols per byte.
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_BYTE_WID/RS_K-1:0][RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0] data_in,
    input  logic [$clog2(NUM_H)-1:0] err_loc,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_BYTE_WID/RS_K-1:0][RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0] data_out,
    output logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix,
    output logic [0:RS_N-1] err_loc_vec,
    output logic data_out_valid,
    input  logic data_out_ready
);

    // pipeline data and select 'h_matrix' and 'err_loc_vec'.
    always @(posedge clk) begin
        data_out       <= data_in;
        data_out_valid <= data_in_valid;

        h_matrix       <= RS_H_LUT[err_loc];
        err_loc_vec    <= RS_ERR_LOC_LUT[err_loc];
    end

    assign data_in_ready = data_out_ready;

endmodule;  // rs_decode_h_select
