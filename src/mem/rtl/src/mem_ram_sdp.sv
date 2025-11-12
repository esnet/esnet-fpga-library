// Simple Dual-Port RAM implementation
// NOTE: This module provides a simple dual-port (SDP) RAM implementation
//       with standard interfaces and built-in reset FSM.
module mem_ram_sdp
    import mem_pkg::*;
#(
    spec_t SPEC = DEFAULT_MEM_SPEC,
    parameter logic [SPEC.DATA_WID-1:0] RESET_VAL = '0,
    // Simulation parameters
    parameter bit SIM__FAST_INIT = 0, // Fast init in simulations
    parameter bit SIM__RAM_MODEL = 0  // Use model for RAM (associative array) in sims
) (
    // Write interface
    mem_wr_intf.peripheral mem_wr_if,

    // Read interface
    mem_rd_intf.peripheral mem_rd_if
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int DEPTH = 2**SPEC.ADDR_WID;

    localparam int WR_LATENCY_RAM = get_ram_wr_latency(SPEC);
    localparam int RD_LATENCY_RAM = get_ram_rd_latency(SPEC);
    localparam int WR_LATENCY = get_wr_latency(SPEC);
    localparam int RD_LATENCY = get_rd_latency(SPEC);

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [SPEC.ADDR_WID-1:0] addr_t;
    typedef logic [SPEC.DATA_WID-1:0] data_t;

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_wr_intf #(.ADDR_WID(SPEC.ADDR_WID), .DATA_WID(SPEC.DATA_WID)) __mem_wr_if (.clk(mem_wr_if.clk));
    mem_rd_intf #(.ADDR_WID(SPEC.ADDR_WID), .DATA_WID(SPEC.DATA_WID)) __mem_rd_if (.clk(mem_rd_if.clk));

    // -----------------------------
    // Reset FSM (optional)
    // -----------------------------
    generate
        if (SPEC.RESET_FSM) begin : g__reset_fsm
            // Reset FSM
            // - on reset deassertion, auto-clears memory by
            //   sequentially writing RESET_VAL to each memory element
            mem_reset_fsm     #(
                .ADDR_WID      ( SPEC.ADDR_WID ),
                .DATA_WID      ( SPEC.DATA_WID ),
                .RESET_VAL     ( RESET_VAL ),
                .SIM__FAST_INIT( SIM__FAST_INIT )
            ) i_mem_reset_fsm  (
                .mem_wr_if_in  ( mem_wr_if ),
                .mem_wr_if_out ( __mem_wr_if )
            );

            // Read interface is ready when init is complete
            if (SPEC.ASYNC) begin : g__async
                // Synchronize ready from write clock domain to read clock domain
                sync_level #(
                    .RST_VALUE ( 1'b0 )
                ) i_sync_level__rdy (
                    .clk_in  ( mem_wr_if.clk ),
                    .rst_in  ( mem_wr_if.rst ),
                    .rdy_in  ( ),
                    .lvl_in  ( mem_wr_if.rdy ),
                    .clk_out ( mem_rd_if.clk ),
                    .rst_out ( 1'b0 ),
                    .lvl_out ( mem_rd_if.rdy )
                );

                // Map read request signals directly
                assign __mem_rd_if.req = mem_rd_if.req;
                assign __mem_rd_if.addr = mem_rd_if.addr;
            end : g__async
            else begin : g__sync
                // No need to synchronize ready signal
                assign mem_rd_if.rdy = mem_wr_if.rdy;

                if (SPEC.OPT_MODE == OPT_MODE_TIMING) begin : g__rd_req_pipe
                    // Pipeline read request to maintain relative
                    // synchronization with write request interface
                    initial __mem_rd_if.req = 1'b0;
                    always @(posedge mem_wr_if.clk) begin
                        __mem_rd_if.req <= mem_rd_if.req;
                        __mem_rd_if.addr <= mem_rd_if.addr;
                    end
                end : g__rd_req_pipe
                else begin : g__rd_req_no_pipe
                    // For all other optimization modes, write request interface
                    // is not pipelined, so no need to pipeline read request
                    assign __mem_rd_if.req = mem_rd_if.req;
                    assign __mem_rd_if.addr = mem_rd_if.addr;
                end : g__rd_req_no_pipe
            end : g__sync

            // Map remaining read interface signals
            assign __mem_rd_if.rst = mem_rd_if.rst;
            assign mem_rd_if.data = __mem_rd_if.data;
            assign mem_rd_if.ack = __mem_rd_if.ack;

        end : g__reset_fsm
        else begin : g__no_reset_fsm
            // No reset FSM
            // - drive write interface directly
            //   (pass interfaces along unmodified)
            mem_wr_intf_connector i_mem_wr_intf_connector (
                .from_controller ( mem_wr_if ),
                .to_peripheral   ( __mem_wr_if )
            );
            mem_rd_intf_connector i_mem_rd_intf_connector (
                .from_controller ( mem_rd_if ),
                .to_peripheral   ( __mem_rd_if )
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
            sim__mem_ram_sdp_model  #(
                .SPEC           ( SPEC ),
                .RESET_VAL      ( RESET_VAL ),
                .FAST_INIT      ( SIM__FAST_INIT )
            ) i_sim__mem_ram_sdp_model (
                .mem_wr_if ( __mem_wr_if ),
                .mem_rd_if ( __mem_rd_if )
            );
        end : g__ram_model
        else begin : g__ram
`endif // ifndef SYNTHESIS

    // -----------------------------
    // RAM declaration
    // -----------------------------
    xilinx_ram_sdp #(
        .ADDR_WID ( SPEC.ADDR_WID ),
        .DATA_WID ( SPEC.DATA_WID ),
        .ASYNC    ( SPEC.ASYNC ),
        .OPT_MODE ( translate_opt_mode(SPEC.OPT_MODE) )
    ) i_xilinx_ram_sdp (
        .wr_clk  ( __mem_wr_if.clk ),
`ifndef SYNTHESIS
        .wr_srst ( SIM__FAST_INIT && mem_wr_if.rst ),
`endif
        .wr_en   ( __mem_wr_if.en ),
        .wr_req  ( __mem_wr_if.req ),
        .wr_addr ( __mem_wr_if.addr ),
        .wr_data ( __mem_wr_if.data ),
        .wr_ack  ( __mem_wr_if.ack ),
        .rd_clk  ( __mem_rd_if.clk ),
        .rd_en   ( __mem_rd_if.req ),
        .rd_addr ( __mem_rd_if.addr ),
        .rd_data ( __mem_rd_if.data ),
        .rd_ack  ( __mem_rd_if.ack )
    );

    // Base RAM is always ready
    assign __mem_wr_if.rdy = 1'b1;
    assign __mem_rd_if.rdy = 1'b1;

    // Check for expected write/read latencies
    initial begin
        std_pkg::param_check(WR_LATENCY_RAM, i_xilinx_ram_sdp.WR_LATENCY, "WR_LATENCY");
        std_pkg::param_check(RD_LATENCY_RAM, i_xilinx_ram_sdp.RD_LATENCY, "RD_LATENCY");
    end

`ifndef SYNTHESIS
        end : g__ram
    endgenerate
`endif // ifndef SYNTHESIS

endmodule : mem_ram_sdp

//
// -------------- RAM model for simulations only ------------------
//
`ifndef SYNTHESIS

module sim__mem_ram_sdp_model
    import mem_pkg::*;
#(
    parameter spec_t SPEC = DEFAULT_MEM_SPEC,
    parameter logic [SPEC.DATA_WID-1:0] RESET_VAL = '0,
    parameter bit FAST_INIT = 0
) (
    mem_wr_intf.peripheral mem_wr_if,
    mem_rd_intf.peripheral mem_rd_if
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
    logic  wr_en;
    logic  wr_req;
    addr_t wr_addr;
    data_t wr_data;

    logic  rd_ack;
    data_t rd_data;

    // -----------------------------
    // RAM declaration
    // -----------------------------
    data_t mem [addr_t];

    // -----------------------------
    // Write request pipeline
    // -----------------------------
    generate
        if (WR_PIPELINE_STAGES > 0) begin : g__wr_pipe
            // (Local) Signals
            logic  wr_en_p [WR_PIPELINE_STAGES];
            logic  wr_req_p [WR_PIPELINE_STAGES];
            addr_t wr_addr_p [WR_PIPELINE_STAGES];
            data_t wr_data_p [WR_PIPELINE_STAGES];

            initial begin
                wr_en_p = '{WR_PIPELINE_STAGES{1'b0}};
                wr_req_p = '{WR_PIPELINE_STAGES{1'b0}};
            end
            always @(posedge mem_wr_if.clk) begin
                for (int i = 1; i < WR_PIPELINE_STAGES; i++) begin
                    wr_en_p[i] <= wr_en_p[i-1];
                    wr_req_p[i] <= wr_req_p[i-1];
                    wr_addr_p[i] <= wr_addr_p[i-1];
                    wr_data_p[i] <= wr_data_p[i-1];
                end
                wr_en_p[0] <= mem_wr_if.en;
                wr_req_p[0] <= mem_wr_if.req;
                wr_addr_p[0] <= mem_wr_if.addr;
                wr_data_p[0] <= mem_wr_if.data;
            end

            assign wr_en = wr_en_p[WR_PIPELINE_STAGES-1];
            assign wr_req = wr_req_p[WR_PIPELINE_STAGES-1];
            assign wr_addr = wr_addr_p[WR_PIPELINE_STAGES-1];
            assign wr_data = wr_data_p[WR_PIPELINE_STAGES-1];
        end : g__wr_pipe
        else begin : g__wr_no_pipe
            assign wr_en = mem_wr_if.en;
            assign wr_req = mem_wr_if.req;
            assign wr_addr = mem_wr_if.addr;
            assign wr_data = mem_wr_if.data;
        end : g__wr_no_pipe
    endgenerate

    // Write ACK
    initial mem_wr_if.ack = 1'b0;
    always @(posedge mem_wr_if.clk) mem_wr_if.ack <= wr_en && wr_req;

    // RAM is always ready
    assign mem_wr_if.rdy = 1'b1;

    // -----------------------------
    // SDP RAM logic
    // -----------------------------
    if (SPEC.ASYNC) begin : g__async
        always @(posedge mem_wr_if.clk) begin
            if (SPEC.RESET_FSM && FAST_INIT && mem_wr_if.rst) mem.delete();
            else if (wr_en) begin
                if (wr_req) mem[wr_addr] = wr_data;
            end
        end
        always @(posedge mem_rd_if.clk) begin
            if (mem_rd_if.req) begin
                if (mem.exists(mem_rd_if.addr))       rd_data <= mem[mem_rd_if.addr];
                else if (SPEC.RESET_FSM && FAST_INIT) rd_data <= RESET_VAL;
                else                                  rd_data <= 'x;
            end
        end
    end : g__async
    else begin : g__sync
        always @(posedge mem_wr_if.clk) begin
            if (mem_rd_if.req) begin
                if (mem.exists(mem_rd_if.addr))       rd_data <= mem[mem_rd_if.addr];
                else if (SPEC.RESET_FSM && FAST_INIT) rd_data <= RESET_VAL;
                else                                  rd_data <= 'x;
            end
            if (SPEC.RESET_FSM && FAST_INIT && mem_wr_if.rst) mem.delete();
            else if (wr_en) begin
                if (wr_req) mem[wr_addr] = wr_data;
            end
        end
    end : g__sync

    // Read ACK
    initial rd_ack = 1'b0;
    always @(posedge mem_rd_if.clk) rd_ack <= mem_rd_if.req;

    // RAM is always ready
    assign mem_rd_if.rdy = 1'b1;

    // -----------------------------
    // Read response pipeline
    // -----------------------------
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            // (Local) Signals
            logic  rd_ack_p [RD_PIPELINE_STAGES];
            data_t rd_data_p [RD_PIPELINE_STAGES];

            initial begin
                rd_ack_p = '{RD_PIPELINE_STAGES{1'b0}};
            end
            always @(posedge mem_rd_if.clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_ack_p[i] <= rd_ack_p[i-1];
                    rd_data_p[i] <= rd_data_p[i-1];
                end
                rd_ack_p[0] <= rd_ack;
                rd_data_p[0] <= rd_data;
            end

            assign mem_rd_if.ack = rd_ack_p[RD_PIPELINE_STAGES-1];
            assign mem_rd_if.data = rd_data_p[RD_PIPELINE_STAGES-1];
        end : g__rd_pipe
        else begin : g__rd_no_pipe
            assign mem_rd_if.ack = rd_ack;
            assign mem_rd_if.data = rd_data;
        end : g__rd_no_pipe
    endgenerate

endmodule : sim__mem_ram_sdp_model

`endif // ifndef SYNTHESIS
