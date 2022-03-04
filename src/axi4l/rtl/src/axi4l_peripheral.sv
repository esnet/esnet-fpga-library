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

module axi4l_peripheral
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32,
    // Derived parameters (don't override)
    parameter int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH),
    parameter int DATA_WID = DATA_BYTE_WID * 8
) (
    // Upstream (AXI-L)
    axi4l_intf.peripheral            axi4l_if,

    // Downstream (register access)
    output logic                     clk,
    output logic                     srst,
    output logic                     wr,
    output logic [ADDR_WID-1:0]      wr_addr,
    output logic [DATA_WID-1:0]      wr_data,
    output logic [DATA_BYTE_WID-1:0] wr_strb,
    input  logic                     wr_ack,
    input  resp_t                    wr_resp,
    output logic                     rd,
    output logic [ADDR_WID-1:0]      rd_addr,
    input  logic [DATA_WID-1:0]      rd_data,
    input  logic                     rd_ack,
    input  resp_t                    rd_resp
);

    // ============================
    // Signals
    // ============================
    logic wr_addr_latched;
    logic wr_data_latched;
    logic wr_pending;

    logic rd_pending;

    // ============================
    // RTL
    // ============================

    // Clock
    assign clk = axi4l_if.aclk;

    // Reset
    initial srst = 1'b1;
    always @(posedge axi4l_if.aclk) begin
        if (!axi4l_if.aresetn) srst <= 1'b1;
        else                   srst <= 1'b0;
    end

    // Write address
    initial axi4l_if.awready = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.awready <= 1'b0;
        else if (axi4l_if.awvalid && axi4l_if.awready) axi4l_if.awready <= 1'b0;
        else if (axi4l_if.bvalid  && axi4l_if.bready)  axi4l_if.awready <= 1'b1;
        else                                           axi4l_if.awready <= !(wr_addr_latched || wr_pending);
    end

    // -- latch address
    always_ff @(posedge clk) if (axi4l_if.awvalid && axi4l_if.awready) wr_addr <= axi4l_if.awaddr;

    // -- latch done
    initial wr_addr_latched = 1'b0;
    always @(posedge clk) begin
        if (srst) wr_addr_latched <= 1'b0;
        else if (axi4l_if.awvalid && axi4l_if.awready) wr_addr_latched <= 1'b1;
        else if (wr)                                   wr_addr_latched <= 1'b0;
    end

    // Write control
    initial axi4l_if.wready = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.wready <= 1'b0;
        else if (axi4l_if.wvalid && axi4l_if.wready)  axi4l_if.wready <= 1'b0;
        else if (axi4l_if.bvalid  && axi4l_if.bready) axi4l_if.wready <= 1'b1;
        else                                          axi4l_if.wready <= !(wr_data_latched || wr_pending);
    end

    // -- latch data
    always_ff @(posedge clk) begin
        if (axi4l_if.wvalid && axi4l_if.wready) begin
            wr_data <= axi4l_if.wdata;
            wr_strb <= axi4l_if.wstrb;
        end
    end

    // -- latch done
    initial wr_data_latched = 1'b0;
    always @(posedge clk) begin
        if (srst) wr_data_latched <= 1'b0;
        else if (axi4l_if.wvalid && axi4l_if.wready) wr_data_latched <= 1'b1;
        else if (wr)                                 wr_data_latched <= 1'b0;
    end

    // Synthesize downstream write
    assign wr = wr_addr_latched && wr_data_latched;

    initial wr_pending = 1'b0;
    always @(posedge clk) begin
        if (srst)        wr_pending <= 1'b0;
        else if (wr)     wr_pending <= 1'b1;
        else if (wr_ack) wr_pending <= 1'b0;
    end

    // Write response
    initial begin
        axi4l_if.bvalid = 1'b0;
        axi4l_if.bresp = RESP_SLVERR;
    end
    always @(posedge clk) begin
        if (srst) begin
            axi4l_if.bvalid <= 1'b0;
            axi4l_if.bresp <= RESP_SLVERR;
        end else begin
            if (wr_ack) begin
                axi4l_if.bvalid <= 1'b1;
                axi4l_if.bresp  <= wr_resp;
            end else if (axi4l_if.bready) begin
                axi4l_if.bvalid <= 1'b0;
                axi4l_if.bresp <= RESP_SLVERR;
            end
        end
    end

    // Read control

    // Latch read address
    always_ff @(posedge clk) if (axi4l_if.arvalid && axi4l_if.arready) rd_addr <= axi4l_if.araddr;

    // Synthesize downstream read
    initial rd = 1'b0;
    always @(posedge clk) begin
        if (srst) rd <= 1'b0;
        else if (axi4l_if.arvalid && axi4l_if.arready) rd <= 1'b1;
        else                                           rd <= 1'b0;
    end

    initial axi4l_if.arready = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.arready <= 1'b0;
        else if (axi4l_if.arvalid && axi4l_if.arready) axi4l_if.arready <= 1'b0;
        else if (axi4l_if.rvalid  && axi4l_if.rready)  axi4l_if.arready <= 1'b1;
        else                                           axi4l_if.arready <= !rd_pending;
    end

    initial rd_pending = 1'b0;
    always @(posedge clk) begin
        if (srst) rd_pending <= 1'b0;
        else begin
            if (axi4l_if.arvalid && axi4l_if.arready)    rd_pending <= 1'b1;
            else if (axi4l_if.rvalid && axi4l_if.rready) rd_pending <= 1'b0;
        end
    end

    // Read data
    always_ff @(posedge clk) begin
        if (rd_ack) begin
            if (rd_resp == RESP_OKAY) axi4l_if.rdata <= rd_data;
            else                      axi4l_if.rdata <= reg_pkg::BAD_ACCESS_DATA;
        end
    end

    // Read response
    initial begin
        axi4l_if.rvalid = 1'b0;
        axi4l_if.rresp  = RESP_SLVERR;
    end
    always @(posedge clk) begin
        if (srst) begin
            axi4l_if.rvalid <= 1'b0;
            axi4l_if.rresp  <= RESP_SLVERR;
        end else begin
            if (rd_ack) begin
                axi4l_if.rvalid <= 1'b1;
                axi4l_if.rresp  <= rd_resp;
            end else if (axi4l_if.rready) begin
                axi4l_if.rvalid <= 1'b0;
                axi4l_if.rresp <= RESP_SLVERR;
            end
        end
    end

endmodule : axi4l_peripheral
