class timer_expiry_reg_agent extends timer_expiry_reg_blk_agent;

    local static const string __CLASS_NAME = "timer_verif_pkg::timer_expiry_reg_agent";

    //===================================
    // Methods
    //===================================
    function new(
            input string name="timer_expiry_reg_agent",
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
        timer_expiry_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        timer_expiry_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task set_timeout(input int timeout);
        timer_expiry_reg_pkg::reg_cfg_timeout_t reg_cfg_timeout;
        reg_cfg_timeout = timeout;
        this.write_cfg_timeout(timeout);
    endtask

    task get_timeout(output int timeout);
        timer_expiry_reg_pkg::reg_cfg_timeout_t reg_cfg_timeout;
        this.read_cfg_timeout(reg_cfg_timeout);
        timeout = reg_cfg_timeout;
    endtask


    task get_timer_bits(output int timer_bits);
        timer_expiry_reg_pkg::reg_info_timer_bits_t reg_info_timer_bits;
        this.read_info_timer_bits(reg_info_timer_bits);
        timer_bits = reg_info_timer_bits;
    endtask

    task get_timer_value(output bit[63:0] timer_value);
        timer_expiry_reg_pkg::reg_dbg_timer_upper_t reg_dbg_timer_upper;
        timer_expiry_reg_pkg::reg_dbg_timer_lower_t reg_dbg_timer_lower;
        this.read_dbg_timer_upper(reg_dbg_timer_upper);
        this.read_dbg_timer_lower(reg_dbg_timer_lower);
        timer_value = {reg_dbg_timer_upper, reg_dbg_timer_lower};
    endtask

endclass : timer_expiry_reg_agent
