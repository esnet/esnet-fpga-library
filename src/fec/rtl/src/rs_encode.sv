module rs_encode
    import fec_pkg::*;
(
    input  logic clk,
    input  logic srst,

    input  logic [RS_K-1:0][SYM_SIZE-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [RS_K-1:0][SYM_SIZE-1:0] data_out,
    output logic [RS_2T-1:0][SYM_SIZE-1:0] parity_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    localparam PIPE_STAGES = 3;

    logic [PIPE_STAGES-1:0][RS_K-1:0][SYM_SIZE-1:0] data_in_pipe;
    logic [PIPE_STAGES-1:0]                         data_in_valid_pipe;

    logic [RS_2T-1:0][RS_K-1:0][SYM_SIZE-1:0] _prod, prod;
    logic [RS_2T-1:0][SYM_SIZE-1:0]           _parity, parity;

    // instantiate data pipeline.
    always @(posedge clk) begin
        data_in_pipe[0] <= data_in;
        data_in_valid_pipe[0] <= data_in_valid;

        for (int i=1; i<PIPE_STAGES; i++) begin
            data_in_pipe[i] <= data_in_pipe[i-1];
            data_in_valid_pipe[i] <= data_in_valid_pipe[i-1];
        end
    end


    // stage 0 - calculate partial products.
    always_comb
        for (int i=0; i<RS_2T; i++)
            for (int j=0; j<RS_K; j++) _prod[i][j] = gf_mul(data_in_pipe[0][j], RS_G_LUT[j][RS_K+i]);
   
    always @(posedge clk) prod <= _prod;


    // stage 1 - calculate parity (by summing partial products).
    always_comb
        for (int i=0; i<RS_2T; i++) begin
            _parity[i] = 0;
            for (int j=0; j<RS_K; j++) _parity[i] = gf_add(_parity[i], prod[i][j]);
        end

    always @(posedge clk) parity <= _parity;


    // stage 2 - output assignments.
    assign data_out_valid = data_in_valid_pipe[PIPE_STAGES-1];
    assign data_out = data_in_pipe[PIPE_STAGES-1];
    assign parity_out = parity;

    assign data_in_ready = data_out_ready;

endmodule;  // rs_encode
