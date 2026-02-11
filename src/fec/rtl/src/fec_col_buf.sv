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
    // 2 RAMs per bank (high + low).  512 words × 64 bits per RAM.
    // -------------------------------------------------------------------------
    localparam int NUM_BANKS = 4;
    localparam int NUM_RAMS_PER_BANK = 2;
    localparam int RAM_ADDR_WID = 9;
    localparam int RAM_DATA_WID = 64;

    // memory specification for 512×64 BRAM instances in buffer array.
    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: RAM_ADDR_WID,
        DATA_WID: RAM_DATA_WID,
        ASYNC: 0,
        RESET_FSM: 0,
        OPT_MODE: OPT_MODE_TIMING  // OPT_MODE_LATENCY
    };

    // memory interfaces for 4 banks × 2 RAMs/bank = 8 RAM instances.
    mem_wr_intf #(
        .ADDR_WID(RAM_ADDR_WID),
        .DATA_WID(RAM_DATA_WID)
    ) mem_wr_if [NUM_BUFS-1:0][NUM_BANKS-1:0][NUM_RAMS_PER_BANK-1:0] (
        .clk(clk)
    );

    mem_rd_intf #(
        .ADDR_WID(RAM_ADDR_WID),
        .DATA_WID(RAM_DATA_WID)
    ) mem_rd_if [NUM_BUFS-1:0][NUM_BANKS-1:0][NUM_RAMS_PER_BANK-1:0] (
        .clk(clk)
    );

    // instantiate RAM instances.
    generate
        for (genvar buff = 0; buff < NUM_BUFS; buff++) begin : g_buf
            for (genvar bank = 0; bank < NUM_BANKS; bank++) begin : g_bank
                for (genvar ram = 0; ram < NUM_RAMS_PER_BANK; ram++) begin : g_ram
                    mem_ram_sdp #(
                        .SPEC(MEM_SPEC)
                    ) i_mem_ram_sdp (
                        .mem_wr_if(mem_wr_if[buff][bank][ram]),
                        .mem_rd_if(mem_rd_if[buff][bank][ram])
                    );

                    // wr control signals.
                    assign mem_wr_if[buff][bank][ram].rst  = buf_wr_if[buff].rst;
                    assign mem_wr_if[buff][bank][ram].en   = buf_wr_if[buff].en;
                    assign mem_wr_if[buff][bank][ram].addr = buf_wr_if[buff].addr;
                    assign mem_wr_if[buff][bank][ram].data = 
                           buf_wr_if[buff].data[ (bank * NUM_RAMS_PER_BANK + ram) * RAM_DATA_WID +: RAM_DATA_WID ];
                    assign mem_wr_if[buff][bank][ram].req  = buf_wr_if[buff].req;

                    if (bank==0 && ram==0) begin
                        assign buf_wr_if[buff].rdy = mem_wr_if[buff][bank][ram].rdy;
                        assign buf_wr_if[buff].ack = mem_wr_if[buff][bank][ram].ack;
                    end

                    // rd control signals.
                    assign mem_rd_if[buff][bank][ram].rst  = buf_rd_if[buff].rst;
                    assign mem_rd_if[buff][bank][ram].addr = buf_rd_if[buff].addr;
                    assign mem_rd_if[buff][bank][ram].req  = buf_rd_if[buff].req;

                    assign buf_rd_if[buff].data[ (bank * NUM_RAMS_PER_BANK + ram) * RAM_DATA_WID +: RAM_DATA_WID ] =
                           mem_rd_if[buff][bank][ram].data;

                    if (bank==0 && ram==0) begin
                        assign buf_rd_if[buff].rdy = mem_rd_if[buff][bank][ram].rdy;
                        assign buf_rd_if[buff].ack = mem_rd_if[buff][bank][ram].ack;
                    end
                end
            end
        end
    endgenerate

endmodule;  // fec_col_buf
