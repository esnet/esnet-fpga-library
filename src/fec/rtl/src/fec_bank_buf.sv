module fec_bank_buf
    import fec_pkg::*;
#(
    parameter int NUM_BUFS = 2  // double buffers used for concurrent streaming and processing.
) (
    input  logic clk,
    input  logic srst,

    mem_wr_intf.peripheral buf_wr_if [NUM_BUFS],
    mem_rd_intf.peripheral buf_rd_if [NUM_BUFS]
);
    import mem_pkg::*;
   
    // -------------------------------------------------------------------------
    // memory organization (per buffer):
    // 512 words × 128 bits per bank. 2 RAMs per bank (high+low).  512 words × 64 bits per RAM.
    // -------------------------------------------------------------------------
    localparam int NUM_RAMS = 2;
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

    // memory interfaces: NUM_RAMS RAMs/bank = 8 RAM instances.
    mem_wr_intf #(
        .ADDR_WID(RAM_ADDR_WID),
        .DATA_WID(RAM_DATA_WID)
    ) mem_wr_if [NUM_BUFS-1:0][NUM_RAMS-1:0] (
        .clk(clk)
    );

    mem_rd_intf #(
        .ADDR_WID(RAM_ADDR_WID),
        .DATA_WID(RAM_DATA_WID)
    ) mem_rd_if [NUM_BUFS-1:0][NUM_RAMS-1:0] (
        .clk(clk)
    );

    // instantiate RAM instances.
    generate
        for (genvar _buf = 0; _buf < NUM_BUFS; _buf++) begin : g_buf
            for (genvar ram = 0; ram < NUM_RAMS; ram++) begin : g_ram
                mem_ram_sdp #(
                    .SPEC(MEM_SPEC)
                ) i_mem_ram_sdp (
                    .mem_wr_if(mem_wr_if[_buf][ram]),
                    .mem_rd_if(mem_rd_if[_buf][ram])
                );

                // wr control signals.
                assign mem_wr_if[_buf][ram].rst  = buf_wr_if[_buf].rst;
                assign mem_wr_if[_buf][ram].en   = buf_wr_if[_buf].en;
                assign mem_wr_if[_buf][ram].addr = buf_wr_if[_buf].addr;
                assign mem_wr_if[_buf][ram].data = 
                       buf_wr_if[_buf].data[ ram * RAM_DATA_WID +: RAM_DATA_WID ];
                assign mem_wr_if[_buf][ram].req  = buf_wr_if[_buf].req;

                if (ram==0) begin
                    assign buf_wr_if[_buf].rdy = mem_wr_if[_buf][ram].rdy;
                    assign buf_wr_if[_buf].ack = mem_wr_if[_buf][ram].ack;
                end

                // rd control signals.
                assign mem_rd_if[_buf][ram].rst  = buf_rd_if[_buf].rst;
                assign mem_rd_if[_buf][ram].addr = buf_rd_if[_buf].addr;
                assign mem_rd_if[_buf][ram].req  = buf_rd_if[_buf].req;

                assign buf_rd_if[_buf].data[ ram * RAM_DATA_WID +: RAM_DATA_WID ] =
                       mem_rd_if[_buf][ram].data;

                if (ram==0) begin
                    assign buf_rd_if[_buf].rdy = mem_rd_if[_buf][ram].rdy;
                    assign buf_rd_if[_buf].ack = mem_rd_if[_buf][ram].ack;
                end
            end
        end
    endgenerate

endmodule;  // fec_bank_buf
