module axi4l_proxy (
    axi4l_intf.peripheral  axi4l_if_from_controller,
    axi4l_intf.controller  axi4l_if_to_peripheral
);
    // Imports
    import axi4l_pkg::*;

    // Standard register interface
    reg_intf reg_if ();

    // Register-indirect proxy interface
    // - terminates AXI-L with memory window supporting register-indirect
    //   access into a (potentially much larger) memory space mapped on
    //   the APB interface
    reg_proxy i_reg_proxy (
        .axil_if ( axi4l_if_from_controller ),
        .reg_if  ( reg_if )
    );

    // AXI-L controller
    // - map register control interface to downstream AXI-L interface
    resp_t wr_resp;
    resp_t rd_resp;

    assign reg_if.wr_error = wr_resp == RESP_OKAY ? 1'b0 : 1'b1;
    assign reg_if.rd_error = rd_resp == RESP_OKAY ? 1'b0 : 1'b1;

    axi4l_controller i_axi4l_controller (
        .clk      ( reg_if.clk ),
        .srst     ( reg_if.srst ),
        .wr       ( reg_if.wr ),
        .wr_addr  ( reg_if.wr_addr ),
        .wr_data  ( reg_if.wr_data ),
        .wr_strb  ( reg_if.wr_byte_en ),
        .wr_ack   ( reg_if.wr_ack ),
        .wr_resp  ( wr_resp ),
        .rd       ( reg_if.rd ),
        .rd_addr  ( reg_if.rd_addr ),
        .rd_data  ( reg_if.rd_data ),
        .rd_ack   ( reg_if.rd_ack ),
        .rd_resp  ( rd_resp ),
        .axi4l_if ( axi4l_if_to_peripheral )
    );

endmodule : axi4l_proxy
