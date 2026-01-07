module rs_decode
    import fec_pkg::*;
(
    input  logic clk,
    input  logic srst,

    input  logic [RS_K-1:0][SYM_SIZE-1:0] data_in,
    input  logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix,
    input  logic [0:RS_N-1] err_loc_vec,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [RS_K-1:0][SYM_SIZE-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    localparam PIPE_STAGES = 2;

    logic [PIPE_STAGES-1:0][RS_K-1:0][SYM_SIZE-1:0] data_in_pipe;
    logic [PIPE_STAGES-1:0][0:RS_N-1] err_loc_vec_pipe;
    logic [PIPE_STAGES-1:0] data_in_valid_pipe;

    logic [RS_K-1:0][RS_K-1:0][SYM_SIZE-1:0] _prod, prod;
    logic [RS_K-1:0][SYM_SIZE-1:0] _sum, sum;
    logic [RS_K-1:0][SYM_SIZE-1:0] _data_out;

    logic [RS_K-1:0][$clog2(RS_K):0] _errors, errors;


    // instantiate data pipeline.
    always @(posedge clk) begin
        data_in_pipe[0]        <= data_in;
        data_in_valid_pipe[0]  <= data_in_valid;
        err_loc_vec_pipe[0]    <= err_loc_vec;

        for (int i=1; i<PIPE_STAGES; i++) begin
            data_in_pipe[i]        <= data_in_pipe[i-1];
            data_in_valid_pipe[i]  <= data_in_valid_pipe[i-1];
            err_loc_vec_pipe[i]    <= err_loc_vec_pipe[i-1];
        end
    end


    // stage 0 - calculate partial products.
    always_comb begin
        _prod = '0;
        for (int i=0; i<RS_K; i++) if (err_loc_vec[i]==1'b1) begin
            for (int k=0; k<RS_K; k++) _prod[i][k] = gf_mul(data_in[k], h_matrix[i][k]);
        end
    end

    always @(posedge clk) prod <= _prod;


    // stage 1 - accumulate partial products.
    always_comb begin
        _sum = '0;
        for (int i=0; i<RS_K; i++) if (err_loc_vec_pipe[0][i]==1'b1) begin
            for (int k=0; k<RS_K; k++) _sum[i] = gf_add(_sum[i], prod[i][k]);
        end
    end

    // stage 1 - accumulate error count (from least to most significant codeword symbol).
    always_comb begin
        _errors = '0;
        _errors[0] = (err_loc_vec_pipe[0][0]==1'b1) ? 1 : 0;
        for (int i=1; i<RS_K; i++) begin
            if (err_loc_vec_pipe[0][i]==1'b1) _errors[i] = _errors[i-1]+1;
            else                              _errors[i] = _errors[i-1];
        end
    end

    always @(posedge clk) begin 
        sum <= _sum;
        errors <= _errors;
    end


    // stage 2 - replace errored data (with correction sums) and pass-through errorless data.
    always_comb begin
        for (int i=0; i<RS_K; i++) begin
            if (err_loc_vec_pipe[1][i]==1'b1) begin
                _data_out[i] = sum[i];
            end else
                _data_out[i] = data_in_pipe[1][i-errors[i]];
        end
    end


    // output assignments.
    always @(posedge clk) begin
        data_out <= _data_out;
        data_out_valid <= data_in_valid_pipe[1];
    end

    assign data_in_ready = data_out_ready;

endmodule;  // rs_decode
