module hbm_bfm #(
    parameter int PSEUDO_CHANNELS = 16,
    parameter bit DEBUG = 1'b0
) (
    axi3_intf.peripheral axi3_if [PSEUDO_CHANNELS]
);

    // Imports
    import axi3_pkg::*;

    // Typedefs
    typedef logic [32:0]      addr_t;
    typedef logic [31:0][7:0] data_t;
    typedef logic [5:0]       id_t;

    data_t __ram [addr_t];

    generate
        for (genvar g_if = 0; g_if < PSEUDO_CHANNELS; g_if++) begin : g__if

            // (Local) signals
            addr_t awaddr;
            addr_t awaddr_reg;
            id_t   awid;
            id_t   awid_reg;

            addr_t araddr;
            addr_t araddr_reg;
            id_t   arid;
            id_t   arid_reg;

            // Always ready for write address
            assign axi3_if[g_if].awready = 1'b1;

            // Latch write address/id
            always @(posedge axi3_if[g_if].aclk) begin
                if (axi3_if[g_if].awvalid) begin
                    awaddr_reg <= axi3_if[g_if].awaddr;
                    awid_reg <= axi3_if[g_if].awid;
                end
            end
            assign awaddr = axi3_if[g_if].awvalid ? axi3_if[g_if].awaddr : awaddr_reg;
            assign awid   = axi3_if[g_if].awvalid ? axi3_if[g_if].awid   : awid_reg;

            // Always ready for write data
            assign axi3_if[g_if].wready = 1'b1;

            // Perform write
            always @(posedge axi3_if[g_if].aclk) begin
                if (axi3_if[g_if].wvalid) begin
                    if (axi3_if[g_if].wlast) begin
                        __ram[awaddr + 32] = axi3_if[g_if].wdata;
                        if (DEBUG) $display("WRITE on PC %d, ID %d: ADDR: %0x, DATA: %x", g_if, awid, awaddr + 32, axi3_if[g_if].wdata);
                    end else begin
                        __ram[awaddr] = axi3_if[g_if].wdata;
                        if (DEBUG) $display("WRITE on PC %d, ID %d: ADDR: %0x, DATA: %x", g_if, awid, awaddr, axi3_if[g_if].wdata);
                    end
                end
            end

            initial axi3_if[g_if].bvalid = 1'b0;

            // Perform write response
            always @(posedge axi3_if[g_if].aclk) begin
                if (axi3_if[g_if].wvalid) begin
                    axi3_if[g_if].bvalid <= 1'b1;
                    axi3_if[g_if].bid <= awid;
                    axi3_if[g_if].bresp <= axi3_pkg::RESP_OKAY;
                end else begin
                    axi3_if[g_if].bvalid <= 1'b0;
                end
            end

            // Always ready for read address
            assign axi3_if[g_if].arready = 1'b1;

            // Latch read address/id
            always @(posedge axi3_if[g_if].aclk) begin
                if (axi3_if[g_if].arvalid) begin
                    araddr_reg <= axi3_if[g_if].araddr;
                    arid_reg <= axi3_if[g_if].arid;
                end
            end
            assign araddr = axi3_if[g_if].arvalid ? axi3_if[g_if].araddr : araddr_reg;
            assign arid   = axi3_if[g_if].arvalid ? axi3_if[g_if].arid   : arid_reg;

            initial axi3_if[g_if].rvalid = 1'b0;
            initial axi3_if[g_if].rresp = axi3_pkg::RESP_SLVERR;

            // Perform read
            always @(posedge axi3_if[g_if].aclk) begin
                if (axi3_if[g_if].arvalid) begin
                    if (__ram.exists(araddr)) begin
                        axi3_if[g_if].rdata <= __ram[araddr];
                        if (DEBUG) $display("READ on PC %d, ID %d: ADDR: %0x, DATA: %x", g_if, arid, araddr, __ram[araddr]);
                    end else begin
                        axi3_if[g_if].rdata <= '0;
                        if (DEBUG) $display("READ on PC %d, ID %d: ADDR: %0x, DATA: %x", g_if, arid, araddr, '0);
                    end
                    axi3_if[g_if].rvalid <= 1'b1;
                    axi3_if[g_if].rid <= arid;
                    axi3_if[g_if].rlast <= 1'b0;
                    axi3_if[g_if].rresp <= axi3_pkg::RESP_OKAY;
                end else if (axi3_if[g_if].rvalid && !axi3_if[g_if].rlast) begin
                    if (__ram.exists(araddr + 32)) begin
                        axi3_if[g_if].rdata <= __ram[araddr + 32];
                        if (DEBUG) $display("READ on PC %d, ID %d: ADDR: %0x, DATA: %x", g_if, arid, araddr + 32, __ram[araddr + 32]);
                    end else begin
                        axi3_if[g_if].rdata <= '0;
                        if (DEBUG) $display("READ on PC %d, ID %d: ADDR: %0x, DATA: %x", g_if, arid, araddr, '0);
                    end
                    axi3_if[g_if].rvalid <= 1'b1;
                    axi3_if[g_if].rlast <= 1'b1;
                    axi3_if[g_if].rid <= arid;
                    axi3_if[g_if].rresp <= axi3_pkg::RESP_OKAY;
                end else begin
                    axi3_if[g_if].rvalid <= 1'b0;
                end
            end

        end : g__if
    endgenerate

endmodule : hbm_bfm
