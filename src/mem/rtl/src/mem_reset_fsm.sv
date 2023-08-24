module mem_reset_fsm
    import mem_pkg::*;
#(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 8,
    parameter opt_mode_t OPT_MODE = OPT_MODE_TIMING,
    parameter bit [DATA_WID-1:0] RESET_VAL = 0,
    parameter bit SIM__FAST_INIT = 0 // Optimize sim time
) (
    // Memory interface (from application)
    mem_wr_intf.peripheral  mem_wr_if_in,

    // Memory interface (to memory)
    mem_wr_intf.controller  mem_wr_if_out
);

    // -----------------------------
    // PARAMETERS
    // -----------------------------
    localparam int DEPTH = 2**ADDR_WID;

    localparam int SIM__FAST_INIT_DEPTH = DEPTH > 16 ? 16 : DEPTH-1;

    // -----------------------------
    // TYPEDEFS
    // -----------------------------
    typedef enum logic [1:0] {
        RESET,
        CLEAR,
        CLEAR_DONE,
        INIT_DONE
    } state_t;

    // -----------------------------
    // SIGNALS
    // -----------------------------
    state_t              state;
    state_t              state_nxt;
    logic                addr_reset;
    logic [ADDR_WID-1:0] addr;

    logic                init_done;

    // -----------------------------
    // RTL
    // -----------------------------

    // Reset state machine
    // - zeroes all memory entries in response to block-level reset
    initial state = RESET;
    always @(posedge mem_wr_if_in.clk) begin
        if (mem_wr_if_in.rst) state <= RESET;
        else                  state <= state_nxt;
    end

    always_comb begin
        state_nxt = state;
        addr_reset = 1'b1;
        init_done = 1'b0;
        case (state)
            RESET : begin
                if (mem_wr_if_out.rdy) state_nxt = CLEAR;
            end
            CLEAR : begin
                addr_reset = 1'b0;
`ifndef SYNTHESIS
            if (SIM__FAST_INIT) begin
                if (addr == SIM__FAST_INIT_DEPTH) state_nxt = CLEAR_DONE;
            end else
`endif // ifndef SYNTHESIS
                if (addr == DEPTH-1) state_nxt = CLEAR_DONE;
            end
            CLEAR_DONE : begin
                if (!mem_wr_if_out.ack) state_nxt = INIT_DONE; // Flush write acks from auto-clear operation
            end
            INIT_DONE : begin
                init_done = 1'b1;
            end
        endcase
    end

    // Address state variable (cycle through all addresses to clear)
    initial addr = '0;
    always @(posedge mem_wr_if_in.clk) begin
        if (addr_reset) addr <= '0;
        else            addr <= addr + 1;
    end

    // Synthesize rdy output (indicates that initialization procedure is complete)
    initial mem_wr_if_in.rdy = 1'b0;
    always @(posedge mem_wr_if_in.clk) begin
        if (mem_wr_if_in.rst) mem_wr_if_in.rdy <= 1'b0;
        else                  mem_wr_if_in.rdy <= init_done;
    end

    // Mux between reset and regular transactions
    assign mem_wr_if_out.rst  = mem_wr_if_in.rst;

    // Peripheral is ready to accept transactions when reset operation has completed
    assign mem_wr_if_in.ack = mem_wr_if_in.rdy ? mem_wr_if_out.ack : 1'b0;

    generate
        if (OPT_MODE == OPT_MODE_TIMING) begin : g__wr_pipe
            // Pipeline write request (timing-optimized)
            // - Control
            initial begin
                mem_wr_if_out.en  = 1'b0;
                mem_wr_if_out.req = 1'b0;
            end
            always @(posedge mem_wr_if_in.clk) begin
                if (mem_wr_if_in.rst) begin
                    mem_wr_if_out.en <= 1'b0;
                    mem_wr_if_out.req <= 1'b0;
                end else begin
                    if (mem_wr_if_in.rdy) begin
                        mem_wr_if_out.en <= mem_wr_if_in.en;
                        mem_wr_if_out.req <= mem_wr_if_in.req;
                    end else begin
                        mem_wr_if_out.en <= (state == CLEAR);
                        mem_wr_if_out.req <= (state == CLEAR);
                    end
                end
            end
            
            // - Data
            always_ff @(posedge mem_wr_if_in.clk) begin
                if (mem_wr_if_in.rdy) begin
                    mem_wr_if_out.addr <= mem_wr_if_in.addr;
                    mem_wr_if_out.data <= mem_wr_if_in.data;
                end else begin
                    mem_wr_if_out.addr <= addr;
                    mem_wr_if_out.data <= RESET_VAL;
                end
            end
        end : g__wr_pipe
        else begin : g__wr_no_pipe
            // Don't pipeline (latency-optimized)
            assign mem_wr_if_out.en  = mem_wr_if_in.rdy ? mem_wr_if_in.en : (state == CLEAR);
            assign mem_wr_if_out.req = mem_wr_if_in.rdy ? mem_wr_if_in.req : (state == CLEAR);
            assign mem_wr_if_out.addr = mem_wr_if_in.rdy ? mem_wr_if_in.addr : addr;
            assign mem_wr_if_out.data = mem_wr_if_in.rdy ? mem_wr_if_in.data : RESET_VAL;
        end : g__wr_no_pipe
    endgenerate

endmodule : mem_reset_fsm
