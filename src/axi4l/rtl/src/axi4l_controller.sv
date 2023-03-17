module axi4l_controller
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32,
    // Derived parameters (don't override)
    parameter int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH),
    parameter int DATA_WID = DATA_BYTE_WID * 8
) (
    // Upstream (register control)
    input  logic                     clk,
    input  logic                     srst,
    input  logic                     wr,
    input  logic [ADDR_WID-1:0]      wr_addr,
    input  logic [DATA_WID-1:0]      wr_data,
    input  logic [DATA_BYTE_WID-1:0] wr_strb,
    output logic                     wr_ack,
    output resp_t                    wr_resp,
    input  logic                     rd,
    input  logic [ADDR_WID-1:0]      rd_addr,
    output logic [DATA_WID-1:0]      rd_data,
    output logic                     rd_ack,
    output resp_t                    rd_resp,
    // Downstream (AXI-L)
    axi4l_intf.controller            axi4l_if
);

    // Parameters
    // --------------------
    localparam int WR_TIMEOUT = 64;
    localparam int WR_TIMER_WID = $clog2(WR_TIMEOUT);
    localparam int RD_TIMEOUT = 64;
    localparam int RD_TIMER_WID = $clog2(RD_TIMEOUT);

    // Signals
    // --------------------
    logic                      wr_pending;
    logic [WR_TIMER_WID-1:0]   wr_timer;
    logic                      wr_timeout;

    logic                      rd_pending;
    logic [RD_TIMER_WID-1:0]   rd_timer;
    logic                      rd_timeout;

    // Clock/reset
    // --------------------
    assign axi4l_if.aclk = clk;

    initial axi4l_if.aresetn = 1'b0;
    always @(posedge axi4l_if.aclk) begin
        if (srst) axi4l_if.aresetn <= 1'b0;
        else      axi4l_if.aresetn <= 1'b1;
    end

    // Write address
    // --------------------
    initial axi4l_if.awvalid = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.awvalid <= 1'b0;
        else begin
            if (wr) axi4l_if.awvalid <= 1'b1;
            else if (axi4l_if.awready || wr_timeout) axi4l_if.awvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) if (wr) axi4l_if.awaddr <= wr_addr;

    // Write data
    // --------------------
    initial axi4l_if.wvalid = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.wvalid <= 1'b0;
        else begin
            if (wr) axi4l_if.wvalid <= 1'b1;
            else if (axi4l_if.wready || wr_timeout) axi4l_if.wvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (wr) begin
            axi4l_if.wdata <= wr_data;
            axi4l_if.wstrb <= wr_strb;
        end
    end

    // Write state
    // -------------
    initial wr_pending = 1'b0;
    always @(posedge clk) begin
        if (srst) wr_pending <= 1'b0;
        else begin
            if (wr) wr_pending <= 1'b1;
            else if (wr_ack) wr_pending <= 1'b0;
        end
    end

    // Write timeout
    // -------------
    initial wr_timer = 0;
    always @(posedge clk) begin
        if (srst) wr_timer <= 0;
        else begin
            if (wr_pending) wr_timer <= wr_timer + 1;
            else            wr_timer <= 0;
        end
    end
    assign wr_timeout = (wr_timer == WR_TIMEOUT-1);

    // Write response
    // --------------------
    initial axi4l_if.bready = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.bready <= 1'b0;
        else if (wr) axi4l_if.bready <= 1'b1;
        else if (axi4l_if.bvalid || wr_timeout) axi4l_if.bready <= 1'b0;
    end

    initial begin
        wr_ack = 1'b0;
        wr_resp = RESP_SLVERR;
    end
    always @(posedge clk) begin
        if (srst) begin
            wr_ack  <= 1'b0;
            wr_resp <= RESP_SLVERR;
        end else begin
            if (wr_timeout) begin
                wr_ack  <= 1'b1;
                wr_resp <= RESP_SLVERR;
            end else if (axi4l_if.bvalid && axi4l_if.bready) begin
                wr_ack  <= 1'b1;
                wr_resp <= axi4l_if.bresp;
            end else begin
                wr_ack  <= 1'b0;
                wr_resp <= RESP_SLVERR;
            end
        end
    end

    // Read address
    // --------------------
    initial axi4l_if.arvalid = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.arvalid <= 1'b0;
        else begin
            if (rd) axi4l_if.arvalid <= 1'b1;
            else if (axi4l_if.arready || rd_timeout) axi4l_if.arvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) if (rd) axi4l_if.araddr <= rd_addr;

    // Read state
    // -------------
    initial rd_pending = 1'b0;
    always @(posedge clk) begin
        if (srst) rd_pending <= 1'b0;
        else begin
            if (rd) rd_pending <= 1'b1;
            else if (rd_ack) rd_pending <= 1'b0;
        end
    end

    // Read timeout
    // -------------
    initial rd_timer = 0;
    always @(posedge clk) begin
        if (srst) rd_timer <= 0;
        else begin
            if (rd_pending) rd_timer <= rd_timer + 1;
            else            rd_timer <= 0;
        end
    end
    assign rd_timeout = (rd_timer == RD_TIMEOUT-1);

    // Read response
    // --------------------
    initial axi4l_if.rready = 1'b0;
    always @(posedge clk) begin
        if (srst) axi4l_if.rready <= 1'b0;
        else if (rd) axi4l_if.rready <= 1'b1;
        else if (axi4l_if.rvalid || rd_timeout) axi4l_if.rready <= 1'b0;
    end

    initial begin
        rd_ack  = 1'b0;
        rd_resp = RESP_SLVERR;
    end
    always @(posedge clk) begin
        if (srst) begin
            rd_ack  <= 1'b0;
            rd_resp <= RESP_SLVERR;
        end else begin
            if (rd_timeout) begin
                rd_ack  <= 1'b1;
                rd_resp <= RESP_SLVERR;
            end else if (axi4l_if.rvalid && axi4l_if.rready) begin
                rd_ack  <= 1'b1;
                rd_resp <= axi4l_if.rresp;
            end else begin
                rd_ack  <= 1'b0;
                rd_resp <= RESP_SLVERR;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rd_timeout) rd_data <= reg_pkg::BAD_ACCESS_DATA;
        else            rd_data <= axi4l_if.rdata;
    end

endmodule : axi4l_controller
