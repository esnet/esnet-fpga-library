module reg_proxy (
    // AXI4-Lite control interface
    axi4l_intf.peripheral  axil_if,

    // Register control interface
    reg_intf.controller    reg_if
);
    // -------------------------
    // Typedefs
    // -------------------------
    typedef enum logic [2:0] {
        RESET,
        READY,
        WRITE,
        READ,
        WRITE_ACK,
        READ_ACK,
        DONE,
        ERROR
    } state_t;

    // -------------------------
    // Signals
    // -------------------------
    state_t state;
    state_t nxt_state;

    logic [31:0] rd_data;

    // -------------------------
    // Interfaces
    // -------------------------
    // Local interfaces
    reg_proxy_reg_intf reg_proxy_reg_if ();

    // -------------------------
    // Terminate AXI-L interface
    // -------------------------
    // Endian check register block
    reg_proxy_reg_blk i_reg_proxy_reg_blk (
        .axil_if     (axil_if),
        .reg_blk_if  (reg_proxy_reg_if)
    );
    
    // -------------------------
    // Clock/reset
    // -------------------------
    assign reg_if.clk = axil_if.aclk;

    initial reg_if.srst = 1'b1;
    always @(posedge reg_if.clk) begin
        if (!axil_if.aresetn) reg_if.srst <= 1'b1;
        else                  reg_if.srst <= 1'b0;
    end

    // -------------------------
    // Transaction FSM
    // -------------------------
    initial state = RESET;
    always @(posedge reg_if.clk) begin
        if (reg_if.srst) state <= RESET;
        else             state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        reg_if.wr = 1'b0;
        reg_if.rd = 1'b0;
        case (state)
            RESET : begin
                nxt_state = READY;
            end
            READY : begin
                if (reg_proxy_reg_if.command_wr_evt) begin
                    if (reg_proxy_reg_if.command.wr_rd_n) nxt_state = WRITE;
                    else                                  nxt_state = READ;
                end
            end
            WRITE : begin
                reg_if.wr = 1'b1;
                nxt_state = WRITE_ACK;
            end
            READ : begin
                reg_if.rd = 1'b1;
                nxt_state = READ_ACK;
            end
            WRITE_ACK : begin
                if (reg_if.wr_ack) begin
                    if (reg_if.wr_error) nxt_state = ERROR;
                    else                 nxt_state = DONE;
                end
            end
            READ_ACK : begin
                if (reg_if.rd_ack) begin
                    if (reg_if.rd_error) nxt_state = ERROR;
                    else                 nxt_state = DONE;
                end
            end
            ERROR : begin
                nxt_state = READY;
            end
            DONE : begin
                nxt_state = READY;
            end
        endcase
    end

    // Latch write context
    always_ff @(posedge reg_if.clk) begin
        if (state == READY) begin
            reg_if.wr_addr <= reg_proxy_reg_if.address;
            reg_if.wr_data <= reg_proxy_reg_if.wr_data;
            reg_if.wr_byte_en <= reg_proxy_reg_if.wr_byte_en;
        end
    end

    // Latch read context
    always_ff @(posedge reg_if.clk) begin
        if (state == READY) begin
            reg_if.rd_addr <= reg_proxy_reg_if.address;
        end
    end

    // Latch read data
    always_ff @(posedge reg_if.clk) begin
        if (reg_if.rd_ack) rd_data <= reg_if.rd_data;
    end

    // Maintain status register
    always_comb begin
        reg_proxy_reg_if.status_nxt_v = 1'b0;
        reg_proxy_reg_if.status_nxt = reg_proxy_reg_if.status;
        // Clear on read
        if (reg_proxy_reg_if.status_rd_evt) begin
            reg_proxy_reg_if.status_nxt_v = 1'b1;
            reg_proxy_reg_if.status_nxt.done = 1'b0;
            reg_proxy_reg_if.status_nxt.error = 1'b0;
        end
        // Update
        case (state)
            READY : begin
                reg_proxy_reg_if.status_nxt_v = 1'b1;
                reg_proxy_reg_if.status_nxt.ready = 1'b1;
            end
            DONE : begin
                reg_proxy_reg_if.status_nxt_v = 1'b1;
                reg_proxy_reg_if.status_nxt.done = 1'b1;
                reg_proxy_reg_if.status_nxt.error = 1'b0;
            end
            ERROR : begin
                reg_proxy_reg_if.status_nxt_v = 1'b1;
                reg_proxy_reg_if.status_nxt.done = 1'b1;
                reg_proxy_reg_if.status_nxt.error = 1'b1;
            end
        endcase
    end

    // Read data
    always_comb begin
        case (state)
            DONE : begin
                reg_proxy_reg_if.rd_data_nxt_v = 1'b1;
                reg_proxy_reg_if.rd_data_nxt = rd_data;
            end
            ERROR : begin
                reg_proxy_reg_if.rd_data_nxt_v = 1'b1;
                reg_proxy_reg_if.rd_data_nxt = reg_pkg::BAD_ACCESS_DATA;
            end
            default : begin
                reg_proxy_reg_if.rd_data_nxt_v = 1'b0;
                reg_proxy_reg_if.rd_data_nxt = reg_pkg::BAD_ACCESS_DATA;
            end
        endcase
    end

endmodule : reg_proxy
