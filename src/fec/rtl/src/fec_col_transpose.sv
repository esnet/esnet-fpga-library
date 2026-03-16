module fec_col_transpose
    import fec_pkg::*;
#(
    parameter int DATA_WID = 512,
    parameter int COL_WID  = SYM_SIZE,
    parameter int COL_LEN  = 1024,
    parameter fec_col_transpose_mode_t MODE = BIT_TO_SYM
) (
    input  logic clk,
    input  logic srst,

    input  logic [DATA_WID-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    output logic [DATA_WID-1:0] data_out,
    output logic data_out_valid,
    input  logic data_out_ready
);

    // derived parameters.
    localparam CLKS_PER_COL = COL_LEN / DATA_WID;
    localparam CLKS_PER_BLK = CLKS_PER_COL * COL_WID;

    // pipeline parameters.
    localparam PIPE_STAGES = 3;
    localparam REQ_STAGE   = 0; // initiates buffer write and read access requests (below).
    localparam ACK_STAGE   = 2; // memory read data is ready (below).


    // signals.
    logic [$clog2(CLKS_PER_BLK)-1:0] index;  // word index within column.  1 word = 'DATA_WID' bits.
    logic buf_sel;

    logic [PIPE_STAGES-1:0][DATA_WID-1:0]              pipe_data;
    logic [PIPE_STAGES-1:0]                            pipe_valid;
    logic [PIPE_STAGES-1:0][$clog2(CLKS_PER_BLK)-1:0]  pipe_index;
    logic [PIPE_STAGES-1:0]                            pipe_buf_sel;

    logic [2*DATA_WID-1:0]                             pipe_data_x2;
    logic   [DATA_WID-1:0]                             wr_data;
    logic [$clog2(CLKS_PER_BLK):0]                     wr_index;

    logic [$clog2(CLKS_PER_BLK):0]                     rd_index;
    logic                                              rd_req;
    logic [PIPE_STAGES-1:0][$clog2(CLKS_PER_BLK)-1:0]  pipe_rd_index;
    logic [PIPE_STAGES-1:0]                            pipe_rd_req;

    logic [DATA_WID-1:0] fifo_in;
    logic fifo_wr_rdy, fifo_rd, fifo_empty;


    // instantiate ingress and egress pipelines.
    assign data_in_ready = data_out_ready;

    always_ff @(posedge clk)
        if (srst) begin
            index   <= '0;
            buf_sel <=  0;
        end else if (data_in_valid && data_in_ready) begin
            index   <= (index == CLKS_PER_BLK-1) ? 0 : index+1;
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
            pipe_valid   [i] <= pipe_valid   [i-1];
            pipe_index   [i] <= pipe_index   [i-1];
            pipe_buf_sel [i] <= pipe_buf_sel [i-1];

            pipe_rd_index [i] <= pipe_rd_index [i-1];
            pipe_rd_req [i] <= pipe_rd_req [i-1];
        end
    end

    assign pipe_data_x2 = {pipe_data[REQ_STAGE], pipe_data[REQ_STAGE]};

    assign wr_index = pipe_index[REQ_STAGE];

    // memory read fsm (for steaming output data).
    always_ff @(posedge clk) begin
        if (srst) begin
            rd_index <= '1;
            rd_req   <= 1'b0;
        end else if (buf_sel ^ pipe_buf_sel[0]) begin
            rd_index <= '0;
            rd_req   <= 1'b1;
        end else if ((rd_index < CLKS_PER_BLK-1) && data_out_ready && fifo_wr_rdy) begin
            rd_index <= rd_index+1;
            rd_req   <= 1'b1;
        end else begin
            rd_index <= rd_index;
            rd_req   <= 1'b0;
        end
    end



    // ---- FEC bank buffer instantiations ----

    localparam int NUM_BUFS  = 2;        // double buffers used for concurrent streaming in and out.
    localparam int NUM_BANKS = COL_WID;  // one bank per column.
    localparam int BANK_ADDR_WID = 9;    // 512 words
    localparam int BANK_DATA_WID = DATA_WID/NUM_BANKS;

    mem_wr_intf #(.ADDR_WID(BANK_ADDR_WID), .DATA_WID(BANK_DATA_WID)) mux_wr_if [NUM_BANKS][NUM_BUFS][2] (.clk(clk));
    mem_rd_intf #(.ADDR_WID(BANK_ADDR_WID), .DATA_WID(BANK_DATA_WID)) mux_rd_if [NUM_BANKS][NUM_BUFS][2] (.clk(clk));

    mem_wr_intf #(.ADDR_WID(BANK_ADDR_WID), .DATA_WID(BANK_DATA_WID)) buf_wr_if [NUM_BANKS][NUM_BUFS] (.clk(clk));
    mem_rd_intf #(.ADDR_WID(BANK_ADDR_WID), .DATA_WID(BANK_DATA_WID)) buf_rd_if [NUM_BANKS][NUM_BUFS] (.clk(clk));

    logic [NUM_BUFS-1:0][  DATA_WID-1:0] buf_rd_data;
    logic [NUM_BUFS-1:0][2*DATA_WID-1:0] buf_rd_data_x2;

    generate begin
        if (MODE == BIT_TO_SYM)
             assign wr_data = pipe_data_x2[(2*DATA_WID - (wr_index/CLKS_PER_COL)*(DATA_WID/COL_WID))-1 -: DATA_WID];
        else 
             assign wr_data = pipe_data[REQ_STAGE];


        for (genvar i = 0; i < NUM_BANKS; i++) begin : g_bank
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

                if (MODE == SYM_TO_BIT) begin
                    assign mux_wr_if[i][j][0].rst  = srst;
                    assign mux_wr_if[i][j][0].en   = 1'b1;
                    assign mux_wr_if[i][j][0].req  = pipe_valid[REQ_STAGE];
                    assign mux_wr_if[i][j][0].addr = { '0,  ((i-wr_index)%COL_WID)*CLKS_PER_COL + wr_index/COL_WID };

                    for (genvar k = 0; k < BANK_DATA_WID; k++) begin : g_bit_slice
                        assign mux_wr_if[i][j][0].data[k] = wr_data[(i-wr_index)%COL_WID + k*COL_WID +: 1];
                    end

                end else if (MODE == BIT_TO_SYM) begin
                    assign mux_wr_if[i][j][0].rst  = srst;
                    assign mux_wr_if[i][j][0].en   = 1'b1;
                    assign mux_wr_if[i][j][0].req  = pipe_valid[REQ_STAGE];
                    assign mux_wr_if[i][j][0].addr = { '0, wr_index };
                    assign mux_wr_if[i][j][0].data = wr_data[i*BANK_DATA_WID +: BANK_DATA_WID];
                end 


                // generate memory interface signals for output streaming.
                assign mux_wr_if[i][j][1].rst  = srst;
                assign mux_wr_if[i][j][1].en   = 1'b1;
                assign mux_wr_if[i][j][1].req  = '0;
                assign mux_wr_if[i][j][1].addr = '0;
                assign mux_wr_if[i][j][1].data = '0;

                if (MODE == SYM_TO_BIT) begin
                    assign mux_rd_if[i][j][1].rst  = srst;
                    assign mux_rd_if[i][j][1].req  = rd_req;
                    assign mux_rd_if[i][j][1].addr = { '0, rd_index };
                end else if (MODE == BIT_TO_SYM) begin
                    assign mux_rd_if[i][j][1].rst  = srst;
                    assign mux_rd_if[i][j][1].req  = rd_req;
                    assign mux_rd_if[i][j][1].addr = { '0, ((i-rd_index)%COL_WID)*CLKS_PER_COL + rd_index/COL_WID };
                end 

                assign buf_rd_data[j][i*BANK_DATA_WID +: BANK_DATA_WID] = buf_rd_if[i][j].data;

            end : g_buf


            // instantiate memory bank buffers.
            fec_bank_buf #(.NUM_BUFS(NUM_BUFS)) fec_bank_buf_inst (
                .clk        (clk),
                .srst       (srst),
                .buf_wr_if  (buf_wr_if[i]),
                .buf_rd_if  (buf_rd_if[i])
            );

        end : g_bank

        for (genvar i = 0; i < 2; i++) assign buf_rd_data_x2[i] = {buf_rd_data[i], buf_rd_data[i]};

        // output muxing logic from double buffers.
        for (genvar i = 0; i < DATA_WID/COL_WID; i++) begin : g_sym
            for (genvar j = 0; j < COL_WID; j++) begin : g_bit
                if (MODE == SYM_TO_BIT) begin
                    assign fifo_in[i*COL_WID+j] = pipe_buf_sel[ACK_STAGE] ?
                           buf_rd_data_x2[0][(pipe_rd_index[1]/CLKS_PER_COL)*BANK_DATA_WID + (i*COL_WID+j) +: 1] :
                           buf_rd_data_x2[1][(pipe_rd_index[1]/CLKS_PER_COL)*BANK_DATA_WID + (i*COL_WID+j) +: 1] ;
                end else if (MODE == BIT_TO_SYM) begin
                    assign fifo_in[i*COL_WID+j] = pipe_buf_sel[ACK_STAGE] ?
                           buf_rd_data[0][(((j+pipe_rd_index[1])%COL_WID)*BANK_DATA_WID + i) +: 1] :
                           buf_rd_data[1][(((j+pipe_rd_index[1])%COL_WID)*BANK_DATA_WID + i) +: 1] ;
                end 
            end
        end

    end endgenerate


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

endmodule;  // fec_col_transpose
