module rs_acc_pad
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_LEN  = 1024,
    parameter rs_acc_pad_mode_t MODE = INSERT,
    // Derived parameters (don't override)
    parameter int CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_WID-1:0] data_in,
    input  logic data_in_valid,
    input  logic [$clog2(CLKS_PER_BLK)-1:0] data_in_blk_size,
    output logic data_in_ready,

    output logic [DATA_WID-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    logic [$clog2(CLKS_PER_BLK)-1:0] index;
    logic pad_en;

    always_ff @(posedge clk)
        if (srst) begin
            index    <= '0;
            pad_en <=  0;
        end else begin
            if (!pad_en) begin
                if (data_in_valid && data_in_ready) begin
                    if (index == CLKS_PER_BLK-1) begin
                        index <= '0;
                    end else if (index == data_in_blk_size) begin
                        index <= index+1;
                        pad_en <= 1;
                    end else begin
                        index <= index+1;
                    end
                end
            end else if (pad_en) begin
                if (data_out_ready) begin
                    if (index == CLKS_PER_BLK-1) begin
                        index <= '0;
                        pad_en <= 0;
                    end else begin
                        index <= index+1;
                    end
                end
            end	       
        end

    generate begin
        if (MODE == INSERT) begin
            assign data_in_ready  = pad_en ? '0 : data_out_ready;
            assign data_out_valid = pad_en ? '1 : data_in_valid;
            assign data_out       = pad_en ? '0 : data_in;

        end else if (MODE == DELETE) begin
            assign data_in_ready  = pad_en ? '1 : data_out_ready;
            assign data_out_valid = pad_en ? '0 : data_in_valid;
            assign data_out       = pad_en ? '0 : data_in;

        end
    end endgenerate

endmodule;  // rs_acc_pad
