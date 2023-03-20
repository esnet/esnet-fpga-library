module axi4l_apb_bridge (
    axi4l_intf.peripheral axi4l_if,
    apb_intf.controller   apb_if
);
    // Standard register interface
    reg_intf #(.DATA_BYTE_WID(axi4l_if.DATA_BYTE_WID), .ADDR_WID(axi4l_if.ADDR_WID)) reg_if ();

    // AXI-L register peripheral
    // - map downstream control interface to standard register
    //   interface for interacting with register block endpoints
    axi4l_reg_peripheral i_axi4l_reg_peripheral (
        .axi4l_if ( axi4l_if ),
        .reg_if   ( reg_if )
    );

    // APB controller
    // - map register control interface to downstream APB interface
    apb_controller i_apb_controller (
        .reg_if   ( reg_if ),
        .apb_if   ( apb_if )
    );

endmodule : axi4l_apb_bridge
