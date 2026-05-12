module rs_acc_framer
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter rs_acc_framer_mode_t MODE = TX
) (
    input  logic clk,
    input  logic srst,
    input  logic [31:0] fec_evt_size,

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // derived parameters.
    localparam DATA_BYTE_WID = DATA_WID / 8;
    localparam CLKS_PER_BLK  = FEC_BLK_SIZE / DATA_BYTE_WID;
    localparam CLKS_PER_BIT  = CLKS_PER_BLK / (RS_K * SYM_SIZE);

    logic [31:0] index;  // word index within fec event.
    logic [31:0] fec_blk_num;
    logic [31:0] clks_per_evt;
    logic [31:0] num_fec_blks;  // number of FULL fec blks per evt (excludes LAST blk, if partial).
    logic [$clog2(RS_K*SYM_SIZE)-1:0] pad_frames;  // pad frames within last fec block.

    logic [19:0] last_blk_size;

    logic  last_fec_blk;
    assign last_fec_blk = (fec_blk_num == num_fec_blks);

    always_ff @(posedge clk) begin
        if (srst) begin
            index <= '0;
            fec_blk_num <= '0;
        end else begin
            if (data_in.valid && data_in.ready) begin
                if ((MODE == TX) && (index == clks_per_evt-1)) begin
                    index <= '0;
                    fec_blk_num <= '0;
                end else if ((MODE == RX) && (index >= clks_per_evt-1) &&
                             ((index % CLKS_PER_BLK) == CLKS_PER_BLK-1)) begin
                    index <= '0;
                    fec_blk_num <= '0;
                end else if ((index % CLKS_PER_BLK) == CLKS_PER_BLK-1) begin
                    index <= index+1;
                    fec_blk_num <= fec_blk_num+1;
                end else begin
                    index  <= index+1;
                end
            end
        end

        clks_per_evt  <= (fec_evt_size + DATA_BYTE_WID - 1) / DATA_BYTE_WID;  // round up.
        num_fec_blks  <= fec_evt_size / FEC_BLK_SIZE;  // number of FULL fec blocks per event.
        pad_frames    <= (CLKS_PER_BLK - (clks_per_evt % CLKS_PER_BLK)) / CLKS_PER_BIT;
        last_blk_size <= fec_evt_size % FEC_BLK_SIZE;
    end


    always_comb begin
        data_in.ready  = data_out.ready;

        data_out.valid = data_in.valid;
        data_out.data  = data_in.data;

        data_out.meta.parity       = 'x;                              // 0-data frame, 1-parity frame.
        data_out.meta.ec_frame_num = 'x;                              // 0-31 for parity=0, 0-7 for parity=1.
        data_out.meta.pad_frames   = last_fec_blk ? pad_frames : '0;  // pad frames within last fec blk of this evt.
        data_out.meta.ec_sgmt_size = COL_LEN/8;                       // fixed non-last segment size in bytes.
        data_out.meta.pad_bytes    = 'x;                              // pad bytes within this frame.
        data_out.meta.fec_blk_num  = fec_blk_num;                     // common for all fec blocks within this event.

        data_out.meta.eos          = 'x;
        data_out.meta.fec_blk_size = last_fec_blk ? last_blk_size : FEC_BLK_SIZE;
    end

endmodule  // rs_acc_framer
