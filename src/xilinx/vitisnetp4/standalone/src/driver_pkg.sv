package driver_pkg;

`ifdef DPI_PKG_V2_0

    class driver;
        chandle env;
        chandle CtxPtr[$];
        local const string __hier_path;

        function new(input string hier_path);
            __hier_path = hier_path;
        endfunction

        task init();
            env = vitis_net_p4_dpi_pkg::XilVitisNetP4DpiCreateEnv(__hier_path);
            `VITIS_NET_P4_PKG::initialize(CtxPtr, env);
        endtask

        task add_rule(input string table_name, bit[1023:0] key, bit[1023:0] mask, bit[1023:0] response, int prio);
            `VITIS_NET_P4_PKG::table_add(CtxPtr, table_name, key, mask, response, prio);
        endtask

        task cleanup();
            `VITIS_NET_P4_PKG::terminate(CtxPtr);
            void'(vitis_net_p4_dpi_pkg::XilVitisNetP4DpiDestroyEnv(env));
            CtxPtr.delete();
        endtask

    endclass

`else

    class driver;
        local vitis_net_p4_dpi_pkg::XilVitisNetP4DPIHandle drv;
        local const string __hier_path;

        function new(input string hier_path);
            __hier_path = hier_path;
        endfunction

        task init();
            drv.cfg = `VITIS_NET_P4_PKG::XilVitisNetP4Config;
            vitis_net_p4_dpi_pkg::XilVitisNetP4DPIinit(drv, __hier_path);
        endtask

        task add_rule(input string table_name, bit[1023:0] key, bit[1023:0] mask, bit[1023:0] response, int prio);
            vitis_net_p4_dpi_pkg::XilVitisNetP4DPItableAdd(drv, table_name, key, mask, response, prio);
        endtask

        task cleanup();
            vitis_net_p4_dpi_pkg::XilVitisNetP4DPIexit(drv);
        endtask

    endclass
`endif

endpackage
