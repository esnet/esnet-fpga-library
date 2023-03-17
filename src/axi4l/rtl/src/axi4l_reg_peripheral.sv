module axi4l_reg_peripheral (
    axi4l_intf.peripheral axi4l_if,
    reg_intf.controller reg_if
);

    // ============================
    // Imports
    // ============================
    import axi4l_pkg::*;

    // ============================
    // Parameters
    // ============================
    localparam int ADDR_WID = axi4l_if.ADDR_WID;
    localparam axi4l_bus_width_t BUS_WIDTH = axi4l_if.BUS_WIDTH;
    localparam int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH);

    // Parameterization assertions
    initial begin
        assert(axi4l_if.ADDR_WID == reg_if.ADDR_WID);
        assert(DATA_BYTE_WID     == reg_if.DATA_BYTE_WID);
    end

    // ============================
    // Signals
    // ============================
    resp_t wr_resp;
    resp_t rd_resp;

    // ============================
    // Logic
    // ============================

    // Base AXI-L peripheral
    // - map downstream control interface to standard register
    //   interface for interacting with register block endpoints
    axi4l_peripheral #(
        .ADDR_WID  ( ADDR_WID ),
        .BUS_WIDTH ( BUS_WIDTH )
    ) i_axi4l_peripheral (
        .axi4l_if ( axi4l_if ),
        .clk      ( reg_if.clk ),
        .srst     ( reg_if.srst ),
        .wr       ( reg_if.wr ),
        .wr_addr  ( reg_if.wr_addr ),
        .wr_data  ( reg_if.wr_data ),
        .wr_strb  ( reg_if.wr_byte_en ),
        .wr_ack   ( reg_if.wr_ack),
        .wr_resp  ( wr_resp ),
        .rd       ( reg_if.rd ),
        .rd_addr  ( reg_if.rd_addr ),
        .rd_data  ( reg_if.rd_data ),
        .rd_ack   ( reg_if.rd_ack ),
        .rd_resp  ( rd_resp )
    );

    // Map write error into AXI-L response code
    always_comb begin
        if (reg_if.wr_error) wr_resp = RESP_SLVERR;
        else                 wr_resp = RESP_OKAY;
    end

    // Map read error into AXI-L response code
    always_comb begin
        if (reg_if.rd_error) rd_resp = RESP_SLVERR;
        else                 rd_resp = RESP_OKAY;
    end

endmodule : axi4l_reg_peripheral
