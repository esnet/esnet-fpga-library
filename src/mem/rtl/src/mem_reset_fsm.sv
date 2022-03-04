// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

module mem_reset_fsm #(
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 8,
    parameter bit [DATA_WID-1:0] RESET_VAL = 0,
    parameter bit SIM__FAST_INIT = 0 // Optimize sim time
) (
    // Clock/reset
    input  logic            wr_clk,
    input  logic            wr_srst,

    output logic            init_done,

    // Memory interface (from application)
    mem_intf.wr_peripheral  mem_wr_if_in,

    // Memory interface (to memory)
    mem_intf.wr_controller  mem_wr_if_out
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
        DONE
    } state_t;

    // -----------------------------
    // SIGNALS
    // -----------------------------
    logic                reset;

    state_t              state;
    state_t              state_nxt;
    logic                addr_reset;
    logic [ADDR_WID-1:0] addr;

    logic                reset_done;

    // -----------------------------
    // RTL
    // -----------------------------
    // Combine block and 'soft' reset inputs
    assign reset = wr_srst || mem_wr_if_in.rst;

    // Reset state machine
    // - zeroes all memory entries in response to block-level reset
    initial state = RESET;
    always @(posedge wr_clk) begin
        if (reset) state <= RESET;
        else       state <= state_nxt;
    end

    always_comb begin
        state_nxt = state;
        addr_reset = 1'b0;
        case (state)
            RESET : begin
                addr_reset = 1'b1;
                state_nxt = CLEAR;
            end
            CLEAR : begin
`ifdef SIMULATION
            if (SIM__FAST_INIT) begin
                if (addr == SIM__FAST_INIT_DEPTH) state_nxt = DONE;
            end else
`endif
                if (addr == DEPTH-1) state_nxt = DONE;
            end
            DONE : begin
                addr_reset = 1'b1;
            end
            default : begin
                state_nxt = RESET;
            end
        endcase
    end

    // State variable for auto-clearing counters on reset (or explicit command)
    initial addr = '0;
    always @(posedge wr_clk) begin
        if (addr_reset) addr <= '0;
        else            addr <= addr + 1;
    end

    // Reset done
    initial reset_done = 1'b0;
    always @(posedge wr_clk) begin
        if (reset)                  reset_done <= 1'b0;
        else if (state_nxt == DONE) reset_done <= 1'b1;
        else                        reset_done <= 1'b0;
    end

    // Peripheral is ready to accept transactions when reset operation has completed
    assign mem_wr_if_in.rdy = reset_done;
    assign mem_wr_if_in.ack = mem_wr_if_out.ack;

    // Mux between reset and regular transactions
    assign mem_wr_if_out.rst  = reset;
    assign mem_wr_if_out.en   = reset_done ? mem_wr_if_in.en   : (state == CLEAR);
    assign mem_wr_if_out.req  = reset_done ? mem_wr_if_in.req  : (state == CLEAR);
    assign mem_wr_if_out.addr = reset_done ? mem_wr_if_in.addr : addr;
    assign mem_wr_if_out.data = reset_done ? mem_wr_if_in.data : RESET_VAL;

    // Drive outputs
    assign init_done = (state == DONE);

endmodule : mem_reset_fsm
