module apb_peripheral #(
    parameter int DATA_BYTE_WIDTH = 4,
    parameter int ADDR_WID = 32
) (
    // Upstream (APB)
    apb_intf.peripheral  apb_if,

    // Downstream (register access)
    reg_intf.controller  reg_if
);
    // ============================
    // Typedefs
    // ============================
    typedef enum logic [1:0] {
        RESET,
        IDLE,
        WRITE,
        READ
    } state_t;

    // ============================
    // Signals
    // ============================
    state_t state;
    state_t nxt_state;

    // ============================
    // RTL
    // ============================
    // Clock
    assign reg_if.clk = apb_if.pclk;

    // Reset
    initial reg_if.srst = 1'b1;
    always @(posedge apb_if.pclk) begin
        if (!apb_if.presetn) reg_if.srst <= 1'b1;
        else                 reg_if.srst <= 1'b0;
    end

    // Transaction state machine
    initial state = RESET;
    always @(posedge apb_if.pclk) begin
        if (!apb_if.presetn) state <= RESET;
        else                 state <= nxt_state;
    end

    always_comb begin
        reg_if.wr = 1'b0;
        reg_if.rd = 1'b0;
        case (state)
            RESET : begin
                nxt_state = IDLE;
            end
            IDLE : begin
                if (apb_if.psel) begin
                    if (apb_if.pwrite) nxt_state = WRITE;
                    else               nxt_state = READ;
                end
            end
            WRITE: begin
                reg_if.wr = apb_if.penable;
                if (reg_if.wr_ack) nxt_state = IDLE;
            end
            READ : begin
                reg_if.rd = apb_if.penable;
                if (reg_if.rd_ack) nxt_state = IDLE;
            end
        endcase
    end

    // Write setup
    always_ff @(posedge apb_if.pclk) begin
        if (state == IDLE && apb_if.psel && apb_if.pwrite) begin
            reg_if.wr_addr    <= apb_if.paddr;
            reg_if.wr_data    <= apb_if.pwdata;
            reg_if.wr_byte_en <= apb_if.pstrb;
        end
    end

    // Read setup
    always_ff @(posedge apb_if.pclk) begin
        if (state == IDLE && apb_if.psel && !apb_if.pwrite) begin
            reg_if.rd_addr <= apb_if.paddr;
        end
    end

    // Response
    always_comb begin
        apb_if.pready = 1'b0;
        apb_if.pslverr = 1'b0;
        if (state == WRITE) begin
            apb_if.pready = reg_if.wr_ack;
            apb_if.pslverr = reg_if.wr_error;
        end else if (state == READ) begin
            apb_if.pready = reg_if.rd_ack;
            apb_if.pslverr = reg_if.rd_error;
        end
    end

    // Read data
    assign apb_if.prdata = reg_if.rd_data;

endmodule : apb_peripheral
