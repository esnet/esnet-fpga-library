import std_verif_pkg::*;
import fec_pkg::*;

class rs_model #(
    parameter int  NUM_THREADS = 2,  // # threads = # symbols per data unit e.g. 2 symbols per byte.
    parameter type TRANSACTION_IN_T  = raw_transaction#(logic [RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0]),
    parameter type TRANSACTION_OUT_T = raw_transaction#(logic [RS_N-1:0][NUM_THREADS*SYM_SIZE-1:0])
) extends model#(TRANSACTION_IN_T, TRANSACTION_OUT_T);

    local static const string __CLASS_NAME = "fec_verif_pkg::rs_model";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="rs_model");
        super.new(name);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Process input transaction
    // [[ implements std_verif_pkg::model._process() ]]
    protected task _process(input TRANSACTION_IN_T transaction_in);
        localparam DATA_WIDTH = $bits(transaction_in.data);
        localparam NUM_CW = DATA_WIDTH / (RS_K * NUM_THREADS * SYM_SIZE);

        TRANSACTION_OUT_T  transaction_out;

        logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_K -1:0][SYM_SIZE-1:0] data_in;
        logic [NUM_CW-1:0][NUM_THREADS-1:0][RS_2T-1:0][SYM_SIZE-1:0] rem;

        logic [NUM_CW-1:0][RS_2T-1:0][NUM_THREADS*SYM_SIZE-1:0] parity_out;
        logic [NUM_CW-1:0][RS_N -1:0][NUM_THREADS*SYM_SIZE-1:0] data_out;


        // rearrange and organize input data.
        for (int i=0; i<NUM_CW; i++) begin
            for (int j=0; j<NUM_THREADS; j++) begin
                for (int k=0; k<RS_K; k++) begin
                    data_in[i][j][k] = transaction_in.data[i*RS_K + k][j*SYM_SIZE +: SYM_SIZE];
                end
            end
        end

        // calculate all codewords.
        for (int i=0; i<NUM_CW; i++) begin
            for (int j=0; j<NUM_THREADS; j++) begin
                rem[i][j] = rs_encode(data_in[i][j]);
            end
        end

        // rearrange and organize output parity.
        for (int i=0; i<NUM_CW; i++) begin
            for (int j=0; j<NUM_THREADS; j++) begin
                for (int k=0; k<RS_2T; k++) begin
                    parity_out[i][k][j*SYM_SIZE +: SYM_SIZE] = rem[i][j][k];
                end
            end
        end

        data_out = { parity_out, transaction_in.data };

        transaction_out = new($sformatf("trans_%0d_out", num_output_transactions()), data_out);

        _enqueue(transaction_out);
    endtask


    // rs encoding function
    protected function [RS_2T-1:0][SYM_SIZE-1:0] rs_encode (input [RS_K-1:0][SYM_SIZE-1:0] data_in);
        logic [RS_N-1:0][SYM_SIZE-1:0] poly_a;
        logic [RS_N-1:0][SYM_SIZE-1:0] quot;
        int                            quot_len;
        logic [RS_N-1:0][SYM_SIZE-1:0] rem;
        int                            rem_len;

        poly_a = { {RS_2T{SYM_SIZE{1'b0}}}, data_in };

        poly_div (
            .poly_a      (poly_a),
            .poly_a_len  (RS_N),
            .poly_b      (RS_G_POLY),
            .poly_b_len  (RS_2T+1),
            .quot        (quot),
            .quot_len    (quot_len),
            .rem         (rem),
            .rem_len     (rem_len)
        );

        return rem[RS_2T-1:0];
    endfunction

endclass : rs_model
