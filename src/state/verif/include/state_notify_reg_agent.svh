class state_notify_reg_agent extends state_notify_reg_blk_agent;

    local static const string __CLASS_NAME = "state_verif_pkg::state_notify_reg_agent";

    //===================================
    // Methods
    //===================================
    function new(
            input string name="state_notify_reg_agent",
            reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
    endfunction
 
    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent._reset() virtual method ]]
    protected virtual function automatic void _reset();
        super._reset();
        // Nothing extra to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    task soft_reset();
        state_notify_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    // Reset scan to ID 0
    task scan_reset();
        state_notify_reg_pkg::reg_scan_control_t reg_scan_control;
        this.read_scan_control(reg_scan_control);
        reg_scan_control.reset = 1;
        this.write_scan_control(reg_scan_control);
        reg_scan_control.reset = 0;
        this.write_scan_control(reg_scan_control);
    endtask

    // Configure scan to poll limited range of IDs (i.e. 0:max_id)
    task set_scan_limit(input int max_id);
        state_notify_reg_pkg::reg_scan_control_t reg_scan_control;
        reg_scan_control.reset = 0;
        reg_scan_control.limit_en = 1;
        reg_scan_control.limit_max = max_id;
        this.write_scan_control(reg_scan_control);
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        state_notify_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task get_size(output int size);
        state_notify_reg_pkg::reg_info_size_t reg_info_size;
        this.read_info_size(reg_info_size);
        size = reg_info_size;
    endtask

    task get_scan_done_cnt(output int cnt);
        state_notify_reg_pkg::reg_dbg_cnt_scan_done_t reg_dbg_cnt_scan_done;
        this.read_dbg_cnt_scan_done(reg_dbg_cnt_scan_done);
        cnt = reg_dbg_cnt_scan_done;
    endtask

    task get_active_last_scan_cnt(output int cnt);
        state_notify_reg_pkg::reg_dbg_cnt_active_last_scan_t reg_dbg_cnt_active_last_scan;
        this.read_dbg_cnt_active_last_scan(reg_dbg_cnt_active_last_scan);
        cnt = reg_dbg_cnt_active_last_scan;
    endtask

    task get_notify_cnt(output int cnt);
        state_notify_reg_pkg::reg_dbg_cnt_notify_t reg_dbg_cnt_notify;
        this.read_dbg_cnt_notify(reg_dbg_cnt_notify);
        cnt = reg_dbg_cnt_notify;
    endtask

    task clear_debug_counts();
        state_notify_reg_pkg::reg_dbg_control_t reg_dbg_control;
        this.read_dbg_control(reg_dbg_control);
        reg_dbg_control.clear_counts = 1'b1;
        this.write_dbg_control(reg_dbg_control);
        reg_dbg_control.clear_counts = 1'b0;
        this.write_dbg_control(reg_dbg_control);
    endtask

endclass : state_notify_reg_agent
