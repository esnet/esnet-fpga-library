module fec_err_inject
    import fec_pkg::*;
#(
    parameter int DATA_BYTE_WID = 64,
    parameter int NUM_THREADS = 2  // # threads = # symbols per data unit e.g. 2 symbols per byte.
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_BYTE_WID/RS_K-1:0][RS_K -1:0][NUM_THREADS*SYM_SIZE-1:0] data_in,
    input  logic [DATA_BYTE_WID/RS_K-1:0][RS_2T-1:0][NUM_THREADS*SYM_SIZE-1:0] parity_in,
    input  logic [$clog2(NUM_H)-1:0] err_loc_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_BYTE_WID/RS_K-1:0][RS_K -1:0][NUM_THREADS*SYM_SIZE-1:0] data_out,
    output logic [$clog2(NUM_H)-1:0] err_loc_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    localparam int PIPE_STAGES = 2;
    localparam int NUM_CW = DATA_BYTE_WID/RS_K;

    logic [NUM_CW-1:0][RS_N-1:0][NUM_THREADS*SYM_SIZE-1:0] _data_in;
    logic [NUM_CW-1:0][RS_N-1:0][NUM_THREADS*SYM_SIZE-1:0]  data_pipe [PIPE_STAGES];

    logic [$clog2(NUM_H)-1:0] err_loc_pipe [PIPE_STAGES];
    logic                     valid_pipe [PIPE_STAGES];

    logic [0:RS_N-1] err_loc_vec;

    logic [RS_N-1:0][$clog2(RS_N)-1:0] _out_idx, out_idx;
    logic           [$clog2(RS_N)-1:0] count;


    assign data_in_ready = data_out_ready;

    // combine input data.
    always_comb
        for (int i=0; i<NUM_CW; i++)
            for (int j=0; j<RS_N; j++)
                if (j < RS_K) _data_in[i][j] = data_in[i][j];
                else          _data_in[i][j] = parity_in[i][j-RS_K];

    // pipeline stage 1 - capture input data and select 'err_loc_vec'.
    always @(posedge clk) if (data_out_ready) begin
        data_pipe[1]     <= _data_in;
        valid_pipe[1]    <= data_in_valid;
        err_loc_pipe[1]  <= err_loc_in;

        err_loc_vec <= RS_ERR_LOC_LUT[err_loc_in];
    end

    // calculate output indices (to skip erasure symbols and compress output data).
    always_comb begin
        count = 0;
        for (int i=0; i<RS_N; i++)
            if (err_loc_vec[i] == 1'b0) begin
                _out_idx[i] = count;
                count++;
            end else _out_idx[i] = RS_N-1;
    end

    // pipeline stage 2 - advance pipeline and capture output indices.
    always @(posedge clk) if (data_out_ready) begin
        data_pipe[0]     <= data_pipe[1];
        valid_pipe[0]    <= valid_pipe[1];
        err_loc_pipe[0]  <= err_loc_pipe[1];

        out_idx <= _out_idx;
    end

    // output stage - capture compressed output data, plus valid and loc_out assignments.
    always @(posedge clk) if (data_out_ready) begin
        for (int i=0; i<NUM_CW; i++)
            for (int j=0; j<RS_N; j++)
                data_out[i][out_idx[j]] <= data_pipe[0][i][j];

        data_out_valid <= valid_pipe[0];
        err_loc_out   <= err_loc_pipe[0];
    end

endmodule;  // fec_err_inject
