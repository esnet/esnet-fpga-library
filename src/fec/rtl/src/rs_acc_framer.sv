module rs_acc_framer
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_LEN  = 1024,
    parameter rs_acc_framer_mode_t MODE = TX,
    // Derived parameters (don't override)
    parameter int CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID
) (
    input  logic clk,
    input  logic srst,
    input  logic [31:0] fec_evt_size,

    rs_acc_intf.rx  data_in,
    rs_acc_intf.tx  data_out
);

    // derived parameters.
    localparam DATA_BYTE_WID = DATA_WID / 8;
    localparam CLKS_PER_BIT  = CLKS_PER_BLK / (RS_K * SYM_SIZE);

    logic [31:0] index;        // word index within fec event.
    logic [31:0] fec_blk_num;
    logic [31:0] clks_per_evt;
    logic [31:0] num_fec_blks; // number of FULL fec blks per evt (excludes LAST blk, if partial).
    logic  [6:0] pad_frames;   // pad frames within last fec block.

    logic [$clog2(CLKS_PER_BLK)-1:0] blk_size;

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

        clks_per_evt <= fec_evt_size / DATA_BYTE_WID;
        num_fec_blks <= clks_per_evt / CLKS_PER_BLK;      // number of FULL fec blocks per event.
        pad_frames   <= (CLKS_PER_BLK - (clks_per_evt % CLKS_PER_BLK)) / CLKS_PER_BIT;
        blk_size     <= (clks_per_evt % CLKS_PER_BLK)-1;  // TODO: adjust calculation when adding igr bit-slicing logic.
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
        data_out.meta.fec_blk_size = last_fec_blk ? blk_size : CLKS_PER_BLK-1;
    end

endmodule  // rs_acc_framer
