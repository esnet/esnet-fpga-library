module fec_col_buf
    import fec_pkg::*;
#(
    parameter int NUM_BUFS = 2  // double buffer implementation for concurrent streaming and processing.
) (
    input  logic clk,
    input  logic srst,

    mem_wr_intf.peripheral buf_wr_if [NUM_BUFS],
    mem_rd_intf.peripheral buf_rd_if [NUM_BUFS]
);
    import mem_pkg::*;
   
    // -------------------------------------------------------------------------
    // memory organization (per buffer):
    // 4 memory banks.  512 words × 128 bits per bank.
    // -------------------------------------------------------------------------
    localparam int NUM_BANKS = 4;
    localparam int BANK_ADDR_WID = 9;
    localparam int BANK_DATA_WID = 128;

    // memory interfaces for NUM_BANKS banks × 2 NUM_BUFS buffers/bank.
    mem_wr_intf #(
        .ADDR_WID(BANK_ADDR_WID),
        .DATA_WID(BANK_DATA_WID)
    ) mem_wr_if [NUM_BANKS-1:0][NUM_BUFS-1:0] (
        .clk(clk)
    );

    mem_rd_intf #(
        .ADDR_WID(BANK_ADDR_WID),
        .DATA_WID(BANK_DATA_WID)
    ) mem_rd_if [NUM_BANKS-1:0][NUM_BUFS-1:0] (
        .clk(clk)
    );

    // instantiate RAM instances.
    generate
        for (genvar bank = 0; bank < NUM_BANKS; bank++) begin : g_bank
            for (genvar _buf = 0; _buf < NUM_BUFS; _buf++) begin : g_buf
                    // instantiate memory bank buffer.
                    fec_bank_buf #(.NUM_BUFS(NUM_BUFS)) fec_bank_buf_inst (
                        .clk        (clk),
                        .srst       (srst),
                        .buf_wr_if  (mem_wr_if[bank]),
                        .buf_rd_if  (mem_rd_if[bank])
                    );

                    // wr control signals.
                    assign mem_wr_if[bank][_buf].rst  = buf_wr_if[_buf].rst;
                    assign mem_wr_if[bank][_buf].en   = buf_wr_if[_buf].en;
                    assign mem_wr_if[bank][_buf].addr = buf_wr_if[_buf].addr;
                    assign mem_wr_if[bank][_buf].data =
                           buf_wr_if[_buf].data[ bank * BANK_DATA_WID +: BANK_DATA_WID ];
                    assign mem_wr_if[bank][_buf].req  = buf_wr_if[_buf].req;

                    if (bank==0) begin
                        assign buf_wr_if[_buf].rdy = mem_wr_if[bank][_buf].rdy;
                        assign buf_wr_if[_buf].ack = mem_wr_if[bank][_buf].ack;
                    end

                    // rd control signals.
                    assign mem_rd_if[bank][_buf].rst  = buf_rd_if[_buf].rst;
                    assign mem_rd_if[bank][_buf].addr = buf_rd_if[_buf].addr;
                    assign mem_rd_if[bank][_buf].req  = buf_rd_if[_buf].req;

                    assign buf_rd_if[_buf].data[ bank * BANK_DATA_WID +: BANK_DATA_WID ] =
                           mem_rd_if[bank][_buf].data;

                    if (bank==0) begin
                        assign buf_rd_if[_buf].rdy = mem_rd_if[bank][_buf].rdy;
                        assign buf_rd_if[_buf].ack = mem_rd_if[bank][_buf].ack;
                end
            end
        end
    endgenerate

endmodule;  // fec_col_buf
