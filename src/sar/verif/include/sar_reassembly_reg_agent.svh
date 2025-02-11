class sar_reassembly_reg_agent#(type BUF_ID_T = bit, type OFFSET_T = bit, type FRAGMENT_PTR_T = bit, type TIMER_T = bit) extends sar_reassembly_reg_blk_agent;

    //===================================
    // Properties
    //===================================
    sar_reassembly_cache_reg_agent #(BUF_ID_T, OFFSET_T, FRAGMENT_PTR_T) cache;
    sar_reassembly_state_reg_agent #(BUF_ID_T, OFFSET_T, FRAGMENT_PTR_T, TIMER_T) state;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="sar_reassembly_reg_agent",
            input int MAX_FRAGMENTS,
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
        this.state = new("state_agent", reg_agent, BASE_OFFSET + 'h1000);
        this.cache = new("cache_agent", MAX_FRAGMENTS, reg_agent, BASE_OFFSET + 'h2000);
        reset();
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
        sar_reassembly_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        sar_reassembly_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

endclass : sar_reassembly_reg_agent
