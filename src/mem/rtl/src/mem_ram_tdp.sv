// True Dual-Port RAM implementation
// NOTE: This module provides a true dual-port (TDP) RAM implementation
//       with standard interfaces and built-in reset FSM.
module mem_ram_tdp
    import mem_pkg::*;
#(
    spec_t SPEC = DEFAULT_MEM_SPEC,
    parameter logic [SPEC.DATA_WID-1:0] RESET_VAL = '0,
    // Simulation parameters
    parameter bit SIM__FAST_INIT = 0, // Fast init in simulations
    parameter bit SIM__RAM_MODEL = 0  // Use model for RAM (associative array) in sims
) (
    // Port 0
    mem_intf.peripheral mem_if_0,
    // Port 1
    mem_intf.peripheral mem_if_1
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DEPTH = 2**SPEC.ADDR_WID;

    localparam int WR_LATENCY_RAM = get_ram_wr_latency(SPEC);
    localparam int RD_LATENCY_RAM = get_ram_rd_latency(SPEC);
    localparam int WR_LATENCY = get_wr_latency(SPEC);
    localparam int RD_LATENCY = get_rd_latency(SPEC);

    localparam type ADDR_T = logic[SPEC.ADDR_WID-1:0];
    localparam type DATA_T = logic[SPEC.DATA_WID-1:0];

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_intf #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) __mem_if_0 (.clk(mem_if_0.clk));
    mem_intf #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) __mem_if_1 (.clk(mem_if_1.clk));

    // -----------------------------
    // Reset FSM (optional)
    // -----------------------------
    generate
        if (SPEC.RESET_FSM) begin : g__reset_fsm
            // (Local) interfaces
            mem_wr_intf #(.ADDR_WID(SPEC.ADDR_WID), .DATA_WID(SPEC.DATA_WID)) __mem_wr_if_in  (.clk(mem_if_0.clk));
            mem_wr_intf #(.ADDR_WID(SPEC.ADDR_WID), .DATA_WID(SPEC.DATA_WID)) __mem_wr_if_out (.clk(mem_if_0.clk));
            // Map from full memory interface to write-only interface
            assign __mem_wr_if_in.rst = mem_if_0.rst;
            assign __mem_wr_if_in.en = mem_if_0.wr;
            assign __mem_wr_if_in.req = mem_if_0.req;
            assign __mem_wr_if_in.addr = mem_if_0.addr;
            assign __mem_wr_if_in.data = mem_if_0.wr_data;
            assign mem_if_0.rdy    = __mem_wr_if_in.rdy;
            assign mem_if_0.wr_ack = __mem_wr_if_in.ack;

            // Reset FSM
            // - on reset deassertion, auto-clears memory by
            //   sequentially writing RESET_VAL to each memory element
            mem_reset_fsm     #(
                .ADDR_WID      ( SPEC.ADDR_WID ),
                .DATA_WID      ( SPEC.DATA_WID ),
                .RESET_VAL     ( RESET_VAL ),
                .SIM__FAST_INIT( SIM__FAST_INIT )
            ) i_mem_reset_fsm  (
                .mem_wr_if_in  ( __mem_wr_if_in ),
                .mem_wr_if_out ( __mem_wr_if_out )
            );

            // Map back to full memory interface
            assign __mem_if_0.rst  = __mem_wr_if_out.rst;
            assign __mem_if_0.req  = __mem_wr_if_out.req;
            assign __mem_if_0.wr   = __mem_wr_if_out.en;
            assign __mem_if_0.addr = __mem_wr_if_out.addr;
            assign __mem_if_0.wr_data = __mem_wr_if_out.data;
            assign __mem_wr_if_out.rdy = __mem_if_0.rdy;
            assign __mem_wr_if_out.ack = __mem_if_0.wr_ack;

            // Interfaces are ready when init is complete
            if (SPEC.ASYNC) begin : g__async
                // Synchronize ready from port 0 clock domain to port 1 clock domain
                sync_level #(
                    .RST_VALUE ( 1'b0 )
                ) i_sync_level__rdy (
                    .clk_in  ( mem_if_0.clk ),
                    .rst_in  ( mem_if_0.rst ),
                    .rdy_in  ( ),
                    .lvl_in  ( mem_if_0.rdy ),
                    .clk_out ( mem_if_1.clk ),
                    .rst_out ( 1'b0 ),
                    .lvl_out ( mem_if_1.rdy )
                );

            end : g__async
            else begin : g__sync
                // No need to synchronize ready signal
                assign mem_if_1.rdy = mem_if_0.rdy;

                if (SPEC.OPT_MODE == OPT_MODE_TIMING) begin : g__rd_req_pipe
                    // (Local) signals
                    logic __mem_if_1__req;
                    logic __mem_if_1__wr;
                    ADDR_T __mem_if_1__addr;
                    DATA_T __mem_if_1__wr_data;
                    // Pipeline requests on port 1 to maintain relative
                    // synchronization with port 0
                    initial __mem_if_1__req = 1'b0;
                    always @(posedge mem_if_1.clk) begin
                        __mem_if_1__req     <= mem_if_1.req;
                        __mem_if_1__wr      <= mem_if_1.wr;
                        __mem_if_1__addr    <= mem_if_1.addr;
                        __mem_if_1__wr_data <= mem_if_1.wr_data;
                    end
                    assign __mem_if_1.req     = __mem_if_1__req;
                    assign __mem_if_1.wr      = __mem_if_1__wr;
                    assign __mem_if_1.addr    = __mem_if_1__addr;
                    assign __mem_if_1.wr_data = __mem_if_1__wr_data;
                end : g__rd_req_pipe
                else begin : g__rd_req_no_pipe
                    // For all other optimization modes, no need to pipeline request interface
                    assign __mem_if_1.req     = mem_if_1.req;
                    assign __mem_if_1.wr      = mem_if_1.wr;
                    assign __mem_if_1.addr    = mem_if_1.addr;
                    assign __mem_if_1.wr_data = mem_if_1.wr_data;
                end : g__rd_req_no_pipe
            end : g__sync

            // Map remaining read interface signals
            assign mem_if_0.rd_ack = __mem_if_0.rd_ack;
            assign mem_if_0.rd_data = __mem_if_0.rd_data;

            assign __mem_if_1.rst = mem_if_1.rst;
            assign mem_if_1.wr_ack = __mem_if_1.wr_ack;
            assign mem_if_1.rd_ack = __mem_if_1.rd_ack;
            assign mem_if_1.rd_data = __mem_if_1.rd_data;

        end : g__reset_fsm
        else begin : g__no_reset_fsm
            // No reset FSM
            // - drive write interface directly
            //   (pass interfaces along unmodified)
            mem_intf_connector i_mem_intf_connector_0 (
                .mem_if_from_controller ( mem_if_0 ),
                .mem_if_to_peripheral   ( __mem_if_0 )
            );
            mem_intf_connector i_mem_intf_connector_1 (
                .mem_if_from_controller ( mem_if_1 ),
                .mem_if_to_peripheral   ( __mem_if_1 )
            );
        end : g__no_reset_fsm
    endgenerate

`ifndef SYNTHESIS
    generate
        if (SIM__RAM_MODEL) begin : g__ram_model
            // -----------------------------
            // RAM model declaration
            // (Sims only)
            // -----------------------------
            sim__mem_ram_tdp_model  #(
                .SPEC      ( SPEC ),
                .RESET_VAL ( RESET_VAL ),
                .FAST_INIT ( SIM__FAST_INIT )
            ) i_sim__mem_ram_tdp_model (
                .mem_if_0  ( __mem_if_0 ),
                .mem_if_1  ( __mem_if_1 )
            );
        end : g__ram_model
        else begin : g__ram
`endif // ifndef SYNTHESIS

    // -----------------------------
    // RAM declaration
    // -----------------------------
    xilinx_ram_tdp #(
        .ADDR_WID   ( SPEC.ADDR_WID ),
        .DATA_WID   ( SPEC.DATA_WID ),
        .ASYNC      ( SPEC.ASYNC ),
        .OPT_MODE   ( translate_opt_mode(SPEC.OPT_MODE) )
    ) i_xilinx_ram_tdp (
        .clk_A      ( __mem_if_0.clk ),
        .en_A       ( __mem_if_0.req ),
        .wr_A       ( __mem_if_0.wr ),
        .addr_A     ( __mem_if_0.addr ),
        .wr_data_A  ( __mem_if_0.wr_data ),
        .wr_ack_A   ( __mem_if_0.wr_ack ),
        .rd_data_A  ( __mem_if_0.rd_data ),
        .rd_ack_A   ( __mem_if_0.rd_ack ),
        .clk_B      ( __mem_if_1.clk ),
        .en_B       ( __mem_if_1.req ),
        .wr_B       ( __mem_if_1.wr ),
        .addr_B     ( __mem_if_1.addr ),
        .wr_data_B  ( __mem_if_1.wr_data ),
        .wr_ack_B   ( __mem_if_1.wr_ack ),
        .rd_data_B  ( __mem_if_1.rd_data ),
        .rd_ack_B   ( __mem_if_1.rd_ack )
    );

    // Base RAM is always ready
    assign __mem_if_0.rdy = 1'b1;
    assign __mem_if_1.rdy = 1'b1;

    // Check for expected write/read latencies
    initial begin
        std_pkg::param_check(WR_LATENCY_RAM, i_xilinx_ram_tdp.WR_LATENCY, "WR_LATENCY");
        std_pkg::param_check(RD_LATENCY_RAM, i_xilinx_ram_tdp.RD_LATENCY, "RD_LATENCY");
    end

`ifndef SYNTHESIS
        end : g__ram
    endgenerate
`endif // ifndef SYNTHESIS

endmodule : mem_ram_tdp

//
// -------------- RAM model for simulations only ------------------
//
`ifndef SYNTHESIS

module sim__mem_ram_tdp_model
    import mem_pkg::*;
#(
    parameter spec_t SPEC = DEFAULT_MEM_SPEC,
    parameter logic [SPEC.DATA_WID-1:0] RESET_VAL = '0,
    parameter bit FAST_INIT = 0
) (
    mem_intf.peripheral mem_if_0,
    mem_intf.peripheral mem_if_1
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int WR_PIPELINE_STAGES = get_ram_wr_latency(SPEC) - 1;
    localparam int RD_PIPELINE_STAGES = get_ram_rd_latency(SPEC) - 1;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [SPEC.ADDR_WID-1:0] addr_t;
    typedef logic [SPEC.DATA_WID-1:0] data_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic  wr_req [2];
    addr_t wr_addr[2];
    data_t wr_data[2];

    logic  wr_ack [2];
    logic  rd_ack [2];
    data_t rd_data[2];

    // -----------------------------
    // RAM declaration
    // -----------------------------
    data_t mem [addr_t];

    // -----------------------------
    // Request pipeline
    // -----------------------------
    generate
        if (WR_PIPELINE_STAGES > 0) begin : g__wr_pipe
            // (Local) Signals
            logic  wr_req_p  [2][WR_PIPELINE_STAGES];
            addr_t wr_addr_p [2][WR_PIPELINE_STAGES];
            data_t wr_data_p [2][WR_PIPELINE_STAGES];

            // Port 0
            initial wr_req_p[0] = '{WR_PIPELINE_STAGES{1'b0}};
            always @(posedge mem_if_0.clk) begin
                for (int i = 1; i < WR_PIPELINE_STAGES; i++) begin
                    wr_req_p [0][i] <= wr_req_p [0][i-1];
                    wr_addr_p[0][i] <= wr_addr_p[0][i-1];
                    wr_data_p[0][i] <= wr_data_p[0][i-1];
                end
                wr_req_p [0][0] <= mem_if_0.req && mem_if_0.wr;
                wr_addr_p[0][0] <= mem_if_0.addr;
                wr_data_p[0][0] <= mem_if_0.wr_data;
            end
            assign wr_req [0] = wr_req_p [0][WR_PIPELINE_STAGES-1];
            assign wr_addr[0] = wr_addr_p[0][WR_PIPELINE_STAGES-1];
            assign wr_data[0] = wr_data_p[0][WR_PIPELINE_STAGES-1];
            
            // Port 1
            initial wr_req_p[1] = '{WR_PIPELINE_STAGES{1'b0}};
            always @(posedge mem_if_1.clk) begin
                for (int i = 1; i < WR_PIPELINE_STAGES; i++) begin
                    wr_req_p [1][i] <= wr_req_p [1][i-1];
                    wr_addr_p[1][i] <= wr_addr_p[1][i-1];
                    wr_data_p[1][i] <= wr_data_p[1][i-1];
                end
                wr_req_p [1][0] <= mem_if_1.req && mem_if_1.wr;
                wr_addr_p[1][0] <= mem_if_1.addr;
                wr_data_p[1][0] <= mem_if_1.wr_data;
            end
            assign wr_req [1] = wr_req_p [1][WR_PIPELINE_STAGES-1];
            assign wr_addr[1] = wr_addr_p[1][WR_PIPELINE_STAGES-1];
            assign wr_data[1] = wr_data_p[1][WR_PIPELINE_STAGES-1];
        end : g__wr_pipe
        else begin : g__wr_no_pipe
            // Port 0
            assign wr_req [0] = mem_if_0.req && mem_if_0.wr;
            assign wr_addr[0] = mem_if_0.addr;
            assign wr_data[0] = mem_if_0.wr_data;
            // Port 1
            assign wr_req [1] = mem_if_1.req && mem_if_1.wr;
            assign wr_addr[1] = mem_if_1.addr;
            assign wr_data[1] = mem_if_1.wr_data;
        end : g__wr_no_pipe
    endgenerate

    // Write ACK
    initial wr_ack[0] = 1'b0;
    always @(posedge mem_if_0.clk) wr_ack[0] <= wr_req[0];
    assign mem_if_0.wr_ack = wr_ack[0];

    initial wr_ack[1] = 1'b0;
    always @(posedge mem_if_1.clk) wr_ack[1] <= wr_req[1];
    assign mem_if_1.wr_ack = wr_ack[1];

    // RAM is always ready
    assign mem_if_0.rdy = 1'b1;
    assign mem_if_1.rdy = 1'b1;

    // -----------------------------
    // SDP RAM logic
    // -----------------------------
    always @(posedge mem_if_0.clk) begin
        if (SPEC.RESET_FSM && FAST_INIT && mem_if_0.rst) mem.delete();
        else begin
            if (mem_if_0.req) begin
                if (mem.exists(mem_if_0.addr))        rd_data[0] <= mem[mem_if_0.addr];
                else if (SPEC.RESET_FSM && FAST_INIT) rd_data[0] <= RESET_VAL;
                else                                  rd_data[0] <= 'x;
            end
            if (wr_req[0]) mem[wr_addr[0]] = wr_data[0];
        end
    end
    always @(posedge mem_if_1.clk) begin
        if (mem_if_1.req) begin
            if (mem.exists(mem_if_1.addr))        rd_data[1] <= mem[mem_if_1.addr];
            else if (SPEC.RESET_FSM && FAST_INIT) rd_data[1] <= RESET_VAL;
            else                                  rd_data[1] <= 'x;
        end
        if (wr_req[1]) mem[wr_addr[1]] = wr_data[1];
    end
    
    // Read ACK
    initial rd_ack[0] = 1'b0;
    always @(posedge mem_if_0.clk) rd_ack[0] <= mem_if_0.req && !mem_if_0.wr;

    initial rd_ack[1] = 1'b0;
    always @(posedge mem_if_1.clk) rd_ack[1] <= mem_if_1.req && !mem_if_1.wr;

    // -----------------------------
    // Read response pipeline
    // -----------------------------
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            // (Local) Signals
            logic  rd_ack_p  [2][RD_PIPELINE_STAGES];
            data_t rd_data_p [2][RD_PIPELINE_STAGES];

            // Port 0
            initial rd_ack_p[0] = '{RD_PIPELINE_STAGES{1'b0}};
            always @(posedge mem_if_0.clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_ack_p [0][i] <= rd_ack_p [0][i-1];
                    rd_data_p[0][i] <= rd_data_p[0][i-1];
                end
                rd_ack_p [0][0] <= rd_ack [0];
                rd_data_p[0][0] <= rd_data[0];
            end
            assign mem_if_0.rd_ack  = rd_ack_p [0][RD_PIPELINE_STAGES-1];
            assign mem_if_0.rd_data = rd_data_p[0][RD_PIPELINE_STAGES-1];

            // Port 1
            initial rd_ack_p[1] = '{RD_PIPELINE_STAGES{1'b0}};
            always @(posedge mem_if_0.clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_ack_p [1][i] <= rd_ack_p [1][i-1];
                    rd_data_p[1][i] <= rd_data_p[1][i-1];
                end
                rd_ack_p [1][0] <= rd_ack [1];
                rd_data_p[1][0] <= rd_data[1];
            end
            assign mem_if_1.rd_ack  = rd_ack_p [1][RD_PIPELINE_STAGES-1];
            assign mem_if_1.rd_data = rd_data_p[1][RD_PIPELINE_STAGES-1];
        end : g__rd_pipe
        else begin : g__rd_no_pipe
            // Port 0
            assign mem_if_0.rd_ack  = rd_ack [0];
            assign mem_if_0.rd_data = rd_data[0];
            // Port 1
            assign mem_if_1.rd_ack  = rd_ack [1];
            assign mem_if_1.rd_data = rd_data[1];
        end : g__rd_no_pipe
    endgenerate

endmodule : sim__mem_ram_tdp_model

`endif // ifndef SYNTHESIS
