// Single-Port RAM implementation
// NOTE: This module provides a single-port (SP) RAM implementation
//       with standard interfaces and built-in reset FSM.
module mem_ram_sp
    import mem_pkg::*;
#(
    spec_t SPEC = DEFAULT_MEM_SPEC,
    parameter logic [SPEC.DATA_WID-1:0] RESET_VAL = '0,
    // Simulation parameters
    parameter bit SIM__FAST_INIT = 0, // Fast init in simulations
    parameter bit SIM__RAM_MODEL = 0  // Use model for RAM (associative array) in sims
) (
    mem_intf.peripheral mem_if
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
    mem_intf #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) __mem_if (.clk(mem_if.clk));

    // -----------------------------
    // Reset FSM (optional)
    // -----------------------------
    generate
        if (SPEC.RESET_FSM) begin : g__reset_fsm
            // (Local) interfaces
            mem_wr_intf #(.ADDR_WID(SPEC.ADDR_WID), .DATA_WID(SPEC.DATA_WID)) __mem_wr_if_in  (.clk(mem_if.clk));
            mem_wr_intf #(.ADDR_WID(SPEC.ADDR_WID), .DATA_WID(SPEC.DATA_WID)) __mem_wr_if_out (.clk(mem_if.clk));
            // Map from full memory interface to write-only interface
            assign __mem_wr_if_in.rst = mem_if.rst;
            assign __mem_wr_if_in.en = mem_if.wr;
            assign __mem_wr_if_in.req = mem_if.req;
            assign __mem_wr_if_in.addr = mem_if.addr;
            assign __mem_wr_if_in.data = mem_if.wr_data;
            assign mem_if.rdy    = __mem_wr_if_in.rdy;
            assign mem_if.wr_ack = __mem_wr_if_in.ack;

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
            assign __mem_if.rst  = __mem_wr_if_out.rst;
            assign __mem_if.req  = __mem_wr_if_out.req;
            assign __mem_if.wr   = __mem_wr_if_out.en;
            assign __mem_if.addr = __mem_wr_if_out.addr;
            assign __mem_if.wr_data = __mem_wr_if_out.data;
            assign __mem_wr_if_out.rdy = __mem_if.rdy;
            assign __mem_wr_if_out.ack = __mem_if.wr_ack;

            // Map remaining read interface signals
            assign mem_if.rd_ack = __mem_if.rd_ack;
            assign mem_if.rd_data = __mem_if.rd_data;

        end : g__reset_fsm
        else begin : g__no_reset_fsm
            // No reset FSM
            // - drive write interface directly
            //   (pass interface along unmodified)
            mem_intf_connector i_mem_intf_connector (
                .mem_if_from_controller ( mem_if ),
                .mem_if_to_peripheral   ( __mem_if )
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
            sim__mem_ram_sp_model  #(
                .SPEC      ( SPEC ),
                .RESET_VAL ( RESET_VAL ),
                .FAST_INIT ( SIM__FAST_INIT )
            ) i_sim__mem_ram_sp_model (
                .mem_if  ( __mem_if )
            );
        end : g__ram_model
        else begin : g__ram
`endif // ifndef SYNTHESIS

    // -----------------------------
    // RAM declaration
    // -----------------------------
    xilinx_ram_sp #(
        .ADDR_WID   ( SPEC.ADDR_WID ),
        .DATA_WID   ( SPEC.DATA_WID ),
        .OPT_MODE   ( translate_opt_mode(SPEC.OPT_MODE) )
    ) i_xilinx_ram_sp (
        .clk      ( __mem_if.clk ),
`ifndef SYNTHESIS
        .srst     ( SIM__FAST_INIT ? mem_if.rst : 1'b0 ),
`endif
        .en       ( __mem_if.req ),
        .wr       ( __mem_if.wr ),
        .addr     ( __mem_if.addr ),
        .wr_data  ( __mem_if.wr_data ),
        .wr_ack   ( __mem_if.wr_ack ),
        .rd_data  ( __mem_if.rd_data ),
        .rd_ack   ( __mem_if.rd_ack )
    );

    // Base RAM is always ready
    assign __mem_if.rdy = 1'b1;

    // Check for expected write/read latencies
    initial begin
        std_pkg::param_check(WR_LATENCY_RAM, i_xilinx_ram_sp.WR_LATENCY, "WR_LATENCY");
        std_pkg::param_check(RD_LATENCY_RAM, i_xilinx_ram_sp.RD_LATENCY, "RD_LATENCY");
    end

`ifndef SYNTHESIS
        end : g__ram
    endgenerate
`endif // ifndef SYNTHESIS

endmodule : mem_ram_sp

//
// -------------- RAM model for simulations only ------------------
//
`ifndef SYNTHESIS

module sim__mem_ram_sp_model
    import mem_pkg::*;
#(
    parameter spec_t SPEC = DEFAULT_MEM_SPEC,
    parameter logic [SPEC.DATA_WID-1:0] RESET_VAL = '0,
    parameter bit FAST_INIT = 0
) (
    mem_intf.peripheral mem_if
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
    logic  clk;

    logic  wr_req;
    addr_t wr_addr;
    data_t wr_data;

    logic  wr_ack;
    logic  rd_ack;
    data_t rd_data;

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
            logic  wr_req_p  [WR_PIPELINE_STAGES];
            addr_t wr_addr_p [WR_PIPELINE_STAGES];
            data_t wr_data_p [WR_PIPELINE_STAGES];

            initial wr_req_p = '{WR_PIPELINE_STAGES{1'b0}};
            always @(posedge mem_if.clk) begin
                for (int i = 1; i < WR_PIPELINE_STAGES; i++) begin
                    wr_req_p [i] <= wr_req_p [i-1];
                    wr_addr_p[i] <= wr_addr_p[i-1];
                    wr_data_p[i] <= wr_data_p[i-1];
                end
                wr_req_p [0] <= mem_if.req && mem_if.wr;
                wr_addr_p[0] <= mem_if.addr;
                wr_data_p[0] <= mem_if.wr_data;
            end
            assign wr_req  = wr_req_p [WR_PIPELINE_STAGES-1];
            assign wr_addr = wr_addr_p[WR_PIPELINE_STAGES-1];
            assign wr_data = wr_data_p[WR_PIPELINE_STAGES-1];
        end : g__wr_pipe
        else begin : g__wr_no_pipe
            assign wr_req  = mem_if.req && mem_if.wr;
            assign wr_addr = mem_if.addr;
            assign wr_data = mem_if.wr_data;
        end : g__wr_no_pipe
    endgenerate

    // Write ACK
    initial wr_ack = 1'b0;
    always @(posedge mem_if.clk) wr_ack <= wr_req;
    assign mem_if.wr_ack = wr_ack;

    // RAM is always ready
    assign mem_if.rdy = 1'b1;

    // -----------------------------
    // SDP RAM logic
    // -----------------------------
    always @(posedge mem_if.clk) begin
        if (SPEC.RESET_FSM && FAST_INIT && mem_if.rst) mem.delete();
        else begin
            if (mem_if.req) begin
                if (mem.exists(mem_if.addr))          rd_data <= mem[mem_if.addr];
                else if (SPEC.RESET_FSM && FAST_INIT) rd_data <= RESET_VAL;
                else                                  rd_data <= 'x;
            end
            if (wr_req) mem[wr_addr] = wr_data;
        end
    end
    
    // Read ACK
    initial rd_ack = 1'b0;
    always @(posedge mem_if.clk) rd_ack <= mem_if.req && !mem_if.wr;

    // -----------------------------
    // Read response pipeline
    // -----------------------------
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            // (Local) Signals
            logic  rd_ack_p  [RD_PIPELINE_STAGES];
            data_t rd_data_p [RD_PIPELINE_STAGES];

            initial rd_ack_p = '{RD_PIPELINE_STAGES{1'b0}};
            always @(posedge mem_if.clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES; i++) begin
                    rd_ack_p [i] <= rd_ack_p [i-1];
                    rd_data_p[i] <= rd_data_p[i-1];
                end
                rd_ack_p [0] <= rd_ack;
                rd_data_p[0] <= rd_data;
            end
            assign mem_if.rd_ack  = rd_ack_p [RD_PIPELINE_STAGES-1];
            assign mem_if.rd_data = rd_data_p[RD_PIPELINE_STAGES-1];
        end : g__rd_pipe
        else begin : g__rd_no_pipe
            assign mem_if.rd_ack  = rd_ack;
            assign mem_if.rd_data = rd_data;
        end : g__rd_no_pipe
    endgenerate

endmodule : sim__mem_ram_sp_model

`endif // ifndef SYNTHESIS
