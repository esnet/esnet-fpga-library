module rs_acc_pad
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_LEN  = 1024,
    parameter rs_acc_pad_mode_t MODE = INSERT
) (
    input  logic clk,
    input  logic srst,
    output logic [$clog2(DATA_WID/8):0] keep,

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // derived parameters.
    localparam CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID;
    localparam CLKS_PER_BIT = COL_LEN / DATA_WID;

    localparam DATA_BYTE_WID = DATA_WID/8;

    // signals.
    logic [$clog2(CLKS_PER_BLK)-1:0] index;
    logic [$clog2(CLKS_PER_BLK):0] blk_size; // in words.
    logic pad_en;

    fec_meta_t meta;


    assign blk_size = ( data_in.meta.fec_blk_size + (DATA_WID/8)-1 ) / (DATA_WID/8);  // in words (rounded up).

    always_ff @(posedge clk)
        if (srst) begin
            index  <= '0;
            pad_en <=  0;
        end else begin
            if (!pad_en) begin
                if (data_in.valid && data_in.ready) begin
                    if (index == CLKS_PER_BLK-1) begin
                        index  <= '0;
                    end else if (index == blk_size-1) begin
                        index  <= index+1;
                        pad_en <= 1;
                    end else begin
                        index  <= index+1;
                    end
                    meta <= (index == 0) ? data_in.meta : meta;
                end
            end else if (pad_en) begin
                if (data_out.ready) begin
                    if (index == CLKS_PER_BLK-1) begin
                        index  <= '0;
                        pad_en <= 0;
                    end else begin
                        index  <= index+1;
                    end
                end
            end	       
        end

    generate begin
        if (MODE == INSERT) begin
            always_comb begin
                data_in.ready  = pad_en ?   '0 : data_out.ready;
                data_out.valid = pad_en ?   '1 : data_in.valid;
                data_out.data  = pad_en ?   '0 : data_in.data;
                data_out.meta  = pad_en ? meta : data_in.meta;
                keep = DATA_BYTE_WID;
            end
        end else if (MODE == DELETE) begin
            always_comb begin
                data_in.ready  = pad_en ?   '1 : data_out.ready;
                data_out.valid = pad_en ?   '0 : data_in.valid;
                data_out.data  = pad_en ?   '0 : data_in.data;
                data_out.meta  = pad_en ? meta : data_in.meta;

                data_out.meta.eos = ((index % CLKS_PER_BIT) == CLKS_PER_BIT-1) | (index == blk_size-1);

                if (index != blk_size-1)
                    keep = DATA_BYTE_WID;
                else if (data_in.meta.fec_blk_size % DATA_BYTE_WID == 0)
                    keep = DATA_BYTE_WID;
                else
                    keep = data_in.meta.fec_blk_size % DATA_BYTE_WID;
            end
        end
    end endgenerate

endmodule  // rs_acc_pad
