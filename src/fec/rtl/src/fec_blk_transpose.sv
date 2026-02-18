module fec_blk_transpose
    import fec_pkg::*;
#(
    parameter int DATA_WID    = 512,
    parameter int NUM_COL     = RS_K,
    parameter int SYM_PER_COL = 1024,
    parameter fec_blk_transpose_mode_t MODE = CW_TO_COL
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    // derived parameters.
    localparam DATA_SYM_WID = DATA_WID / SYM_SIZE;
    localparam  SYM_PER_BLK = SYM_PER_COL * NUM_COL;
    localparam CLKS_PER_COL = SYM_PER_COL / DATA_SYM_WID;
    localparam CLKS_PER_BLK = SYM_PER_BLK / DATA_SYM_WID;

    // pipeline parameters.
    localparam PIPE_STAGES = 3;
    localparam REQ_STAGE   = 0; // no processing logic.  initiates buffer write and read access requests (below).
    localparam ACK_STAGE   = 2; // no processing logic.  signals that memory read data is ready (below).


    // signals.
    logic [$clog2(CLKS_PER_BLK)-1:0] index;  // word index within FEC block.  1 word = 'DATA_SYM_WID' symbols.
    logic buf_sel;

    logic [PIPE_STAGES-1:0][DATA_SYM_WID-1:0][SYM_SIZE-1:0] pipe_data;
    logic [PIPE_STAGES-1:0]                                 pipe_valid;
    logic [PIPE_STAGES-1:0][$clog2(CLKS_PER_BLK)-1:0]       pipe_index;
    logic [PIPE_STAGES-1:0]                                 pipe_buf_sel;

    logic [$clog2(CLKS_PER_BLK):0] rd_index;
    logic rd_req;
    logic [PIPE_STAGES-1:0][$clog2(CLKS_PER_BLK)-1:0]       pipe_rd_index;
    logic [PIPE_STAGES-1:0]                                 pipe_rd_req;

    logic [DATA_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] fifo_in;
    logic fifo_wr_rdy, fifo_rd, fifo_empty;


    // instantiate ingress and egress pipelines.
    assign data_in_ready = data_out_ready;

    always_ff @(posedge clk)
        if (srst) begin
            index   <= '0;
            buf_sel <=  0;
        end else if (data_in_valid && data_in_ready) begin
            index   <= index+1;
            buf_sel <= (index == CLKS_PER_BLK-1) ? !buf_sel : buf_sel;
        end

    always @(posedge clk) begin
        pipe_data [0]   <= data_in;
        pipe_valid[0]   <= data_in_valid && data_in_ready;
        pipe_index[0]   <= index;
        pipe_buf_sel[0] <= buf_sel;

        pipe_rd_index[0] <= rd_index;
        pipe_rd_req[0] <= rd_req;

        for (int i=1; i<PIPE_STAGES; i++) begin
            pipe_data    [i] <= pipe_data    [i-1];
            pipe_valid   [i] <= pipe_valid   [i-1];
            pipe_index   [i] <= pipe_index   [i-1];
            pipe_buf_sel [i] <= pipe_buf_sel [i-1];

            pipe_rd_index [i] <= pipe_rd_index [i-1];
            pipe_rd_req [i] <= pipe_rd_req [i-1];
        end
    end


    // memory read fsm (for steaming output data).
    always_ff @(posedge clk) begin
        if (srst) begin
            rd_index <= '1;
            rd_req   <= 1'b0;
        end else if (buf_sel ^ pipe_buf_sel[0]) begin
            rd_index <= '0;
            rd_req   <= 1'b1;
        end else if ((rd_index < NUM_COL*CLKS_PER_COL-1) && data_out_ready && fifo_wr_rdy) begin
            rd_index <= rd_index+1;
            rd_req   <= 1'b1;
        end else begin
            rd_index <= rd_index;
            rd_req   <= 1'b0;
        end
    end



    // ---- FEC column buffer instantiations ----
    localparam int NUM_BUFS = 2;      // double buffer implementation for concurrent streaming in and out.
    localparam int RAM_ADDR_WID = 9;  // 512 words

    mem_wr_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) mux_wr_if [NUM_COL][NUM_BUFS][2] (.clk(clk));
    mem_rd_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) mux_rd_if [NUM_COL][NUM_BUFS][2] (.clk(clk));

    mem_wr_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) buf_wr_if [NUM_COL][NUM_BUFS] (.clk(clk));
    mem_rd_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) buf_rd_if [NUM_COL][NUM_BUFS] (.clk(clk));


    generate
    for (genvar i = 0; i < NUM_COL; i++) begin : g_col
        for (genvar j = 0; j < NUM_BUFS; j++) begin : g_buf

            // instantiate input muxing logic for double buffers.
            logic  sel;
            assign sel = (j==0) ? pipe_buf_sel[REQ_STAGE] : !pipe_buf_sel[REQ_STAGE];

            mem_wr_intf_mux mem_wr_intf_mux_inst (
                .from_controller (mux_wr_if[i][j]),
                .to_peripheral   (buf_wr_if[i][j]),
                .sel             (sel)
            );

            mem_rd_intf_mux mem_rd_intf_mux_inst (
                .from_controller (mux_rd_if[i][j]),
                .to_peripheral   (buf_rd_if[i][j]),
                .sel             (sel)
            );


            // generate memory interface signals for input streaming.
            assign mux_rd_if[i][j][0].rst  = srst;
            assign mux_rd_if[i][j][0].req  = '0;
            assign mux_rd_if[i][j][0].addr = '0;

            if (MODE == CW_TO_COL) begin
                assign mux_wr_if[i][j][0].rst  = srst;
                assign mux_wr_if[i][j][0].en   = 1'b1;
                assign mux_wr_if[i][j][0].req  = pipe_valid[REQ_STAGE] && ((pipe_index[REQ_STAGE] % NUM_COL) == i);
                assign mux_wr_if[i][j][0].addr = { '0, pipe_index[REQ_STAGE] / NUM_COL };
                assign mux_wr_if[i][j][0].data = pipe_data [REQ_STAGE];
            end else if (MODE == COL_TO_CW) begin
                assign mux_wr_if[i][j][0].rst  = srst;
                assign mux_wr_if[i][j][0].en   = 1'b1;
                assign mux_wr_if[i][j][0].req  = pipe_valid[REQ_STAGE] && ((pipe_index[REQ_STAGE] / CLKS_PER_COL) == i);
                assign mux_wr_if[i][j][0].addr = { '0, pipe_index[REQ_STAGE] % CLKS_PER_COL };
                assign mux_wr_if[i][j][0].data = pipe_data [REQ_STAGE];
            end 


            // generate memory interface signals for output streaming.
            assign mux_wr_if[i][j][1].rst  = srst;
            assign mux_wr_if[i][j][1].en   = 1'b1;
            assign mux_wr_if[i][j][1].req  = '0;
            assign mux_wr_if[i][j][1].addr = '0;
            assign mux_wr_if[i][j][1].data = '0;

            if (MODE == CW_TO_COL) begin
                assign mux_rd_if[i][j][1].rst  = srst;
                assign mux_rd_if[i][j][1].req  = rd_req;
                assign mux_rd_if[i][j][1].addr = rd_index % CLKS_PER_COL;
            end else if (MODE == COL_TO_CW) begin
                assign mux_rd_if[i][j][1].rst  = srst;
                assign mux_rd_if[i][j][1].req  = rd_req;
                assign mux_rd_if[i][j][1].addr = rd_index / NUM_COL;
            end 
        end

        // instantiate column buffers.
        fec_col_buf #(.NUM_BUFS(NUM_BUFS)) fec_col_buf_inst (
            .clk        (clk),
            .srst       (srst),
            .buf_wr_if  (buf_wr_if[i]),
            .buf_rd_if  (buf_rd_if[i])
        );


        // output muxing logic from double buffers.
        for (genvar j = 0; j < DATA_SYM_WID/NUM_COL; j++) begin : g_cw
            if (MODE == CW_TO_COL) begin
                assign fifo_in[i*DATA_SYM_WID/NUM_COL+j] = pipe_buf_sel[ACK_STAGE] ?
                       buf_rd_if[i][0].data[(pipe_rd_index[1]/CLKS_PER_COL + j*NUM_COL)*SYM_SIZE +: SYM_SIZE] :
                       buf_rd_if[i][1].data[(pipe_rd_index[1]/CLKS_PER_COL + j*NUM_COL)*SYM_SIZE +: SYM_SIZE] ;
            end else if (MODE == COL_TO_CW) begin
                assign fifo_in[j*NUM_COL+i] = pipe_buf_sel[ACK_STAGE] ?
                       buf_rd_if[i][0].data[((pipe_rd_index[1]%NUM_COL) * DATA_SYM_WID/NUM_COL + j)*SYM_SIZE +: SYM_SIZE] :
                       buf_rd_if[i][1].data[((pipe_rd_index[1]%NUM_COL) * DATA_SYM_WID/NUM_COL + j)*SYM_SIZE +: SYM_SIZE] ;
            end 
        end

    end
    endgenerate


    // instantiate output FIFO (to support stalls in datapath).
    assign fifo_rd = data_out_ready && !fifo_empty;

    fifo_sync #(.DATA_WID(DATA_WID), .DEPTH(8), .OFLOW_PROT(1)) fifo_sync_inst (
        .clk       (clk),
        .srst      (srst),
        .wr_rdy    (fifo_wr_rdy),
        .wr        (pipe_rd_req[1]),
        .wr_data   (fifo_in),
        .wr_count  (),
        .full      (),
        .oflow     (),
        .rd        (fifo_rd),
        .rd_ack    (),
        .rd_data   (data_out),
        .rd_count  (),
        .empty     (fifo_empty),
        .uflow     ()
    );

    assign data_out_valid = fifo_rd;

endmodule;  // fec_blk_transpose
