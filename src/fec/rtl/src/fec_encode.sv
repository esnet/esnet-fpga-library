module fec_encode
    import fec_pkg::*;
#(
    parameter int DATA_BYTE_WID = 64,
    parameter int NUM_THREADS = 2  // # threads = # symbols per data unit e.g. 2 symbols per byte.
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_BYTE_WID/RS_K-1:0][RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_BYTE_WID/RS_K-1:0][RS_K -1:0][NUM_THREADS*SYM_SIZE-1:0] data_out,
    output logic [DATA_BYTE_WID/RS_K-1:0][RS_2T-1:0][NUM_THREADS*SYM_SIZE-1:0] parity_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    localparam int NUM_CW = DATA_BYTE_WID/RS_K;

    logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_K -1:0][SYM_SIZE-1:0] rse_data_in;
    logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_K -1:0][SYM_SIZE-1:0] rse_data_out;
    logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_2T-1:0][SYM_SIZE-1:0] rse_parity_out;


    // rearrange and organize encoder input and output data.
    always_comb begin
        for (int i = 0; i < NUM_CW; i++) begin
            for (int j = 0; j < NUM_THREADS; j++) begin
                for (int k = 0; k < RS_K; k++) rse_data_in[i][j][k] = data_in[i][k][j*SYM_SIZE +: SYM_SIZE];

                for (int k = 0; k < RS_K; k++)    data_out[i][k][j*SYM_SIZE +: SYM_SIZE] = rse_data_out  [i][j][k];
                for (int k = 0; k < RS_2T; k++) parity_out[i][k][j*SYM_SIZE +: SYM_SIZE] = rse_parity_out[i][j][k];
            end
        end
    end


    // instantiate 'rs_encode' blocks.
    generate
        for (genvar i = 0; i < NUM_CW; i++) begin : g__rse_cw
            for (genvar j = 0; j < NUM_THREADS; j++) begin : g__rse_thread

                logic _rse_data_in_ready;
                logic _rse_data_out_valid;

                if (i==0 && j==0) begin
                    assign data_in_ready  = _data_in_ready;
                    assign data_out_valid = _data_out_valid;
                end

                rs_encode rs_encode_inst (
                    .clk              (clk),
                    .srst             (srst),

                    .data_in          (rse_data_in[i][j]),
                    .data_in_valid    (data_in_valid),
                    .data_in_ready    (_data_in_ready),

                    .data_out         (rse_data_out[i][j]),
                    .parity_out       (rse_parity_out[i][j]),
                    .data_out_valid   (_data_out_valid),
                    .data_out_ready   (data_out_ready)
                );

            end : g__rse_thread
        end : g__rse_cw
    endgenerate

endmodule;  // fec_encode
