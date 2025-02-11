class sar_reassembly_state_check_reg_agent extends sar_reassembly_state_check_reg_blk_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="sar_reassembly_state_check_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() virtual method ]]
    function automatic void reset();
        super.reset();
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        sar_reassembly_state_check_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        sar_reassembly_state_check_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    // Set timeout
    task set_timeout(
            input int timeout
        );
        sar_reassembly_state_check_reg_pkg::reg_cfg_timeout_t reg_cfg_timeout;
        reg_cfg_timeout.enable = 1'b1;
        reg_cfg_timeout.value = timeout;
        this.write_cfg_timeout(reg_cfg_timeout);
    endtask

    // Read timeout
    task get_timeout(
            output int timeout
        );
        sar_reassembly_state_check_reg_pkg::reg_cfg_timeout_t reg_cfg_timeout;
        this.read_cfg_timeout(reg_cfg_timeout);
        timeout = reg_cfg_timeout.value;
    endtask

    task get_buffer_done_cnt(
            output int cnt
        );
        sar_reassembly_state_check_reg_pkg::reg_dbg_cnt_buffer_done_t reg_dbg_cnt_buffer_done;
        this.read_dbg_cnt_buffer_done(reg_dbg_cnt_buffer_done);
        cnt = reg_dbg_cnt_buffer_done;
    endtask

    task get_fragment_expired_cnt(
            output int cnt
        );
        sar_reassembly_state_check_reg_pkg::reg_dbg_cnt_fragment_expired_t reg_dbg_cnt_fragment_expired;
        this.read_dbg_cnt_fragment_expired(reg_dbg_cnt_fragment_expired);
        cnt = reg_dbg_cnt_fragment_expired;
    endtask

endclass : sar_reassembly_state_check_reg_agent
