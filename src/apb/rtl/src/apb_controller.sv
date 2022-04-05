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

module apb_controller #(
    parameter int WR_TIMEOUT = 256, // Write timeout in clock cycles; set to 0 to disable
    parameter int RD_TIMEOUT = 256  // Read timeout in clock cycles; set to 0 to disable
) (
    // Upstream (register control)
    reg_intf.peripheral reg_if,
    // Downstream (APB)
    apb_intf.controller apb_if
);

    // ============================
    // Imports
    // ============================
    import apb_pkg::*;

    // ============================
    // Typedefs
    // ============================
    typedef enum logic [2:0] {
        RESET,
        IDLE,
        WRITE_SETUP,
        READ_SETUP,
        WRITE,
        READ
    } state_t;

    // ============================
    // Parameters
    // ============================
    localparam int DATA_BYTE_WID = reg_if.DATA_BYTE_WID;
    localparam int ADDR_WID = reg_if.ADDR_WID;

    localparam int TIMER_WID = WR_TIMEOUT > RD_TIMEOUT ? $clog2(WR_TIMEOUT) : (RD_TIMEOUT > 0 ? $clog2(RD_TIMEOUT) : 1);

    // ============================
    // Signals
    // ============================
    state_t state;
    state_t nxt_state;

    logic [ADDR_WID-1:0]           paddr_reg;
    logic [DATA_BYTE_WID-1:0][7:0] pwdata_reg;
    logic [DATA_BYTE_WID-1:0]      pstrb_reg;

    logic                 timer_reset;
    logic                 timer_inc;
    logic [TIMER_WID-1:0] timer;
    logic                 wr_timeout;
    logic                 rd_timeout;

    // Clock/reset
    // --------------------
    assign apb_if.pclk = reg_if.clk;

    initial apb_if.presetn = 1'b0;
    always @(posedge reg_if.clk) begin
        if (reg_if.srst) apb_if.presetn <= 1'b0;
        else             apb_if.presetn <= 1'b1;
    end

    // Transaction state machine
    initial state = RESET;
    always @(posedge reg_if.clk) begin
        if (reg_if.srst) state <= RESET;
        else             state <= nxt_state;
    end

    always_comb begin
        apb_if.psel = 1'b0;
        apb_if.pwrite = 1'b0;
        apb_if.penable = 1'b0;
        apb_if.paddr = paddr_reg;
        apb_if.pwdata = pwdata_reg;
        apb_if.pstrb = pstrb_reg;
        timer_inc = 1'b0;
        timer_reset = 1'b1;
        nxt_state = state;
        case (state)
            RESET : begin
                timer_reset = 1'b1;
                nxt_state = IDLE;
            end
            IDLE : begin
                timer_reset = 1'b1;
                if (reg_if.wr) nxt_state = WRITE_SETUP;
                else if (reg_if.rd) nxt_state = READ_SETUP;
            end
            WRITE_SETUP : begin
                timer_reset = 1'b1;
                apb_if.psel = 1'b1;
                apb_if.pwrite = 1'b1;
                apb_if.paddr = reg_if.wr_addr;
                apb_if.pwdata = reg_if.wr_data;
                apb_if.pstrb = reg_if.wr_byte_en;
                nxt_state = WRITE;
            end
            READ_SETUP : begin
                timer_reset = 1'b1;
                apb_if.psel = 1'b1;
                apb_if.paddr = reg_if.rd_addr;
                nxt_state = READ;
            end
            WRITE : begin
                timer_inc = 1'b1;
                apb_if.psel = 1'b1;
                apb_if.pwrite = 1'b1;
                apb_if.penable = 1'b1;
                if (apb_if.pready || wr_timeout) nxt_state = IDLE;
            end
            READ : begin
                apb_if.psel = 1'b1;
                apb_if.penable = 1'b1;
                if (apb_if.pready || rd_timeout) nxt_state = IDLE;
            end
            default : begin
                nxt_state = RESET;
            end
        endcase
    end

    // Register address
    always_ff @(posedge apb_if.pclk) paddr_reg <= apb_if.paddr;

    // Register write data
    always_ff @(posedge apb_if.pclk) begin
        pwdata_reg <= apb_if.pwdata;
        pstrb_reg <= apb_if.pstrb;
    end
    assign apb_if.pprot = PPROT_DEFAULT;

    // Timer
    initial timer = '0;
    always @(posedge reg_if.clk) begin
        if (timer_reset) timer <= '0;
        else if (timer_inc) timer <= timer + 1;
    end
    assign wr_timeout = WR_TIMEOUT == 0 ? 1'b0 : (timer == WR_TIMEOUT-1);   
    assign rd_timeout = RD_TIMEOUT == 0 ? 1'b0 : (timer == RD_TIMEOUT-1);   

    // Response
    always_comb begin
        reg_if.wr_ack = 1'b0;
        reg_if.wr_error = 1'b0;
        reg_if.rd_ack = 1'b0;
        reg_if.rd_error = 1'b0;
        reg_if.rd_data = reg_pkg::BAD_ACCESS_DATA;
        if (state == WRITE) begin
            if (apb_if.pready) begin
                reg_if.wr_ack = 1'b1;
                reg_if.wr_error = apb_if.pslverr;
            end else if (wr_timeout) begin
                reg_if.wr_ack = 1'b1;
                reg_if.wr_error = 1'b1;
            end
        end else if (state == READ) begin
            if (apb_if.pready) begin
                reg_if.rd_ack = 1'b1;
                reg_if.rd_error = apb_if.pslverr;
                if (!apb_if.pslverr) reg_if.rd_data = apb_if.prdata;
            end else if (rd_timeout) begin
                reg_if.rd_ack = 1'b1;
                reg_if.rd_error = 1'b1;
            end
        end
    end

endmodule : apb_controller
