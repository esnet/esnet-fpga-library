class xilinx_vitisnetp4_agent extends std_verif_pkg::agent;

    // Pointer to VitisNetP4 DPI control object
    protected vitis_net_p4_dpi_pkg::XilVitisNetP4DPIHandle _drv;

    // Hierarchical path to AXI-L write/read tasks (axi_lite_wr / axi_lite_rd)
    protected const string _hier_path;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="xilinx_vitisnetp4_agent", input string hier_path,
                 input vitis_net_p4_dpi_pkg::XilVitisNetP4TargetConfig cfg
        );
        super.new(name);
        _hier_path = hier_path;
        _drv.cfg = cfg;
        _drv.meta = {};
        _drv.plugin = 0;
        _drv.pluginJson = "";
    endfunction

    // Destructor
    // [[ overrides std_verif_pkg::base.destroy() ]]
    function automatic void destroy();
        debug_msg("---------------- VitisNetP4: Destroy. -------------");
        // Destroy VitisNetP4 driver instance
        if (_drv.env != null) begin
            _drv.ctxPtr.delete();
            void'(vitis_net_p4_dpi_pkg::XilVitisNetP4DpiDestroyEnv(_drv.env));
        end
        super.destroy();
        debug_msg("---------------- VitisNetP4: Driver destroyed. -------------");
    endfunction

    // Initialize VitisNetP4 driver
    // - needs to be performed before any table accesses/programming
    task init();
        debug_msg("---------------- VitisNetP4: Initialize. -------------");
        vitis_net_p4_dpi_pkg::XilVitisNetP4DPIinit(_drv, _hier_path);
        debug_msg("---------------- VitisNetP4: Initialization done. -------------");
    endtask

    // Terminate VitisNetP4 driver
    task terminate();
        debug_msg("---------------- VitisNetP4: Terminate. -------------");
        vitis_net_p4_dpi_pkg::XilVitisNetP4DPIexit(_drv);
        debug_msg("---------------- VitisNetP4: Termination done. -------------");
    endtask

    // Reset VitisNetP4 tables
    // - reset VitisNetP4 IP to default state
    task reset_tables();
        debug_msg("---------------- VitisNetP4: Reset table state. -------------");
        vitis_net_p4_dpi_pkg::XilVitisNetP4DPIresetState(_drv);
        debug_msg("---------------- VitisNetP4: Reset table state done.. -------------");
    endtask

    // vitisnetp4_table_init is based on the procedure described in the example_control.sv file of xilinx vitisnetp4 example design
    task table_init_from_file(input string filename);
        import vitis_net_p4_dpi_pkg::*;
        import xilinx_vitisnetp4_example_pkg::*;

        automatic bit VERBOSE = (this.get_debug_level() > 1);

        CliCmdStruct cli_cmds[];
        CliCmdStruct cli_cmd;
        longint PktCnt, ByteCnt;
        vitis_net_p4_dpi_pkg::longBitArray regVal;

        automatic string __filename;
        automatic int filename_len = filename.len;
        automatic string filename_ext = filename.substr(filename.len-4,filename.len-1);

        automatic XilVitisNetP4DPIHandle ch = _drv;

        // Always print this message to bracket print output from table driver
        // (no obvious way to disable driver output)
        print_msg("INFO: ", get_name(), "---------------- VitisNetP4: Initialize tables from file. -------------");

        reset_tables();

        // parse_cli_commands function adds '.txt' extension to filename input argument
        // (needs to be stripped if present
        if (filename_ext.compare(".txt"))
            __filename = filename;
        else
            __filename = filename.substr(0,filename.len-5);

        trace_msg($sformatf("------ Parsing %s as command file. ----------", filename));
        parse_cli_commands(_drv.cfg, __filename, cli_cmds);
        trace_msg("------ Parsing command file done. ----------");

        for (int cmd_idx = 0; cmd_idx < cli_cmds.size(); cmd_idx++) begin
            cli_cmd = cli_cmds[cmd_idx];

            case (cli_cmd.op)
                TBL_ADD: begin
                    if (VERBOSE) begin
                      $display("** Info: Adding entry to table %0s", cli_cmd.tbl.name);
                      $display("  - match key:\t0x%0x", cli_cmd.tbl.key);
                      $display("  - key mask:\t0x%0x", cli_cmd.tbl.mask);
                      $display("  - response:\t0x%0x", cli_cmd.tbl.resp);
                      $display("  - priority:\t%0d", cli_cmd.tbl.prio);
                    end
                    XilVitisNetP4DPItableAdd(ch, cli_cmd.tbl.name, cli_cmd.tbl.key, cli_cmd.tbl.mask, cli_cmd.tbl.resp, cli_cmd.tbl.prio);
                    if (VERBOSE) $display("** Info: Entry has been added with handle %0d", cli_cmd.tbl.entryId);
                end

                TBL_MODIFY : begin
                    if (VERBOSE) begin
                      $display("** Info: Modifying entry from table %0s", cli_cmd.tbl.name);
                      $display("  - match key:\t0x%0x", cli_cmd.tbl.key);
                      $display("  - key mask:\t0x%0x", cli_cmd.tbl.mask);
                      $display("  - response:\t0x%0x", cli_cmd.tbl.resp);
                    end
                    XilVitisNetP4DPItableModify(ch, cli_cmd.tbl.name, cli_cmd.tbl.key, cli_cmd.tbl.mask, cli_cmd.tbl.resp);
                    if (VERBOSE) $display("** Info: Entry has been modified with handle %0d", cli_cmd.tbl.entryId);
                end

                TBL_DELETE : begin
                    if (VERBOSE) begin
                      $display("** Info: Deleting entry from table %0s", cli_cmd.tbl.name);
                      $display("  - match key:\t0x%0x", cli_cmd.tbl.key);
                      $display("  - key mask:\t0x%0x", cli_cmd.tbl.mask);
                    end
                    XilVitisNetP4DPItableDelete(ch, cli_cmd.tbl.name, cli_cmd.tbl.key, cli_cmd.tbl.mask);
                    if (VERBOSE) $display("** Info: Entry has been deleted with handle %0d", cli_cmd.tbl.entryId);
                end

                TBL_CLEAR : begin
                    if (VERBOSE) $display("** Info: Deleting all entries from table %0s", cli_cmd.tbl.name);
                    XilVitisNetP4DPItableClear(ch, cli_cmd.tbl.name);
                end

                CNT_READ : begin
                    XilVitisNetP4DPIcounterRead(ch, cli_cmd.cnt.name, cli_cmd.cnt.index, ByteCnt, PktCnt);
                    if (VERBOSE) begin
                      $display("** Info: Counter read %0s[%0d]", cli_cmd.cnt.name, cli_cmd.cnt.index);
                      $display("  - bytes: 0x%0x", ByteCnt);
                      $display("  - packets: 0x%0x", PktCnt);
                    end
                end

                CNT_WRITE : begin
                    if (VERBOSE) begin
                      $display("** Info: Counter write %0s[%0d]", cli_cmd.cnt.name, cli_cmd.cnt.index);
                      $display("  - bytes: 0x%0x", cli_cmd.cnt.bytes);
                      $display("  - packets: 0x%0x", cli_cmd.cnt.packets);
                    end
                    XilVitisNetP4DPIcounterWrite(ch, cli_cmd.cnt.name, cli_cmd.cnt.index, cli_cmd.cnt.bytes, cli_cmd.cnt.packets);
                end

                CNT_RST : begin
                    if (VERBOSE) $display("** Info: Counter reset %0s", cli_cmd.cnt.name);
                    XilVitisNetP4DPIregisterReset(ch, cli_cmd.cnt.name);
                end

                REG_READ : begin
                    XilVitisNetP4DPIregisterRead(ch, cli_cmd.rgt.name, cli_cmd.rgt.index, regVal);
                    if (VERBOSE) $display("** Info: Register read %0s[%0d] = 0x%0x", cli_cmd.rgt.name, cli_cmd.rgt.index, regVal);
                end

                REG_WRITE : begin
                    if (VERBOSE) $display("** Info: Register write %0s[%0d] = 0x%0x", cli_cmd.rgt.name, cli_cmd.rgt.index, cli_cmd.rgt.value);
                    XilVitisNetP4DPIregisterWrite(ch, cli_cmd.rgt.name, cli_cmd.rgt.index, cli_cmd.rgt.value);
                end

                REG_RST : begin
                    if (VERBOSE) $display("** Info: Register reset %0s", cli_cmd.rgt.name);
                    XilVitisNetP4DPIregisterReset(ch, cli_cmd.rgt.name);
                end

                RST_STATE : begin
                    if (VERBOSE) $display("** Info: Resetting VitisNet IP instance to default state");
                    XilVitisNetP4DPIresetState(ch);
                end
            endcase
        end
        cli_cmds.delete();
    endtask

endclass : xilinx_vitisnetp4_agent
