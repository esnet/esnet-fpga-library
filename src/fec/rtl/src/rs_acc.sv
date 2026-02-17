module rs_acc
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int SYM_PER_COL = 1024
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] parity_out,
    output logic parity_out_valid,
    input  logic parity_out_ready
);

    // derived parameters.
    localparam DATA_SYM_WID = DATA_WID / SYM_SIZE;
    localparam  SYM_PER_BLK = SYM_PER_COL * RS_K;
    localparam CLKS_PER_COL = SYM_PER_COL / DATA_SYM_WID;  // CLKS_PER_COL >= 4 (PIPE_STAGES).
    localparam CLKS_PER_BLK = SYM_PER_BLK / DATA_SYM_WID;

    // parameter validation.
    initial std_pkg::param_check_gt(CLKS_PER_COL, 4, "CLKS_PER_COL i.e. SYM_PER_COL/(DATA_WID/SYM_SIZE) >= 4");

    localparam PIPE_STAGES = 4;  // ingress pipeline parameters.
    localparam   RD_STAGE  = 0;
    localparam   PP_STAGE  = 1;
    localparam  ACC_STAGE  = 2;
    localparam   WR_STAGE  = 3;

    localparam  OUT_STAGE  = 1;  // egress pipeline parameters.

    // signals - ingress data_in pipeline.
    logic [$clog2(CLKS_PER_BLK)-1:0] index;   // word index within FEC block.  1 word = 'DATA_SYM_WID' symbols.
    logic buf_sel;

    logic [PIPE_STAGES-1:0][DATA_SYM_WID-1:0][SYM_SIZE-1:0] pipe_data;
    logic [PIPE_STAGES-1:0]                                 pipe_valid;
    logic [PIPE_STAGES-1:0][$clog2(CLKS_PER_BLK)-1:0]       pipe_index;
    logic [PIPE_STAGES-1:0]                                 pipe_buf_sel;

    // signals - egress parity_out pipeline.
    logic [$clog2(CLKS_PER_BLK):0] rd_index;
    logic rd_req;

    logic [PIPE_STAGES-1:0][$clog2(CLKS_PER_BLK)-1:0]       pipe_rd_index;
    logic [PIPE_STAGES-1:0]                                 pipe_rd_req;

    logic [RS_2T-1:0][DATA_SYM_WID-1:0][SYM_SIZE-1:0] parity;

    logic [DATA_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] fifo_in;
    logic fifo_wr_rdy, fifo_rd, fifo_empty;


    // instantiate ingress and egress pipelines.
    assign data_in_ready = parity_out_ready;

    always_ff @(posedge clk)
        if (srst) begin
            index   <= '0;
            buf_sel <=  0;
        end else if (data_in_valid && data_in_ready) begin
            index   <= index+1;
            buf_sel <= (index == CLKS_PER_BLK-1) ? !buf_sel : buf_sel;
        end

    always @(posedge clk) begin
        pipe_data [0]     <= data_in;
        pipe_valid[0]     <= data_in_valid && data_in_ready;
        pipe_index[0]     <= index;
        pipe_buf_sel[0]   <= buf_sel;

        pipe_rd_index[0]  <= rd_index;
        pipe_rd_req[0]    <= rd_req;

        for (int i=1; i<PIPE_STAGES; i++) begin
            pipe_data     [i] <= pipe_data     [i-1];
            pipe_valid    [i] <= pipe_valid    [i-1];
            pipe_index    [i] <= pipe_index    [i-1];
            pipe_buf_sel  [i] <= pipe_buf_sel  [i-1];

            pipe_rd_index [i] <= pipe_rd_index [i-1];
            pipe_rd_req   [i] <= pipe_rd_req   [i-1];
        end
    end


    // memory read fsm (for steaming output parity).
    always_ff @(posedge clk) begin
        if (srst) begin
            rd_index <= '1;
            rd_req   <= 1'b0;
        end else if (pipe_buf_sel[ACC_STAGE] ^ pipe_buf_sel[WR_STAGE]) begin
            rd_index <= '0;
            rd_req   <= 1'b1;
        end else if ((rd_index < RS_2T*CLKS_PER_COL-1) && parity_out_ready && fifo_wr_rdy) begin
            rd_index <= rd_index+1;
            rd_req   <= 1'b1;
        end else begin
            rd_index <= rd_index;
            rd_req   <= 1'b0;
        end
    end



    // === parity processing pipeline (RD_STAGE -> PP_STAGE -> ACC_STAGE -> WR_STAGE). ===

    // RD_STAGE ---- read accumulator state.
    // no processing logic.  initiates 'parity state' column read access (below) i.e. reads 'parity' state. 


    // PP_STAGE ---- calculates partial products (as well as latency cycle from RD_STAGE).
    logic [$clog2(RS_K)-1:0] g_index;
    logic [RS_2T-1:0][DATA_SYM_WID-1:0][SYM_SIZE-1:0] _pp, pp;

    always_comb begin
       g_index = pipe_index[PP_STAGE] / CLKS_PER_COL;
       for (int i=0; i<RS_2T; i++)
           for (int j=0; j<DATA_SYM_WID; j++)
               _pp[i][j] = gf_mul( pipe_data[PP_STAGE][j], RS_G_LUT[g_index][RS_K+i] );
    end

    always @(posedge clk) pp <= _pp;


    // ACC_STAGE ---- accumulates partial product with running sums ('parity state' from memory).
    logic [RS_2T-1:0][DATA_SYM_WID-1:0][SYM_SIZE-1:0] _acc, acc, sum;
    always_comb
       for (int i=0; i<RS_2T; i++) begin
           for (int j=0; j<DATA_SYM_WID; j++)
               if ( pipe_index[ACC_STAGE] >> $clog2(CLKS_PER_COL) == '0 )
                    _acc[i][j] = pp[i][j];  // initialize acc with 1st pp.
               else _acc[i][j] = gf_add(sum[i][j], pp[i][j]);
       end

    always @(posedge clk) acc <= _acc;


    // WR_STAGE ---- write accumulator state.
    // no processing logic,  initiates 'parity state' column write access (below) i.e. writes  'acc' state.




    // ---- FEC column buffer instantiations ----
    localparam int NUM_BUFS = 2;      // double buffer implementation for concurrent streaming and processing.
    localparam int RAM_ADDR_WID = 9;  // 512 words.

    mem_wr_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) mux_wr_if [RS_2T][NUM_BUFS][2] (.clk(clk));
    mem_rd_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) mux_rd_if [RS_2T][NUM_BUFS][2] (.clk(clk));

    mem_wr_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) buf_wr_if [RS_2T][NUM_BUFS] (.clk(clk));
    mem_rd_intf #(.ADDR_WID(RAM_ADDR_WID), .DATA_WID(DATA_WID)) buf_rd_if [RS_2T][NUM_BUFS] (.clk(clk));

    generate
    for (genvar i = 0; i < RS_2T; i++) begin : g_parity
        for (genvar j = 0; j < NUM_BUFS; j++) begin : g_buf
 
            // instantiate input muxing logic for double buffers.
            logic  wr_sel, rd_sel;
            assign wr_sel = (j==0) ? pipe_buf_sel[WR_STAGE] : !pipe_buf_sel[WR_STAGE];
            assign rd_sel = (j==0) ? pipe_buf_sel[RD_STAGE] : !pipe_buf_sel[RD_STAGE];

            mem_wr_intf_mux mem_wr_intf_mux_inst (
                .from_controller (mux_wr_if[i][j]),
                .to_peripheral   (buf_wr_if[i][j]),
                .sel             (wr_sel)
            );

            mem_rd_intf_mux mem_rd_intf_mux_inst (
                .from_controller (mux_rd_if[i][j]),
                .to_peripheral   (buf_rd_if[i][j]),
                .sel             (rd_sel)
            );

            // generate memory interface signals for rs parity processing.
            assign mux_wr_if[i][j][0].rst  = srst;
            assign mux_wr_if[i][j][0].en   = 1'b1;
            assign mux_wr_if[i][j][0].addr = { '0, pipe_index[WR_STAGE] % CLKS_PER_COL };
            assign mux_wr_if[i][j][0].data = acc[i];
            assign mux_wr_if[i][j][0].req  = pipe_valid[WR_STAGE];

            assign mux_rd_if[i][j][0].rst  = srst;
            assign mux_rd_if[i][j][0].addr = { '0, pipe_index[RD_STAGE] % CLKS_PER_COL };
            assign mux_rd_if[i][j][0].req  = pipe_valid[RD_STAGE];


            // generate memory interface signals for streaming output parity.
            assign mux_wr_if[i][j][1].rst  = srst;
            assign mux_wr_if[i][j][1].en   = 1'b1;
            assign mux_wr_if[i][j][1].addr = '0;
            assign mux_wr_if[i][j][1].data = '0;
            assign mux_wr_if[i][j][1].req  = '0;

            assign mux_rd_if[i][j][1].rst  = srst;
            assign mux_rd_if[i][j][1].addr = { '0, rd_index % CLKS_PER_COL };
            assign mux_rd_if[i][j][1].req  = (rd_index >= i*CLKS_PER_COL) && (rd_index < (i+1)*CLKS_PER_COL);

        end

        // instantiate column buffers.
        fec_col_buf #(.NUM_BUFS(NUM_BUFS)) fec_col_buf_inst (
            .clk        (clk),
            .srst       (srst),
            .buf_wr_if  (buf_wr_if[i]),
            .buf_rd_if  (buf_rd_if[i])
        );

        // output muxing logic from double buffers (processing pipeline).
        assign sum[i] = pipe_buf_sel[WR_STAGE] ? buf_rd_if[i][1].data : buf_rd_if[i][0].data;

        // output muxing logic from double buffers (output parity streaming).
        assign parity[i] = pipe_buf_sel[WR_STAGE] ? buf_rd_if [i][0].data : buf_rd_if [i][1].data ;

    end
    endgenerate


    // instantiate output FIFO (to support stalls in datapath).
    assign fifo_in = parity[pipe_rd_index[OUT_STAGE]/CLKS_PER_COL];

    fifo_sync #(.DATA_WID(DATA_WID), .DEPTH(8)) fifo_sync_inst (
        .clk       (clk),
	.srst      (srst),
	.wr_rdy    (fifo_wr_rdy),
        .wr        (pipe_rd_req[OUT_STAGE]),
        .wr_data   (fifo_in),
        .wr_count  (),
        .full      (),
        .oflow     (),
        .rd        (fifo_rd),
	.rd_ack    (),
        .rd_data   (parity_out),
        .rd_count  (),
        .empty     (fifo_empty),
        .uflow     ()
    );

    assign fifo_rd = parity_out_ready && !fifo_empty;
    assign parity_out_valid = fifo_rd;

endmodule;  // rs_acc
