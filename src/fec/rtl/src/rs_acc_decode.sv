module rs_acc_decode
    import fec_pkg::*;
#(
    parameter int   DATA_WID = 512,
    parameter logic DELETE_PAD_BYTES = 0
) (
    input  logic clk,
    input  logic srst,
    input  logic [$clog2(NUM_H)-1:0] err_loc,

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // signals.
    logic [0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] h_matrix;
    logic [0:RS_N-1] err_loc_vec;    

    // instantiate interfaces.
    rs_acc_intf #(.DATA_WID(DATA_WID)) h_sel (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID)) acc   (.clk(clk));


    // instantiate H matrix selection block.
    rs_decode_h_select #(.DATA_WID(DATA_WID)) rs_decode_h_select_0 (
        .clk                (clk),
        .srst               (srst),
        .err_loc            (err_loc),
        .data_in            (data_in),
        .h_matrix           (h_matrix),
        .err_loc_vec        (err_loc_vec),
        .data_out           (h_sel)
    );

    // instantiate RS accumulator block.
    rs_acc #(.DATA_WID(DATA_WID), .NUM_COL(RS_K)) rs_acc_0 (
        .clk                (clk),
        .srst               (srst),
        .coef_matrix        (h_matrix),
        .data_in            (h_sel),
        .data_out           (acc)
    );

    generate begin
        if (DELETE_PAD_BYTES) begin
            // instantiate zero pad deletion block.
            rs_acc_pad #(.DATA_WID(DATA_WID), .MODE(DELETE)) rs_acc_pad_0 (
                .clk                (clk),
                .srst               (srst),
                .data_in            (acc),
                .data_out           (data_out)
            );

        end else begin
            assign acc.ready = data_out.ready;

            assign data_out.data  = acc.data;
            assign data_out.valid = acc.valid;
            assign data_out.meta  = acc.meta;
        end
    end endgenerate
endmodule  // rs_acc_decode
