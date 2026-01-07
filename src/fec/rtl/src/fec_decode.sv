module fec_decode
    import fec_pkg::*;
#(
    parameter int DATA_BYTE_WID = 64,
    parameter int NUM_THREADS = 2  // # threads = # symbols per data unit e.g. 2 symbols per byte.
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_BYTE_WID/RS_K-1:0][RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0] data_in,
    input  logic [$clog2(NUM_H)-1:0] err_loc,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_BYTE_WID/RS_K-1:0][RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    localparam int NUM_CW = DATA_BYTE_WID/RS_K;

    logic [DATA_BYTE_WID/RS_K-1:0][RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0] h_sel_data_out;
    logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix;
    logic [0:RS_N-1] err_loc_vec;

    logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_K-1:0][SYM_SIZE-1:0] rsd_data_in;
    logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_K-1:0][SYM_SIZE-1:0] rsd_data_out;

    logic rsd_data_in_valid;
    logic rsd_data_in_ready;


    // instantiate H matrix selection block.
    rs_decode_h_select #(
        .DATA_BYTE_WID  (DATA_BYTE_WID),
        .NUM_THREADS    (NUM_THREADS)
    ) rs_decode_h_select_0 (
        .clk            (clk),
        .srst           (srst),

        .data_in        (data_in),
        .err_loc        (err_loc),
        .data_in_valid  (data_in_valid),
        .data_in_ready  (data_in_ready),

        .data_out       (h_sel_data_out),
        .h_matrix       (h_matrix),
        .err_loc_vec    (err_loc_vec),
        .data_out_valid (rsd_data_in_valid),
        .data_out_ready (rsd_data_in_ready)
    );


    // rearrange and organize decoder input and output data.
    always_comb begin
        for (int i = 0; i < NUM_CW; i++) begin
            for (int j = 0; j < NUM_THREADS; j++) begin
                for (int k = 0; k < RS_K; k++) rsd_data_in[i][j][k] = h_sel_data_out[i][k][j*SYM_SIZE +: SYM_SIZE];
                for (int k = 0; k < RS_K; k++) data_out[i][k][j*SYM_SIZE +: SYM_SIZE] = rsd_data_out[i][j][k];
            end
        end
    end


    // instantiate 'rs_decode' blocks.
    generate
        for (genvar i = 0; i < NUM_CW; i++) begin : g__rsd_cw
            for (genvar j = 0; j < NUM_THREADS; j++) begin : g__rsd_thread

                logic _rsd_data_in_ready;
                logic _data_out_valid;

                if (i==0 && j==0) begin
                    assign rsd_data_in_ready = _rsd_data_in_ready;
                    assign data_out_valid = _data_out_valid;
                end

                rs_decode rs_decode_inst (
                    .clk              (clk),
                    .srst             (srst),

                    .data_in          (rsd_data_in[i][j]),
                    .h_matrix         (h_matrix),
                    .err_loc_vec      (err_loc_vec),
                    .data_in_valid    (rsd_data_in_valid),
                    .data_in_ready    (_rsd_data_in_ready),

                    .data_out         (rsd_data_out[i][j]),
                    .data_out_valid   (_data_out_valid),
                    .data_out_ready   (data_out_ready)
                );

            end : g__rsd_thread
        end : g__rsd_cw
    endgenerate

endmodule;  // fec_decode
