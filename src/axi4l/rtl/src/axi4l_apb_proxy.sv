module axi4l_apb_proxy (
    axi4l_intf.peripheral axi4l_if,
    apb_intf.controller   apb_if
);
    // Standard register interface
    reg_intf reg_if ();

    // Register-indirect proxy interface
    // - terminates AXI-L with memory window supporting register-indirect
    //   access into a (potentially much larger) memory space mapped on
    //   the APB interface
    reg_proxy i_reg_proxy (
        .axil_if ( axi4l_if ),
        .reg_if  ( reg_if )
    );

    // APB controller
    // - map register control interface to downstream APB interface
    apb_controller i_apb_controller (
        .reg_if   ( reg_if ),
        .apb_if   ( apb_if )
    );

endmodule : axi4l_apb_proxy
